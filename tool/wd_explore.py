import json, sys, time, urllib.parse, urllib.request
UA = "SpotMyCarCatalogBot/1.0 (https://github.com/Owenmng/spot_my_car)"
def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/sparql-results+json, application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read())
def sparql(q):
    return get("https://query.wikidata.org/sparql?format=json&query=" + urllib.parse.quote(q))["results"]["bindings"]

print("== classes of items with manufacturer that is car manufacturer ==")
q = """SELECT ?cls ?clsLabel (COUNT(DISTINCT ?m) AS ?n) WHERE {
  ?m wdt:P176 ?man . ?man wdt:P31/wdt:P279* wd:Q786820 .
  ?m wdt:P31 ?cls .
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
} GROUP BY ?cls ?clsLabel ORDER BY DESC(?n) LIMIT 40"""
try:
    for b in sparql(q): print(b["cls"]["value"].split("/")[-1], b.get("clsLabel",{}).get("value"), b["n"]["value"])
except Exception as e: print("ERR", e)

print("== property usage on automobile models (Q3231690) ==")
for p in ["P18","P176","P1716","P571","P2031","P2032","P576","P2669","P729","P730","P580","P582","P2109","P2052","P2067","P2043","P2049","P2048","P1056","P279","P179","P155","P156","P1269","P2754"]:
    q = f"SELECT (COUNT(DISTINCT ?m) AS ?n) WHERE {{ ?m wdt:P31 wd:Q3231690 . ?m wdt:{p} ?v . }}"
    try:
        print(p, sparql(q)[0]["n"]["value"])
    except Exception as e: print(p, "ERR", e)
    time.sleep(1)

print("== sample ==")
q = """SELECT ?m ?mLabel ?manLabel ?brandLabel ?img ?inc ?end WHERE {
 VALUES ?m { wd:Q1065599 wd:Q181471 wd:Q1636 } 
 OPTIONAL{?m wdt:P176 ?man} OPTIONAL{?m wdt:P1716 ?brand} OPTIONAL{?m wdt:P18 ?img}
 OPTIONAL{?m wdt:P571 ?inc} OPTIONAL{?m wdt:P2669 ?end}
 SERVICE wikibase:label { bd:serviceParam wikibase:language "fr,en". } }"""
try:
    for b in sparql(q): print({k: v["value"] for k, v in b.items()})
except Exception as e: print("ERR", e)

print("== brand search ==")
for name in ["Peugeot","BMW","Cupra","Aixam","Lynk & Co","Mustang","AMG","KTM"]:
    d = get("https://www.wikidata.org/w/api.php?action=wbsearchentities&format=json&language=fr&type=item&limit=5&search=" + urllib.parse.quote(name))
    print(name, [(x["id"], x.get("label"), x.get("description")) for x in d.get("search", [])])
    time.sleep(0.5)
