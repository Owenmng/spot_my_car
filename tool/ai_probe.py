import base64, json, re, sys, time, requests
UA = "SpotMyCarCatalogBot/1.0 (https://github.com/Owenmng/spot_my_car)"
opts = open("lib/firebase_options.dart").read()
android = opts[opts.index("android"):]
KEY = re.search(r"apiKey: '([^']+)'", android).group(1)
APPID = re.search(r"appId: '([^']+)'", android).group(1)
PROJECT = "car-spotter-app-779f2"
TESTS = {
    "Peugeot 208 II": "File:Peugeot 208 (II) 1X7A0262.jpg",
    "Porsche 911 992": "File:Porsche 992 Carrera 4S IMG 3285.jpg",
    "VW Golf 8": "File:VW Golf 8 IMG 3586.jpg",
    "Renault Clio V": "File:Renault Clio V IMG 3326.jpg",
}
S = requests.Session(); S.headers["User-Agent"] = UA
def thumb(title):
    d = S.get("https://commons.wikimedia.org/w/api.php", params={"action": "query", "format": "json", "titles": title, "prop": "imageinfo", "iiprop": "url", "iiurlwidth": 1200}).json()
    for p in d["query"]["pages"].values():
        if "imageinfo" in p: return p["imageinfo"][0]["thumburl"]
    return None
def search_file(q):
    d = S.get("https://commons.wikimedia.org/w/api.php", params={"action": "query", "format": "json", "list": "search", "srnamespace": 6, "srsearch": q, "srlimit": 1}).json()
    r = d["query"]["search"]; return r[0]["title"] if r else None

schema = {"type": "OBJECT", "properties": {
  "isRealPhoto": {"type": "BOOLEAN"},
  "vehicleType": {"type": "STRING", "enum": ["car", "motorcycle", "truck", "van", "bus", "other", "none"]},
  "candidates": {"type": "ARRAY", "items": {"type": "OBJECT", "properties": {
      "make": {"type": "STRING"}, "model": {"type": "STRING"}, "variant": {"type": "STRING"}, "generation": {"type": "STRING"},
      "yearFrom": {"type": "INTEGER"}, "yearTo": {"type": "INTEGER"}, "confidence": {"type": "INTEGER"}, "cues": {"type": "STRING"}},
      "required": ["make", "model", "confidence"]}},
  "color": {"type": "STRING"}, "plateText": {"type": "STRING"}},
  "required": ["isRealPhoto", "vehicleType"]}

for label, title in TESTS.items():
    url = thumb(title) or thumb(search_file(label + " car") or "")
    if not url:
        print(label, "NO IMAGE"); continue
    img = S.get(url).content
    print("\n===", label, len(img), "bytes")
    for model in ["gemini-3.8-flash", "gemini-3.5-flash-lite", "gemini-2.5-flash"]:
        body = {"contents": [{"role": "user", "parts": [{"text": "Identifie la voiture principale (marque, modèle, génération). Réponds en JSON."},
                                                          {"inlineData": {"mimeType": "image/jpeg", "data": base64.b64encode(img).decode()}}]}],
                "generationConfig": {"temperature": 0.1, "responseMimeType": "application/json", "responseSchema": schema}}
        for ep in [f"https://firebasevertexai.googleapis.com/v1beta/projects/{PROJECT}/models/{model}:generateContent"]:
            r = requests.post(ep, json=body, headers={"x-goog-api-key": KEY, "X-Firebase-AppId": APPID, "x-goog-api-client": "gl-dart/3 fire/5"}, timeout=90)
            txt = r.text
            if r.ok:
                try:
                    txt = r.json()["candidates"][0]["content"]["parts"][0]["text"]
                except Exception: pass
            print(model, r.status_code, txt[:600].replace("\n", " "))
        time.sleep(1)
