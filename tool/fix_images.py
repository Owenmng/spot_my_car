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
RETRY_PATH = "tool/reports/photo_retry.json"  # modèles sans photo : date du dernier essai
MISSING_MAX = int(os.environ.get("MISSING_MAX", "80"))  # modèles sans photo retentés par exécution
RETRY_DAYS = 2  # jusqu’à la fin du chantier photos (28/11), puis 7

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


# Plafond d'appels IA par exécution : on garde du quota gratuit pour les joueurs.
VISION_MAX = int(os.environ.get("VISION_MAX", "0")) or 10**9
_stop = {"quota": False}


def out_of_time():
    return _stop["quota"] or _vision_calls >= VISION_MAX or time.time() - START > BUDGET_S


def base_title(url):
    if not url:
        return None
    name = urllib.parse.unquote(url.split("?")[0].rsplit("/", 1)[-1])
    name = re.sub(r"^\d+px-", "", name)
    return "File:" + name.replace("_", " ")


def title_ok(title, bname, model_name):
    """Le nom du fichier doit citer le modèle : tous ses mots (chiffres compris, en mots entiers),
    et le code de génération s'il contient des chiffres. Évite « BMW 125 » illustrée par une 118i."""
    tn = f" {norm(title.replace('File:', ''))} "
    base = re.sub(r"\(.*?\)", "", model_name).strip()
    brand_words = set(norm(bname).split())
    want = [w for w in norm(base).split() if w not in brand_words or any(c.isdigit() for c in w)]
    if not want or not all(f" {w} " in tn for w in want):
        return False
    gen = " ".join(re.findall(r"\((.*?)\)", model_name))
    gen_digits = [w for w in norm(gen).split() if any(c.isdigit() for c in w)]
    return all(f" {w} " in tn for w in gen_digits)


def wiki_lead_images(q):
    """Image principale des articles Wikipédia (en, fr, de, it) qui parlent de ce modèle."""
    out = []
    for lang in ("en", "fr", "de", "it"):
        try:
            d = http_json(f"https://{lang}.wikipedia.org/w/api.php", {
                "action": "query", "format": "json", "generator": "search", "gsrsearch": q, "gsrlimit": 3,
                "prop": "pageimages", "piprop": "name"})
        except Exception:
            continue
        if not d:
            continue
        pages = sorted((d.get("query") or {}).get("pages", {}).values(), key=lambda p: p.get("index", 99))
        for pg in pages:
            name = pg.get("pageimage")
            if name and not name.lower().endswith((".svg", ".gif")):
                t = "File:" + name.replace("_", " ")
                if t not in out:
                    out.append(t)
        time.sleep(0.2)
    return out


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
    "view": {"type": "STRING", "enum": ["front", "frontThreeQuarter", "side", "rearThreeQuarter", "rear", "top", "other"]},
    "obstructed": {"type": "BOOLEAN"},
    "quality": {"type": "INTEGER"}},
    "required": ["exterior", "wholeCar", "sameModel", "view", "obstructed", "quality"]}

# Version du contrôle : "v2" = critères stricts (vue avant/trois-quarts/profil, voiture dégagée, qualité >= 6).
# Les photos validées avec l'ancien contrôle (True) sont revérifiées une fois les nouvelles terminées.
CHECK_V = "v3"
# Chaque modèle Gemini a son propre quota gratuit par jour : quand l'un est épuisé, on passe au suivant.
# Ceux qu'utilise l'appli (3.8-flash, 3.5-flash-lite) passent en dernier pour ne pas gêner les joueurs.
_models = [m.strip() for m in (os.environ.get("VISION_MODELS") or "gemini-3.5-flash,gemini-3.8-flash,gemini-3.5-flash-lite").split(",") if m.strip()]
MODEL_THINKING = {"gemini-3.8-flash": {"thinkingBudget": 0}, "gemini-3.5-flash-lite": {"thinkingLevel": "MINIMAL"}}
GOOD_VIEWS = {"front", "frontThreeQuarter", "side", "rearThreeQuarter"}

_vision_calls = 0


BATCH = int(os.environ.get("VISION_BATCH", "8"))  # photos jugées par appel : le quota compte les appels, pas les photos
CRITERIA = ("Pour CHAQUE photo : "
            "exterior : la photo montre la voiture vue de l'extérieur (pas l'habitacle, pas le moteur, pas un détail). "
            "wholeCar : la voiture est entière ou presque dans le cadre et c'est le sujet principal. "
            "sameModel : c'est EXACTEMENT le modèle attendu pour cette photo, et cette génération si elle est précisée. Un modèle voisin "
            "de la même marque (autre numéro, autre génération, version de course ou concept au lieu de la série) = false. En cas de doute = false. "
            "view : angle de vue principal de la voiture. "
            "obstructed : la voiture est en partie cachée (autre véhicule, personnes, barrière, grosse bâche, texte incrusté). "
            "quality : 1 à 10, netteté, lumière et lisibilité de la voiture (10 = photo de catalogue). "
            "Juge chaque photo indépendamment des autres.")


def _fetch_img(url):
    try:
        r = S.get(url, timeout=30)
        if not r.ok:
            return None
        img = r.content
        if Image:
            im = Image.open(io.BytesIO(img)).convert("RGB")
            im.thumbnail((640, 640))
            buf = io.BytesIO()
            im.save(buf, "JPEG", quality=78)
            img = buf.getvalue()
        return img
    except Exception:
        return None


def _gemini(body):
    """Envoie la requête au premier modèle Gemini qui a encore du quota. Renvoie le JSON de réponse, ou None."""
    global _vision_calls
    while _models:
        model = _models[0]
        cfg = MODEL_THINKING.get(model)
        b = dict(body, generationConfig=dict(body["generationConfig"]))
        if cfg:
            b["generationConfig"]["thinkingConfig"] = cfg
        switched = False
        for attempt in range(6):
            try:
                _vision_calls += 1
                resp = requests.post(f"https://firebasevertexai.googleapis.com/v1beta/projects/{PROJECT}/models/{model}:generateContent",
                                     json=b, headers={"x-goog-api-key": KEY, "X-Firebase-AppId": APPID}, timeout=120)
                low = resp.text.lower()
                if resp.status_code == 403 or resp.status_code in (400, 404) and ("not found" in low or "not supported" in low or "thinking" in low):
                    if resp.status_code != 403 and cfg and "thinking" in low:
                        MODEL_THINKING[model] = None  # ce modèle refuse ce réglage : on réessaie sans
                    else:
                        log(f"modèle {model} indisponible, suivant")
                        if _models and _models[0] == model:
                            _models.pop(0)
                    switched = True
                    break
                if resp.status_code in (429, 500, 503):
                    daily = resp.status_code == 429 and ("per day" in low or "perday" in low or "daily" in low)
                    if daily or (resp.status_code == 429 and attempt >= 5):
                        # Quota du jour de ce modèle épuisé : chaque modèle a son propre quota gratuit, on passe au suivant.
                        log(f"quota du jour atteint pour {model} après {_vision_calls} appels, modèle suivant")
                        if _models and _models[0] == model:
                            _models.pop(0)
                        switched = True
                        break
                    time.sleep(65 if resp.status_code == 429 else 10 * (attempt + 1))
                    continue
                time.sleep(4)
                if not resp.ok:
                    log(f"vision HTTP {resp.status_code} {resp.text[:120]}")
                    return None
                return json.loads(resp.json()["candidates"][0]["content"]["parts"][0]["text"])
            except Exception as e:
                log(f"vision err {e}")
                time.sleep(5)
        if not switched:
            return None
    _stop["quota"] = True  # tous les modèles ont épuisé leur quota : on reprendra demain
    log("quota du jour atteint sur tous les modèles, arrêt")
    return None


def _verdict(j):
    return bool(j.get("exterior") and j.get("wholeCar") and j.get("sameModel") and not j.get("obstructed")
                and j.get("view") in GOOD_VIEWS and (j.get("quality") or 0) >= 6)


def vision_batch(items):
    """items = [(url, modèle attendu)] -> [True / False / None] (None = l'IA n'a pas pu trancher)."""
    out = [None] * len(items)
    if out_of_time() or not items:
        return out
    imgs = [_fetch_img(u) for u, _ in items]
    idx = [i for i, im in enumerate(imgs) if im]
    if not idx:
        return out
    parts = [{"text": f"Voici {len(idx)} photos numérotées, chacune destinée à la fiche catalogue d'une voiture. " + CRITERIA +
              f" Réponds avec la liste results de {len(idx)} objets, dans l'ordre des photos, avec n = numéro de la photo."}]
    for n, i in enumerate(idx, 1):
        parts.append({"text": f"Photo {n} — voiture attendue : « {items[i][1]} »"})
        parts.append({"inlineData": {"mimeType": "image/jpeg", "data": base64.b64encode(imgs[i]).decode()}})
    item_schema = dict(SCHEMA, properties=dict(SCHEMA["properties"], n={"type": "INTEGER"}), required=SCHEMA["required"] + ["n"])
    body = {"contents": [{"role": "user", "parts": parts}],
            "generationConfig": {"temperature": 0, "responseMimeType": "application/json",
                                 "responseSchema": {"type": "OBJECT", "properties": {"results": {"type": "ARRAY", "items": item_schema}},
                                                    "required": ["results"]}}}
    j = _gemini(body)
    if not j:
        return out
    res = j.get("results") or []
    if len(res) != len(idx):
        log(f"réponse incomplète ({len(res)}/{len(idx)}), lot ignoré")
        return out
    by_n = {r.get("n"): r for r in res}
    for n, i in enumerate(idx, 1):
        r = by_n.get(n)
        if r is not None:
            out[i] = _verdict(r)
    return out


def vision_ok(thumb_url, label):
    """True / False, ou None si l'IA est indisponible (on ne tranche pas)."""
    return vision_batch([(thumb_url, label)])[0]


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

    def find_replacement(bname, m, wide=False):
        base = re.sub(r"\(.*?\)", "", m["name"]).strip()
        gen = re.findall(r"\((.*?)\)", m["name"])
        want = [w for w in norm(base).split() if w]
        brand_tok = norm(bname).split()[0]
        queries = [f"{bname} {base} {gen[0]}" if gen else None, f"{bname} {base}", f"{bname} {base} front", f"{bname} {base} side"]
        cands = []
        if wide:
            # Modèle sans photo : on regarde aussi l'image principale des articles Wikipédia
            # (souvent la seule bonne photo d'un modèle rare). L'IA vérifie ensuite que c'est le bon.
            for t in wiki_lead_images(f"{bname} {base}"):
                if t not in in_use and t not in cands and title_ok(t, bname, m["name"]):
                    cands.append(t)
            queries += [f"{bname} {base} car", f"{base} {bname}"]
        for q in [q for q in queries if q]:
            for t in commons_search(q):
                tn = norm(t)
                if t in in_use or t in cands or brand_tok not in tn or not all(w in tn for w in want):
                    continue
                if not title_ok(t, bname, m["name"]):
                    continue
                cands.append(t)
            time.sleep(0.2)
            if len(cands) >= 10:
                break
        if not cands:
            return None
        # Les photos prises de l'arrière ou de l'intérieur passent en dernier : on veut l'avant ou le profil.
        back = re.compile(r"\b(rear|back|heck|arriere|arrière|trasera|posteriore|interior|innen|cockpit|engine|motor|dashboard)\b", re.I)
        cands.sort(key=lambda t: (1 if back.search(t) else 0, -score_title(t, m["name"], bname)))
        infos = commons_info(cands[:10])
        ccats = categories(cands[:10])
        ok = []
        for t in cands[:10]:
            info = infos.get(t)
            if checked.get(t) is False or checked.get(f"{t}::{m['name']}") is False or not photo_ok(info) or looks_interior(t, ccats.get(t)):
                continue
            if checked.get(t) == CHECK_V:
                return info  # déjà validée avec les critères stricts : pas besoin de redemander à l'IA
            ok.append((t, info))
        # Un seul appel IA pour juger jusqu'à 6 candidates ; on garde la première validée (les mieux classées d'abord).
        ok = ok[:6]
        verdicts = vision_batch([(info["thumb"], f"{bname} {m['name']}") for _, info in ok])
        for (t, info), v in zip(ok, verdicts):
            if v is False:
                checked[f"{t}::{m['name']}"] = False  # refusée pour CE modèle (elle peut convenir à un autre)
        for (t, info), v in zip(ok, verdicts):
            if v is True:
                return info
        return None  # aucune validée par l'IA (ou IA indisponible) : jamais de photo non vérifiée

    def apply(f, bname, m, info, reason):
        old = base_title(m.get("imageUrl"))
        if info:
            m["imageUrl"] = info["thumb"]
            m["imageCredit"] = info["artist"] or "Wikimedia Commons"
            m["imageLicense"] = info["license"]
            m["imagePage"] = info["page"]
            nt = base_title(info["thumb"]) or info["title"]
            in_use.add(nt)
            checked[nt] = CHECK_V
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

    # 0. Modèles sans photo : nouvelle recherche, plus large, tous les 7 jours au plus.
    try:
        retry = json.load(open(RETRY_PATH))
    except Exception:
        retry = {}
    today = time.strftime("%Y-%m-%d")
    def due(m):
        last = retry.get(m.get("id") or m["name"])
        return not last or (time.mktime(time.strptime(today, "%Y-%m-%d")) - time.mktime(time.strptime(last, "%Y-%m-%d"))) >= RETRY_DAYS * 86400
    missing = [(f, bname, m) for f, bname, m in entries if not m.get("imageUrl") and due(m)]
    log(f"sans photo à retenter: {len(missing)}")
    found = 0
    for f, bname, m in missing[:MISSING_MAX]:
        if out_of_time():
            break
        retry[m.get("id") or m["name"]] = today
        info = find_replacement(bname, m, wide=True)
        if info:
            found += 1
            apply(f, bname, m, info, "sans photo")
            stats["remplacées"] -= 1
            stats["retrouvées"] = stats.get("retrouvées", 0) + 1
        done.add(id(m))

    for f, bname, m, reason in to_fix:
        if out_of_time():
            break
        if id(m) in done:
            continue
        done.add(id(m))
        apply(f, bname, m, find_replacement(bname, m), reason)

    # 3. Validation IA de toutes les autres photos, au fil des exécutions.
    pending = [(f, bname, m) for f, bname, m in entries
               if m.get("imageUrl") and checked.get(base_title(m["imageUrl"])) != CHECK_V and id(m) not in done]
    # D'abord les photos jamais vérifiées, puis celles validées avec l'ancien contrôle, moins strict.
    pending.sort(key=lambda e: 0 if base_title(e[2]["imageUrl"]) not in checked else 1)
    log(f"validation IA restante: {len(pending)}")
    from concurrent.futures import ThreadPoolExecutor
    pool = ThreadPoolExecutor(max_workers=2)
    for i in range(0, len(pending), 24):
        if out_of_time():
            break
        batch = pending[i:i + 24]
        chunks = [batch[k:k + BATCH] for k in range(0, len(batch), BATCH)]
        verdicts = [v for vs in pool.map(lambda ch: vision_batch([(e[2]["imageUrl"], f"{e[1]} {e[2]['name']}") for e in ch]), chunks) for v in vs]
        for (f, bname, m), v in zip(batch, verdicts):
            t = base_title(m["imageUrl"])
            if v is None:
                continue
            if v:
                checked[t] = CHECK_V
                stats["validées"] += 1
            else:
                stats["rejetées_ia"] += 1
                apply(f, bname, m, find_replacement(bname, m), "refusée par l'IA")
                checked[t] = False
        if i % 480 == 0:
            log(f"validation {i}/{len(pending)} {stats}")

    for f, doc in docs.items():
        json.dump(doc, open(f, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    os.makedirs("tool/reports", exist_ok=True)
    json.dump(checked, open(CHECKED_PATH, "w"), ensure_ascii=False)
    json.dump(retry, open(RETRY_PATH, "w"), ensure_ascii=False, indent=0)
    remaining = sum(1 for _, _, m in entries if m.get("imageUrl") and checked.get(base_title(m["imageUrl"])) != CHECK_V)
    no_photo = sum(1 for _, _, m in entries if not m.get("imageUrl"))
    with open("tool/reports/image_quality.md", "w", encoding="utf-8") as fh:
        fh.write(f"# Contrôle des photos\n\n{json.dumps(stats, ensure_ascii=False)} · appels IA: {_vision_calls} · restant à valider: {remaining} · sans photo: {no_photo}\n\n")
        fh.write("\n".join(report[-1500:]))
    log(f"FIN {stats} appels_ia={_vision_calls} restant={remaining} sans_photo={no_photo}")


if __name__ == "__main__":
    main()
