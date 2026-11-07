"""Cherche une photo vérifiée pour chaque modèle du catalogue qui n'en a pas encore."""
import json, glob, re, sys, time
sys.path.insert(0, "tool")
from catalog_builder import (http_json, commons_info, good_image, wiki_search_image, norm, log, log_lines, DATA)

def commons_search(q, limit=8):
    d = http_json("https://commons.wikimedia.org/w/api.php", {
        "action": "query", "format": "json", "list": "search", "srnamespace": 6, "srsearch": q, "srlimit": limit})
    return [x["title"] for x in (d or {}).get("query", {}).get("search", [])]

def main():
    brands = {b["id"]: b for b in json.load(open(f"{DATA}/brands.json", encoding="utf-8"))["brands"]}
    found = missing = 0
    still = []
    for f in sorted(glob.glob(f"{DATA}/models_by_brand/*.json")):
        bid = f.split("/")[-1][:-5]
        brand = brands.get(bid, {"name": bid})
        doc = json.load(open(f, encoding="utf-8"))
        changed = False
        for m in doc["models"]:
            if m.get("imageUrl"):
                continue
            missing += 1
            base = re.sub(r"\(.*?\)", "", m["name"]).strip()
            gen = re.findall(r"\((.*?)\)", m["name"])
            bname = brand["name"] if bid != "mustang" else "Ford"
            want = set(norm(base).split()) | ({"mustang"} if bid == "mustang" else set())
            brand_tok = norm(bname).split()[0]
            queries = [f"{bname} {base} {gen[0]}" if gen else None, f"{bname} {base}", f"{bname} {base} car"]
            cands = []
            for q in [q for q in queries if q]:
                for t in commons_search(q):
                    tn = norm(t)
                    if brand_tok in tn and want and all(w in tn.split() or w in tn for w in want):
                        cands.append(t)
                time.sleep(0.2)
                if len(cands) >= 6:
                    break
            for title, ft in wiki_search_image(f"{bname} {base}"):
                tn = norm(title)
                if brand_tok in tn and all(w in tn for w in want):
                    cands.append(ft)
            seen = []
            for c in cands:
                if c not in seen:
                    seen.append(c)
            infos = commons_info(seen[:10]) if seen else {}
            pick = None
            for c in seen[:10]:
                ok, why = good_image(infos.get(c))
                if ok:
                    pick = infos[c]
                    break
            if pick:
                m["imageUrl"] = pick["thumb"]
                m["imageCredit"] = pick["artist"] or "Wikimedia Commons"
                m["imageLicense"] = pick["license"]
                m["imagePage"] = pick["page"]
                found += 1
                changed = True
                log(f"OK {bname} {m['name']} <- {pick['title']}")
            else:
                still.append(f"{bname} {m['name']}")
        if changed:
            json.dump(doc, open(f, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    log(f"FILL found={found} missing_before={missing} still={len(still)}")
    with open("tool/reports/missing_images.md", "w", encoding="utf-8") as fh:
        fh.write(f"# Modèles sans photo ({len(still)})\n\n" + "\n".join(f"- {x}" for x in still))

if __name__ == "__main__":
    main()
