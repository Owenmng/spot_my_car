"""Construit le catalogue SpotMyCar à partir de Wikidata + Wikimedia Commons.

- vérifie / remplace la photo de chaque modèle existant (photos libres, hébergées par Wikimedia : 0 €)
- ajoute les modèles manquants des marques existantes
- ajoute de nouvelles marques et leurs modèles
- remplace les logos par ceux de Wikimedia
Les identifiants des modèles existants ne changent jamais (les spots des joueurs y font référence).
"""
import html
import json
import os
import re
import sys
import time
import unicodedata
import urllib.parse

import requests

UA = "SpotMyCarCatalogBot/1.0 (https://github.com/Owenmng/spot_my_car)"
S = requests.Session()
S.headers.update({"User-Agent": UA})

DATA = "assets/data"
REPORT_DIR = "tool/reports"
os.makedirs(REPORT_DIR, exist_ok=True)
log_lines = []


def log(*a):
    s = " ".join(str(x) for x in a)
    print(s, flush=True)
    log_lines.append(s)


def http_json(url, params=None, tries=5):
    for i in range(tries):
        try:
            r = S.get(url, params=params, timeout=90)
            if r.status_code in (429, 502, 503, 504):
                time.sleep(4 * (i + 1))
                continue
            r.raise_for_status()
            return r.json()
        except Exception as e:  # noqa
            if i == tries - 1:
                log("HTTP FAIL", url, params and list(params.items())[:3], e)
                return None
            time.sleep(3 * (i + 1))
    return None


def sparql(q):
    d = http_json("https://query.wikidata.org/sparql", {"format": "json", "query": q})
    return d["results"]["bindings"] if d else []


def norm(s):
    s = unicodedata.normalize("NFKD", str(s or "")).encode("ascii", "ignore").decode().lower()
    s = s.replace("&", " and ").replace("serie ", "series ").replace("classe ", "class ").replace("-class", " class")
    return re.sub(r"[^a-z0-9]+", " ", s).strip()


def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", norm(s)).strip("-")


def qid(uri):
    return uri.rsplit("/", 1)[-1]


# --------------------------------------------------------------------------- marques

NEW_BRANDS = [
    # (nom, rareté, indice de recherche)
    ("Cupra", 2, "Cupra"), ("MG", 1, "MG Motor"), ("BYD", 1, "BYD Auto"), ("Genesis", 2, "Genesis Motor"),
    ("Infiniti", 2, "Infiniti"), ("Acura", 2, "Acura"), ("Lincoln", 2, "Lincoln Motor Company"), ("Buick", 2, "Buick"),
    ("GMC", 2, "GMC"), ("Chrysler", 2, "Chrysler"), ("Ram", 2, "Ram Trucks"), ("Saab", 2, "Saab Automobile"),
    ("Daihatsu", 2, "Daihatsu"), ("Isuzu", 2, "Isuzu"), ("SsangYong", 1, "SsangYong Motor"), ("Lada", 1, "Lada"),
    ("Lynk & Co", 2, "Lynk & Co"), ("Aixam", 1, "Aixam"), ("Ligier", 1, "Ligier"), ("Microcar", 1, "Microcar"),
    ("Alpina", 3, "Alpina Burkard Bovensiepen"), ("Brabus", 3, "Brabus"), ("Morgan", 3, "Morgan Motor Company"),
    ("Caterham", 3, "Caterham Cars"), ("TVR", 3, "TVR"), ("Ariel", 3, "Ariel Motor Company"), ("Noble", 4, "Noble Automotive"),
    ("Donkervoort", 4, "Donkervoort"), ("De Tomaso", 4, "De Tomaso"), ("Rimac", 5, "Rimac Automobili"), ("Spyker", 4, "Spyker Cars"),
    ("Lucid", 3, "Lucid Motors"), ("Rivian", 3, "Rivian"), ("Fisker", 3, "Fisker Inc."), ("NIO", 2, "NIO Inc."),
    ("Xpeng", 2, "Xpeng"), ("Zeekr", 2, "Zeekr"), ("Leapmotor", 1, "Leapmotor"), ("Geely", 1, "Geely Auto"),
    ("Hummer", 3, "Hummer"), ("Pontiac", 3, "Pontiac"), ("Oldsmobile", 3, "Oldsmobile"), ("Plymouth", 3, "Plymouth automobile"),
    ("Simca", 3, "Simca"), ("Talbot", 3, "Talbot automobile"), ("Matra", 3, "Matra Automobile"), ("Venturi", 4, "Venturi Automobiles"),
    ("Trabant", 3, "Trabant"), ("Wartburg", 3, "Wartburg car"), ("Rover", 2, "Rover car marque"), ("Austin", 3, "Austin Motor Company"),
    ("Triumph", 3, "Triumph Motor Company"), ("Maybach", 4, "Maybach"), ("Vauxhall", 1, "Vauxhall Motors"), ("Holden", 2, "Holden"),
    ("Proton", 1, "Proton Holdings"), ("Tata", 1, "Tata Motors"), ("Mahindra", 2, "Mahindra & Mahindra"), ("Hennessey", 5, "Hennessey Special Vehicles"),
    ("SSC", 5, "SSC North America"), ("Zenvo", 5, "Zenvo Automotive"), ("Gordon Murray", 5, "Gordon Murray Automotive"), ("Lotus", None, None),
]

CAR_DESC = re.compile(r"car|automobile|automotive|automaker|carmaker|motor|vehicle|marque|constructeur|voiture|manufacturer|brand|company", re.I)
BAD_DESC = re.compile(r"motorcycle|airline|aircraft|footballer|album|film|song|band|rapper|cycling|bicycle|family name|given name|river|city|comune", re.I)


def search_brands(term, limit=3):
    d = http_json("https://www.wikidata.org/w/api.php", {
        "action": "wbsearchentities", "format": "json", "language": "en", "type": "item", "limit": 12, "search": term})
    out = []
    first_word = norm(term).split(" ")[0] if norm(term) else ""
    for x in (d or {}).get("search", []):
        desc = x.get("description") or ""
        label = x.get("label") or ""
        if re.search(r"group|holding|conglomerate|multinational|parent company|subsidiary of", desc, re.I) and len(out) > 0:
            continue
        if not CAR_DESC.search(desc) or BAD_DESC.search(desc) or re.search(r"car model|motor vehicle|model of|car series|engine|dealership|museum|racing team|football|club", desc, re.I):
            continue
        if first_word and first_word not in norm(label):
            continue
        out.append((x["id"], label, desc))
        if len(out) >= limit:
            break
    return out


def search_brand(term):
    r = search_brands(term, 1)
    return r[0] if r else (None, None, None)


BRAND_OVERRIDES = {"mustang": None, "amg": "Mercedes-AMG", "ktm": "KTM", "ds": "DS Automobiles", "mini": "Mini (marque)",
                   "smart": "Smart Automobile", "jeep": "Jeep", "dodge": "Dodge", "lancia": "Lancia", "seat": "SEAT",
                   "polestar": "Polestar", "tesla": "Tesla, Inc.", "alpine": "Alpine (automobile)", "abarth": "Abarth",
                   "land-rover": "Land Rover", "mercedes-benz": "Mercedes-Benz", "bmw": "BMW", "mazda": "Mazda", "honda": "Honda",
                   "nissan": "Nissan", "toyota": "Toyota", "ford": "Ford Motor Company", "chevrolet": "Chevrolet", "cadillac": "Cadillac",
                   "opel": "Opel", "renault": "Renault", "peugeot": "Peugeot", "citroen": "Citroën", "dacia": "Dacia", "fiat": "Fiat Automobiles",
                   "ferrari": "Ferrari", "porsche": "Porsche", "volkswagen": "Volkswagen", "volvo": "Volvo Cars", "subaru": "Subaru",
                   "suzuki": "Suzuki", "hyundai": "Hyundai Motor Company", "kia": "Kia", "skoda": "Škoda Auto", "audi": "Audi",
                   "mitsubishi": "Mitsubishi Motors", "lexus": "Lexus", "jaguar": "Jaguar Cars", "maserati": "Maserati",
                   "mclaren": "McLaren Automotive", "bentley": "Bentley", "rolls-royce": "Rolls-Royce Motor Cars", "aston-martin": "Aston Martin",
                   "bugatti": "Bugatti Automobiles", "lamborghini": "Lamborghini", "koenigsegg": "Koenigsegg", "pagani": "Pagani Automobili",
                   "lotus": "Lotus Cars", "alfa-romeo": "Alfa Romeo"}


# --------------------------------------------------------------------------- modèles Wikidata

ALLOWED_CLASS_WORDS = re.compile(r"automobile model|car model|automobile generation|car generation|model year|sports car|supercar|hypercar|"
                                 r"grand tourer|hatchback|sedan|saloon|station wagon|estate car|coupé|coupe|convertible|roadster|"
                                 r"sport utility|crossover|minivan|city car|microcar|kei car|pickup truck|compact car|executive car|"
                                 r"luxury vehicle|muscle car|electric car|hybrid|motor car|automobile$|^car$|shooting brake|pony car", re.I)
BAD_CLASS_WORDS = re.compile(r"concept car|prototype|racing|race car|formula|truck$|lorry|bus|motorcycle|engine|tractor|military|"
                             r"armored|tank|aircraft|boat|van$|ambulance|fire engine|kit car|rally car|one-off", re.I)


def brand_models(brand_qid):
    q = f"""SELECT ?m ?mLabel ?frLabel ?clsLabel ?img ?inc ?dis ?s ?e ?st ?et ?len ?wid ?hei ?mass ?speed ?power ?enwiki ?frwiki WHERE {{
      {{ ?m wdt:P1716 wd:{brand_qid} }} UNION {{ ?m wdt:P176 wd:{brand_qid} }}
      ?m wdt:P31 ?cls .
      OPTIONAL {{ ?m wdt:P18 ?img }}
      OPTIONAL {{ ?m wdt:P571 ?inc }} OPTIONAL {{ ?m wdt:P2669 ?dis }} OPTIONAL {{ ?m wdt:P576 ?e }}
      OPTIONAL {{ ?m wdt:P580 ?st }} OPTIONAL {{ ?m wdt:P582 ?et }} OPTIONAL {{ ?m wdt:P729 ?s }}
      OPTIONAL {{ ?m p:P2043/psn:P2043/wikibase:quantityAmount ?len }}
      OPTIONAL {{ ?m p:P2049/psn:P2049/wikibase:quantityAmount ?wid }}
      OPTIONAL {{ ?m p:P2048/psn:P2048/wikibase:quantityAmount ?hei }}
      OPTIONAL {{ ?m p:P2067/psn:P2067/wikibase:quantityAmount ?mass }}
      OPTIONAL {{ ?m p:P2052/psn:P2052/wikibase:quantityAmount ?speed }}
      OPTIONAL {{ ?m p:P2109/psn:P2109/wikibase:quantityAmount ?power }}
      OPTIONAL {{ ?enwiki schema:about ?m ; schema:isPartOf <https://en.wikipedia.org/> }}
      OPTIONAL {{ ?frwiki schema:about ?m ; schema:isPartOf <https://fr.wikipedia.org/> }}
      OPTIONAL {{ ?m rdfs:label ?frLabel FILTER(LANG(?frLabel) = "fr") }}
      SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en,fr". }}
    }}"""
    rows = sparql(q)
    items = {}
    for b in rows:
        mid = qid(b["m"]["value"])
        it = items.setdefault(mid, {"qid": mid, "label": b.get("mLabel", {}).get("value", ""), "fr": b.get("frLabel", {}).get("value"),
                                     "classes": set(), "images": [], "years": set(), "enwiki": None, "frwiki": None, "specs": {}})
        it["classes"].add(b.get("clsLabel", {}).get("value", ""))
        if "img" in b and b["img"]["value"] not in it["images"]:
            it["images"].append(b["img"]["value"])
        for k in ("inc", "dis", "s", "e", "st", "et"):
            if k in b:
                m = re.match(r"(\d{4})", b[k]["value"].lstrip("+"))
                if m:
                    it["years"].add(int(m.group(1)))
        for k in ("len", "wid", "hei", "mass", "speed", "power"):
            if k in b:
                try:
                    it["specs"][k] = float(b[k]["value"])
                except ValueError:
                    pass
        it["enwiki"] = it["enwiki"] or b.get("enwiki", {}).get("value")
        it["frwiki"] = it["frwiki"] or b.get("frwiki", {}).get("value")
    out = []
    for it in items.values():
        cls = " | ".join(it["classes"])
        if BAD_CLASS_WORDS.search(cls) and not re.search(r"automobile model|car model", cls, re.I):
            continue
        if not ALLOWED_CLASS_WORDS.search(cls):
            continue
        if re.match(r"^Q\d+$", it["label"]):
            continue
        out.append(it)
    return out


def strip_brand(label, brand_name):
    l = label.strip()
    for b in {brand_name, brand_name.replace("-", " "), "Mercedes-Benz", "Mercedes-AMG", "Mercedes", "Volkswagen", "VW", "Škoda", "Citroën"}:
        if l.lower().startswith(b.lower() + " "):
            return l[len(b) + 1:].strip()
    return l


# --------------------------------------------------------------------------- images Commons

BAD_FILE = re.compile(r"logo|emblem|badge|interior|dashboard|cockpit|engine|motor_|seat|wheel|rim|sketch|drawing|render|diagram|"
                      r"blueprint|scale_model|model_car|toy|lego|\.svg$|\.gif$|map|plan|patent|brochure|advert|poster", re.I)


def commons_info(filenames):
    """filenames: liste de 'File:xxx.jpg' -> dict nom -> info"""
    res = {}
    for i in range(0, len(filenames), 40):
        chunk = filenames[i:i + 40]
        d = http_json("https://commons.wikimedia.org/w/api.php", {
            "action": "query", "format": "json", "titles": "|".join(chunk), "prop": "imageinfo",
            "iiprop": "url|size|mime|extmetadata", "iiurlwidth": 1280, "iiextmetadatafilter": "Artist|LicenseShortName|UsageTerms"})
        if not d:
            continue
        norm_map = {n["to"]: n["from"] for n in d.get("query", {}).get("normalized", [])}
        for p in d.get("query", {}).get("pages", {}).values():
            ii = (p.get("imageinfo") or [None])[0]
            if not ii:
                continue
            title = norm_map.get(p["title"], p["title"])
            meta = ii.get("extmetadata", {})
            artist = re.sub(r"<[^>]+>", "", html.unescape(meta.get("Artist", {}).get("value", ""))).strip()
            res[title] = {"title": p["title"], "w": ii.get("width", 0), "h": ii.get("height", 0), "mime": ii.get("mime", ""),
                          "thumb": ii.get("thumburl") or ii.get("url"), "page": ii.get("descriptionurl"),
                          "artist": re.sub(r"\s+", " ", artist)[:120], "license": meta.get("LicenseShortName", {}).get("value", "")}
        time.sleep(0.3)
    return res


def good_image(info):
    if not info:
        return False, "absente"
    if BAD_FILE.search(info["title"]):
        return False, "pas une photo de voiture entière"
    if info["mime"] not in ("image/jpeg", "image/png", "image/webp", "image/tiff"):
        return False, f"format {info['mime']}"
    if info["w"] < 800 or info["h"] < 400:
        return False, f"trop petite ({info['w']}x{info['h']})"
    ratio = info["w"] / max(info["h"], 1)
    if ratio < 1.1 or ratio > 2.8:
        return False, f"cadrage inadapté ({ratio:.2f})"
    if not info["license"] or "non-free" in info["license"].lower() or "fair use" in info["license"].lower():
        return False, "licence non libre"
    return True, "ok"


def file_title(url):
    return "File:" + urllib.parse.unquote(url.rsplit("/", 1)[-1]).replace("_", " ")


def wiki_page_images(titles_by_lang):
    """{'en': [titles], 'fr': [...]} -> {(lang,title): 'File:..'}"""
    out = {}
    for lang, titles in titles_by_lang.items():
        for i in range(0, len(titles), 40):
            chunk = titles[i:i + 40]
            d = http_json(f"https://{lang}.wikipedia.org/w/api.php", {
                "action": "query", "format": "json", "titles": "|".join(chunk), "prop": "pageimages", "piprop": "name", "redirects": 1})
            if not d:
                continue
            q = d.get("query", {})
            back = {}
            for n in q.get("normalized", []) + q.get("redirects", []):
                back[n["to"]] = back.get(n["from"], n["from"])
            for p in q.get("pages", {}).values():
                if "pageimage" in p:
                    out[(lang, back.get(p["title"], p["title"]))] = "File:" + p["pageimage"].replace("_", " ")
            time.sleep(0.3)
    return out


def wiki_search_image(query):
    d = http_json("https://en.wikipedia.org/w/api.php", {
        "action": "query", "format": "json", "generator": "search", "gsrsearch": query, "gsrlimit": 3,
        "prop": "pageimages", "piprop": "name"})
    pages = sorted((d or {}).get("query", {}).get("pages", {}).values(), key=lambda p: p.get("index", 99))
    return [(p["title"], "File:" + p["pageimage"].replace("_", " ")) for p in pages if "pageimage" in p]


# --------------------------------------------------------------------------- main

def years_label(years):
    ys = sorted(y for y in years if 1885 <= y <= 2030)
    if not ys:
        return None
    if len(ys) == 1:
        return f"{ys[0]} - Aujourd'hui" if ys[0] >= 2019 else str(ys[0])
    return f"{ys[0]} - {ys[-1]}"


def main():
    brands_doc = json.load(open(f"{DATA}/brands.json", encoding="utf-8"))
    brands = brands_doc["brands"]
    by_id = {b["id"]: b for b in brands}
    catalog = {}
    for b in brands:
        p = f"{DATA}/models_by_brand/{b['id']}.json"
        catalog[b["id"]] = json.load(open(p, encoding="utf-8"))["models"] if os.path.exists(p) else []

    stats = {"brands_new": 0, "models_new": 0, "img_kept_new": 0, "img_none": 0, "img_replaced": 0}
    rejected = []

    # 1. QID des marques existantes + nouvelles
    brand_qids = {}
    for b in brands:
        term = BRAND_OVERRIDES.get(b["id"], b["name"])
        if term is None:
            continue
        found = search_brands(term) or search_brands(b["name"])
        if found:
            brand_qids[b["id"]] = [f[0] for f in found]
            log(f"marque {b['name']} -> {found}")
        else:
            log(f"marque {b['name']} -> introuvable")
        time.sleep(0.2)

    if "--no-new-brands" not in sys.argv:
        for name, rarity, term in NEW_BRANDS:
            bid = slug(name)
            if bid in by_id or term is None:
                continue
            q, label, desc = search_brand(term)
            if not q:
                q, label, desc = search_brand(name)
            if not q:
                log(f"NOUVELLE marque {name}: introuvable")
                continue
            ent = http_json("https://www.wikidata.org/w/api.php", {"action": "wbgetentities", "format": "json", "ids": q,
                                                                    "props": "claims|descriptions", "languages": "fr|en"})
            e = (ent or {}).get("entities", {}).get(q, {})
            claims = e.get("claims", {})

            def first(pid):
                for c in claims.get(pid, []):
                    v = c.get("mainsnak", {}).get("datavalue", {}).get("value")
                    if v is not None:
                        return v
                return None

            country = first("P17") or first("P495")
            country_fr = None
            if isinstance(country, dict) and "id" in country:
                ce = http_json("https://www.wikidata.org/w/api.php", {"action": "wbgetentities", "format": "json", "ids": country["id"],
                                                                       "props": "labels", "languages": "fr"})
                country_fr = (ce or {}).get("entities", {}).get(country["id"], {}).get("labels", {}).get("fr", {}).get("value")
            inception = first("P571")
            year = None
            if isinstance(inception, dict):
                m = re.match(r"\+?(\d{4})", inception.get("time", ""))
                year = m.group(1) if m else None
            desc_fr = e.get("descriptions", {}).get("fr", {}).get("value") or e.get("descriptions", {}).get("en", {}).get("value") or ""
            nb = {"id": bid, "name": name, "logoUrl": None, "models": [], "annee_fondation": year, "description": desc_fr[:1].upper() + desc_fr[1:] if desc_fr else None,
                  "pays": country_fr, "rarete": rarity or 2, "wikidata": q}
            brands.append(nb)
            by_id[bid] = nb
            catalog[bid] = []
            brand_qids[bid] = [q]
            stats["brands_new"] += 1
            log(f"NOUVELLE marque {name} -> {q} ({desc}) pays={country_fr}")
            time.sleep(0.2)

    # 2. logos
    logo_files = {}
    brand_enwiki = {}
    for bid, qs in brand_qids.items():
        ent = http_json("https://www.wikidata.org/w/api.php", {"action": "wbgetentities", "format": "json", "ids": "|".join(qs), "props": "claims|sitelinks", "sitefilter": "enwiki"})
        for q in qs:
            e = (ent or {}).get("entities", {}).get(q, {})
            claims = e.get("claims", {})
            if bid not in brand_enwiki and e.get("sitelinks", {}).get("enwiki"):
                brand_enwiki[bid] = e["sitelinks"]["enwiki"]["title"]
            for pid in ("P154", "P8972"):
                for c in claims.get(pid, []):
                    v = c.get("mainsnak", {}).get("datavalue", {}).get("value")
                    if v and bid not in logo_files:
                        logo_files[bid] = "File:" + v.replace("_", " ")
        time.sleep(0.15)
    missing = {bid: t for bid, t in brand_enwiki.items() if bid not in logo_files}
    if missing:
        pi = wiki_page_images({"en": sorted(set(missing.values()))})
        for bid, t in missing.items():
            f = pi.get(("en", t))
            if f and re.search(r"logo|emblem|badge|wordmark|\.svg", f, re.I):
                logo_files[bid] = f
    for i in range(0, len(logo_files), 40):
        items = list(logo_files.items())[i:i + 40]
        d = http_json("https://commons.wikimedia.org/w/api.php", {"action": "query", "format": "json", "titles": "|".join(f for _, f in items),
                                                                  "prop": "imageinfo", "iiprop": "url", "iiurlwidth": 400})
        urls = {}
        if d:
            nm = {n["to"]: n["from"] for n in d.get("query", {}).get("normalized", [])}
            for p in d.get("query", {}).get("pages", {}).values():
                ii = (p.get("imageinfo") or [None])[0]
                if ii:
                    urls[nm.get(p["title"], p["title"])] = ii.get("thumburl") or ii.get("url")
        for bid, f in items:
            if urls.get(f):
                by_id[bid]["logoUrl"] = urls[f]
    log(f"logos trouvés: {sum(1 for b in brands if (b.get('logoUrl') or '').startswith('https://upload.wikimedia.org'))}/{len(brands)}")

    # 3. modèles
    for bid, qs in brand_qids.items():
        brand = by_id[bid]
        seen_q = set()
        wd_models = []
        for bq in qs:
            for wm in brand_models(bq):
                if wm["qid"] not in seen_q:
                    seen_q.add(wm["qid"])
                    wd_models.append(wm)
        if bid == "ford" and "mustang" in by_id:
            pass
        log(f"{brand['name']}: {len(wd_models)} modèles Wikidata")
        existing = catalog[bid]
        index = {norm(m["name"]): m for m in existing}
        other_names = sorted({norm(x["name"]) for x in brands if x["id"] != bid} - {norm(brand["name"])}, key=len, reverse=True)
        own = norm(brand["name"])
        kept = []
        for wm in wd_models:
            ln = norm(wm["label"])
            if not ln.startswith(own) and any(ln.startswith(o + " ") or ln == o for o in other_names if o and o not in own):
                continue
            kept.append(wm)
        wd_models = kept
        for wm in wd_models:
            wm["short"] = strip_brand(wm["label"], brand["name"])
            wm["key"] = norm(wm["short"])
        wd_by_key = {}
        for wm in wd_models:
            wd_by_key.setdefault(wm["key"], wm)

        # association modèles existants <-> wikidata
        for m in existing:
            k = norm(m["name"])
            k2 = norm(re.sub(r"\(.*?\)", "", m["name"]))
            wm = wd_by_key.get(k) or wd_by_key.get(k2)
            m["_wd"] = wm

        # nouveaux modèles
        target_id = bid
        for wm in wd_models:
            k = wm["key"]
            if not k or k in index or len(k) > 60:
                continue
            if bid == "ford" and k.startswith("mustang") and "mustang" in by_id:
                target_id = "mustang"
            else:
                target_id = bid
            if target_id != bid and norm(wm["short"]) in {norm(x["name"]) for x in catalog[target_id]}:
                continue
            new_id = f"{target_id}_{slug(wm['short'])}"
            ids = {x["id"] for x in catalog[target_id]}
            n = 2
            base = new_id
            while new_id in ids:
                new_id = f"{base}-{n}"
                n += 1
            nm = {"id": new_id, "name": wm["short"], "imageUrl": None, "production_years": years_label(wm["years"]), "tags": [], "_wd": wm, "_new": True}
            sp = wm["specs"]
            if "len" in sp and "wid" in sp and "hei" in sp:
                f = lambda v: int(v * 1000) if v < 10 else int(v)
                nm["dimensions_lwh_mm"] = f"{f(sp['len'])} x {f(sp['wid'])} x {f(sp['hei'])}"
            if "mass" in sp and 300 < sp["mass"] < 5000:
                nm["poids_kg"] = int(sp["mass"])
            if "speed" in sp and 50 < sp["speed"] < 500:
                nm["vitesse_max_kmh"] = int(sp["speed"])
            if "power" in sp and 20 < sp["power"] < 2500:
                nm["puissance_ch"] = int(sp["power"] * (1.36 if sp["power"] < 1200 else 1))
            catalog[target_id].append(nm)
            index[k] = nm

        time.sleep(0.5)

    # 4. images : candidates P18, puis image de l'article Wikipedia, puis recherche
    all_models = [(bid, m) for bid, ms in catalog.items() for m in ms]
    cand_files = set()
    wiki_titles = {"en": set(), "fr": set()}
    for bid, m in all_models:
        wm = m.get("_wd")
        if wm:
            for u in wm["images"][:3]:
                cand_files.add(file_title(u))
            for lang in ("en", "fr"):
                url = wm.get(f"{lang}wiki")
                if url:
                    wiki_titles[lang].add(urllib.parse.unquote(url.rsplit("/", 1)[-1]).replace("_", " "))
    log(f"pages Wikipedia à interroger: en={len(wiki_titles['en'])} fr={len(wiki_titles['fr'])}")
    page_imgs = wiki_page_images({k: sorted(v) for k, v in wiki_titles.items()})
    cand_files.update(page_imgs.values())
    log(f"fichiers Commons à vérifier: {len(cand_files)}")
    infos = commons_info(sorted(cand_files))

    def pick(m, brand_name):
        wm = m.get("_wd")
        cands = []
        if wm:
            cands += [file_title(u) for u in wm["images"][:3]]
            for lang in ("en", "fr"):
                url = wm.get(f"{lang}wiki")
                if url:
                    t = urllib.parse.unquote(url.rsplit("/", 1)[-1]).replace("_", " ")
                    if (lang, t) in page_imgs:
                        cands.append(page_imgs[(lang, t)])
        reasons = []
        for f in cands:
            ok, why = good_image(infos.get(f))
            if ok:
                return infos[f], None
            reasons.append(f"{f}: {why}")
        return None, reasons

    searched = 0
    for bid, m in all_models:
        brand = by_id[bid]
        info, reasons = pick(m, brand["name"])
        if info is None and not m.get("_new") and searched < 2500:
            searched += 1
            base = re.sub(r"\(.*?\)", "", m["name"]).strip()
            want = set(norm(base).split())
            for title, f in wiki_search_image(f"{brand['name']} {base} automobile"):
                tn = set(norm(title).split())
                if not want or not (want & tn) or norm(brand["name"]).split()[0] not in norm(title):
                    continue
                if f not in infos:
                    infos.update(commons_info([f]))
                ok, why = good_image(infos.get(f))
                if ok:
                    info = infos[f]
                    break
                reasons = (reasons or []) + [f"{f}: {why}"]
            time.sleep(0.15)
        if info:
            if m.get("imageUrl") != info["thumb"]:
                stats["img_replaced" if not m.get("_new") else "img_kept_new"] += 1
            m["imageUrl"] = info["thumb"]
            m["imageCredit"] = info["artist"] or "Wikimedia Commons"
            m["imageLicense"] = info["license"]
            m["imagePage"] = info["page"]
        else:
            stats["img_none"] += 1
            if not m.get("_new"):
                m["imageUrl"] = None
                for k in ("imageCredit", "imageLicense", "imagePage"):
                    m.pop(k, None)
                rejected.append(f"{brand['name']} {m['name']}: " + "; ".join((reasons or ["aucune photo trouvée"])[:3]))

    # 5. on ne garde un nouveau modèle que s'il a une photo valide (qualité du catalogue)
    for bid in catalog:
        before = len(catalog[bid])
        catalog[bid] = [m for m in catalog[bid] if not m.get("_new") or m.get("imageUrl")]
        stats["models_new"] += sum(1 for m in catalog[bid] if m.get("_new"))
        for m in catalog[bid]:
            m.pop("_wd", None)
            m.pop("_new", None)
            if m.get("tags") is None:
                m["tags"] = []
        if before != len(catalog[bid]):
            pass

    # marques nouvelles sans aucun modèle : on les retire
    brands_doc["brands"] = [b for b in brands if catalog.get(b["id"]) or b.get("wikidata") is None]
    for b in brands_doc["brands"]:
        b.pop("wikidata", None)

    for bid, models in catalog.items():
        if not models:
            continue
        with open(f"{DATA}/models_by_brand/{bid}.json", "w", encoding="utf-8") as f:
            json.dump({"models": models}, f, ensure_ascii=False, indent=1)
    with open(f"{DATA}/brands.json", "w", encoding="utf-8") as f:
        json.dump(brands_doc, f, ensure_ascii=False, indent=1)

    total = sum(len(v) for v in catalog.values())
    with_img = sum(1 for v in catalog.values() for m in v if m.get("imageUrl"))
    log(f"STATS {stats} total_modeles={total} avec_photo={with_img} marques={len(brands_doc['brands'])}")
    with open(f"{REPORT_DIR}/catalog_report.md", "w", encoding="utf-8") as f:
        f.write(f"# Rapport catalogue\n\n{stats}\n\nModèles: {total}, avec photo vérifiée: {with_img}, marques: {len(brands_doc['brands'])}\n\n")
        f.write("## Modèles existants sans photo valide\n\n" + "\n".join(f"- {r}" for r in rejected[:3000]) + "\n\n## Journal\n\n")
        f.write("\n".join(log_lines[-4000:]))


if __name__ == "__main__":
    main()
