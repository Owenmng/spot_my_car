"""Contrôle qualité des photos du catalogue.

1. Une photo = un seul modèle : les doublons reçoivent une autre photo (ou sont masqués).
2. Uniquement des vues extérieures : intérieurs, moteurs, détails sont remplacés.
3. Chaque photo est validée par l'IA (Gemini) : bonne voiture, vue extérieure, nette.

Le travail est incrémental : tool/reports/vision_checked.json garde les photos déjà validées,
chaque exécution reprend où la précédente s'est arrêtée (budget de temps limité).
"""
import base64, glob, io, json, os, re, sys, time, urllib.parse
sys.path.insert(0, "tool")
import requests
from catalog_builder import http_json, commons_info, norm, log, DATA

try:
    from PIL import Image
except ImportError:
    Image = None

BUDGET_S = float(os.environ.get("BUDGET_MIN", "300")) * 60
START = time.time()
CHECKED_PATH = "tool/reports/vision_checked.json"

opts = open("lib/firebase_options.dart").read()
android = opts[opts.index("android"):]
KEY = re.search(r"apiKey: '([^']+)'", android).group(1)
APPID = re.search(r"appId: '([^']+)'", android).group(1)
PROJECT = "car-spotter-app-779f2"
UA = "SpotMyCarCatalogBot/1.0 (https://github.com/Owenmng/spot_my_car)"
S = requests.Session()
S.headers["User-Agent"] = UA

BAD_TITLE = re.compile(r"\b(interior|innenraum|innenansicht|int[ée]rieur|interieur|cockpit|dashboard|armaturenbrett|tacho|lenkrad|"
                       r"steering wheel|engine|engine bay|motorraum|moteur|kofferraum|trunk|car seats|gear ?(stick|lever|shift)|"
                       r"rims?|felgen?|badge|logo|emblem|close-?up|headlights?|scheinwerfer|taillights?|r[üu]ckleuchten?|"
                       r"mirror|exhaust|auspuff|vin)\b", re.I)
BAD_CAT = re.compile(r"interior|dashboard|cockpit|steering wheel|engine|seats|gear stick|instrument|innenraum|trunk|boot of|"
                     r"wheels of|rims|headlights|taillights|logos|emblems|details of|doors of|exhaust", re.I)


def out_of_time():
    return time.time() - START > BUDGET_S


def base_title(url):
    if not url:
        return None
    name = urllib.parse.unquote(url.split("?")[0].rsplit("/", 1)[-1])
    name = re.sub(r"^\d+px-", "", name)
    return "File:" + name.replace("_", " ")


def commons_search(q, limit=12):
    d = http_json("https://commons.wikimedia.org/w/api.php", {
        "action": "query", "format": "json", "list": "search", "srnamespace": 6, "srsearch": q, "srlimit": limit})
    return [x["title"] for x in (d or {}).get("query", {}).get("search", [])]


def categories(titles):
    out = {}
    for i in range(0, len(titles), 40):
        chunk = titles[i:i + 40]
        d = http_json("https://commons.wikimedia.org/w/api.php", {
            "action": "query", "format": "json", "titles": "|".join(chunk), "prop": "categories", "cllimit": "max", "clshow": "!hidden"})
        if not d:
            continue
        norm_map = {n["to"]: n["from"] for n in d.get("query", {}).get("normalized", [])}
        for p in d.get("query", {}).get("pages", {}).values():
            t = norm_map.get(p["title"], p["title"])
            out[t] = [c["title"] for c in p.get("categories", [])]
        time.sleep(0.2)
    return out


def photo_ok(info):
    if not info or info["mime"] not in ("image/jpeg", "image/png", "image/webp"):
        return False
    if info["w"] < 800 or info["h"] < 450:
        return False
    ratio = info["w"] / max(info["h"], 1)
    lic = (info["license"] or "").lower()
    return 1.2 <= ratio <= 2.6 and lic and "non-free" not in lic and "fair use" not in lic


def looks_interior(title, cats):
    if BAD_TITLE.search(title.replace("File:", "")):
        return True
    return any(BAD_CAT.search(c) for c in cats or [])


SCHEMA = {"type": "OBJECT", "properties": {
    "exterior": {"type": "BOOLEAN"},
    "wholeCar": {"type": "BOOLEAN"},
    "sameModel": {"type": "BOOLEAN"},
    "seenMake": {"type": "STRING"},
    "seenModel": {"type": "STRING"},
    "quality": {"type": "INTEGER"}},
    "required": ["exterior", "wholeCar", "sameModel", "quality"]}

_vision_calls = 0


def vision_ok(thumb_url, label):
    """True / False, ou None si l'IA est indisponible (on ne tranche pas)."""
    global _vision_calls
    try:
        r = S.get(thumb_url, timeout=30)
        if not r.ok:
            return None
        img = r.content
        if Image:
            im = Image.open(io.BytesIO(img)).convert("RGB")
            im.thumbnail((768, 768))
            b = io.BytesIO()
            im.save(b, "JPEG", quality=78)
            img = b.getvalue()
    except Exception:
        return None
    prompt = (f"Cette photo doit illustrer la fiche catalogue de la voiture « {label} ». "
              "exterior : la photo montre la voiture vue de l'extérieur (pas l'habitacle, pas le moteur, pas un détail). "
              "wholeCar : la voiture est entière ou presque dans le cadre et c'est le sujet principal. "
              "sameModel : c'est bien ce modèle (et cette génération si elle est précisée), ou une version très proche. "
              "quality : 1 à 10, netteté et lisibilité de la voiture.")
    body = {"contents": [{"role": "user", "parts": [{"text": prompt},
                                                      {"inlineData": {"mimeType": "image/jpeg", "data": base64.b64encode(img).decode()}}]}],
            "generationConfig": {"temperature": 0, "responseMimeType": "application/json", "responseSchema": SCHEMA,
                                 "thinkingConfig": {"thinkingLevel": "MINIMAL"}}}
    for attempt in range(6):
        try:
            _vision_calls += 1
            resp = requests.post(f"https://firebasevertexai.googleapis.com/v1beta/projects/{PROJECT}/models/gemini-3.5-flash-lite:generateContent",
                                 json=body, headers={"x-goog-api-key": KEY, "X-Firebase-AppId": APPID}, timeout=60)
            if resp.status_code in (429, 500, 503):
                time.sleep(10 * (attempt + 1))
                continue
            if not resp.ok:
                log(f"vision HTTP {resp.status_code} {resp.text[:120]}")
                return None
            j = json.loads(resp.json()["candidates"][0]["content"]["parts"][0]["text"])
            return bool(j.get("exterior") and j.get("wholeCar") and j.get("sameModel") and (j.get("quality") or 0) >= 5)
        except Exception as e:
            log(f"vision err {e}")
            time.sleep(5)
    return None


def score_title(title, model_name, brand_name):
    tn = norm(title)
    base = re.sub(r"\(.*?\)", "", model_name).strip()
    gen = " ".join(re.findall(r"\((.*?)\)", model_name))
    s = sum(1 for w in norm(base).split() if w in tn) * 2
    s += sum(1 for w in norm(gen).split() if len(w) > 1 and w in tn) * 3
    s += 1 if norm(brand_name).split()[0] in tn else 0
    return s


def main():
    brands = {b["id"]: b for b in json.load(open(f"{DATA}/brands.json", encoding="utf-8"))["brands"]}
    files = sorted(glob.glob(f"{DATA}/models_by_brand/*.json"))
    docs = {f: json.load(open(f, encoding="utf-8")) for f in files}
    try:
        checked = json.load(open(CHECKED_PATH))
    except Exception:
        checked = {}

    entries = []  # (file, brand_name, model)
    for f, doc in docs.items():
        bid = f.split("/")[-1][:-5]
        bname = brands.get(bid, {"name": bid})["name"] if bid != "mustang" else "Ford"
        for m in doc["models"]:
            entries.append((f, bname, m))

    used = {}
    for f, bname, m in entries:
        t = base_title(m.get("imageUrl"))
        if t:
            used.setdefault(t, []).append((f, bname, m))
    log(f"photos={sum(len(v) for v in used.values())} distinctes={len(used)}")

    cats = categories(list(used.keys()))
    to_fix = []  # (f, bname, m, reason)

    # 1. Doublons : on garde le modèle qui correspond le mieux au nom du fichier.
    for t, owners in used.items():
        if len(owners) > 1:
            owners.sort(key=lambda o: -score_title(t, o[2]["name"], o[1]))
            for o in owners[1:]:
                to_fix.append((*o, "doublon"))
    # 2. Intérieurs / détails repérés par le titre ou les catégories.
    for t, owners in used.items():
        if looks_interior(t, cats.get(t)):
            to_fix.append((*owners[0], "intérieur/détail"))
    log(f"à corriger d'office: {len(to_fix)}")

    in_use = set(used.keys())
    stats = {"remplacées": 0, "masquées": 0, "validées": 0, "rejetées_ia": 0}
    report = []

    def find_replacement(bname, m):
        base = re.sub(r"\(.*?\)", "", m["name"]).strip()
        gen = re.findall(r"\((.*?)\)", m["name"])
        want = [w for w in norm(base).split() if w]
        brand_tok = norm(bname).split()[0]
        queries = [f"{bname} {base} {gen[0]}" if gen else None, f"{bname} {base}", f"{bname} {base} front", f"{bname} {base} side"]
        cands = []
        for q in [q for q in queries if q]:
            for t in commons_search(q):
                tn = norm(t)
                if t in in_use or t in cands or brand_tok not in tn or not all(w in tn for w in want):
                    continue
                cands.append(t)
            time.sleep(0.2)
            if len(cands) >= 10:
                break
        if not cands:
            return None
        cands.sort(key=lambda t: -score_title(t, m["name"], bname))
        infos = commons_info(cands[:10])
        ccats = categories(cands[:10])
        for t in cands[:10]:
            info = infos.get(t)
            if not photo_ok(info) or looks_interior(t, ccats.get(t)):
                continue
            v = vision_ok(info["thumb"], f"{bname} {m['name']}")
            if v is False:
                continue
            return info
        return None

    def apply(f, bname, m, info, reason):
        old = base_title(m.get("imageUrl"))
        if info:
            m["imageUrl"] = info["thumb"]
            m["imageCredit"] = info["artist"] or "Wikimedia Commons"
            m["imageLicense"] = info["license"]
            m["imagePage"] = info["page"]
            nt = base_title(info["thumb"]) or info["title"]
            in_use.add(nt)
            checked[nt] = True
            stats["remplacées"] += 1
            report.append(f"- {bname} {m['name']} ({reason}) → {info['title']}")
        else:
            for k in ("imageUrl", "imageCredit", "imageLicense", "imagePage"):
                m.pop(k, None)
            stats["masquées"] += 1
            report.append(f"- {bname} {m['name']} ({reason}) → masqué, aucune photo fiable")
        if old and reason != "doublon":
            in_use.discard(old)

    done = set()
    for f, bname, m, reason in to_fix:
        if out_of_time():
            break
        if id(m) in done:
            continue
        done.add(id(m))
        apply(f, bname, m, find_replacement(bname, m), reason)

    # 3. Validation IA de toutes les autres photos, au fil des exécutions.
    pending = [(f, bname, m) for f, bname, m in entries
               if m.get("imageUrl") and base_title(m["imageUrl"]) not in checked and id(m) not in done]
    log(f"validation IA restante: {len(pending)}")
    for f, bname, m in pending:
        if out_of_time():
            break
        t = base_title(m["imageUrl"])
        v = vision_ok(m["imageUrl"], f"{bname} {m['name']}")
        if v is None:
            continue
        if v:
            checked[t] = True
            stats["validées"] += 1
        else:
            stats["rejetées_ia"] += 1
            apply(f, bname, m, find_replacement(bname, m), "refusée par l'IA")
            checked[t] = False

    for f, doc in docs.items():
        json.dump(doc, open(f, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    os.makedirs("tool/reports", exist_ok=True)
    json.dump(checked, open(CHECKED_PATH, "w"), ensure_ascii=False)
    remaining = sum(1 for _, _, m in entries if m.get("imageUrl") and base_title(m["imageUrl"]) not in checked)
    with open("tool/reports/image_quality.md", "w", encoding="utf-8") as fh:
        fh.write(f"# Contrôle des photos\n\n{json.dumps(stats, ensure_ascii=False)} · appels IA: {_vision_calls} · restant à valider: {remaining}\n\n")
        fh.write("\n".join(report[-1500:]))
    log(f"FIN {stats} appels_ia={_vision_calls} restant={remaining}")


if __name__ == "__main__":
    main()
