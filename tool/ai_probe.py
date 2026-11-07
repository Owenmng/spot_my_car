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

import io
try:
    from PIL import Image
except ImportError:
    Image = None
for label, title in list(TESTS.items())[:3]:
    url = thumb(title) or thumb(search_file(label + " car") or "")
    if not url:
        print(label, "NO IMAGE"); continue
    img = S.get(url).content
    if Image:
        im = Image.open(io.BytesIO(img)).convert("RGB"); im.thumbnail((1024, 1024)); b = io.BytesIO(); im.save(b, "JPEG", quality=80); img = b.getvalue()
    print("\n===", label, len(img), "bytes")
    for model, think in [("gemini-3.8-flash", None), ("gemini-3.8-flash", {"thinkingLevel": "MINIMAL"}), ("gemini-3.8-flash", {"thinkingLevel": "LOW"}), ("gemini-3.8-flash", {"thinkingBudget": 0}), ("gemini-3.5-flash-lite", None), ("gemini-3.5-flash-lite", {"thinkingLevel": "MINIMAL"})]:
        gc = {"temperature": 0.1, "responseMimeType": "application/json", "responseSchema": schema}
        if think: gc["thinkingConfig"] = think
        body = {"contents": [{"role": "user", "parts": [{"text": "Identifie la voiture principale (marque, modèle, génération). Réponds en JSON."},
                                                          {"inlineData": {"mimeType": "image/jpeg", "data": base64.b64encode(img).decode()}}]}],
                "generationConfig": gc}
        t = time.time()
        r = requests.post(f"https://firebasevertexai.googleapis.com/v1beta/projects/{PROJECT}/models/{model}:generateContent", json=body, headers={"x-goog-api-key": KEY, "X-Firebase-AppId": APPID}, timeout=120)
        dt = time.time() - t
        out = r.text[:200].replace("\n", " ")
        if r.ok:
            try:
                j = json.loads(r.json()["candidates"][0]["content"]["parts"][0]["text"]); c = (j.get("candidates") or [{}])[0]
                out = f"{c.get('make')} {c.get('model')} {c.get('generation')} conf={c.get('confidence')} usage={r.json().get('usageMetadata',{}).get('thoughtsTokenCount')}"
            except Exception as e: out = str(e)
        print(f"{model:24} {str(think):30} {r.status_code} {dt:5.1f}s {out}")
