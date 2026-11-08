"""Traduit assets/i18n/fr.json vers en/es/de/it/pt avec Gemini (offre gratuite).

Seules les clés manquantes sont traduites : relancer après avoir ajouté des textes
ne retraduit pas tout. Les marqueurs {0}, {1}… et les emojis sont conservés.
"""
import json, os, re, sys, time
import requests

opts = open("lib/firebase_options.dart").read()
android = opts[opts.index("android"):]
KEY = re.search(r"apiKey: '([^']+)'", android).group(1)
APPID = re.search(r"appId: '([^']+)'", android).group(1)
URL = "https://firebasevertexai.googleapis.com/v1beta/projects/car-spotter-app-779f2/models/{}:generateContent"

LANGS = {
    "en": "English (US). Use 'you' casually.",
    "es": "Spanish (Spain). Tutea al usuario (tú).",
    "de": "German. Duze den Nutzer (du).",
    "it": "Italian. Dai del tu all'utente.",
    "pt": "Brazilian Portuguese. Use 'você'.",
}

CONTEXT = (
    "You translate the user interface of 'Spot My Car', a mobile game for car enthusiasts: users photograph cars in the street, "
    "an AI recognises the model, cars become collectible cards with rarity tiers, XP, levels, achievements, duels and a blind test quiz with friends. "
    "Tone: friendly, punchy, like a premium car-culture app. Keep texts about the same length (they must fit buttons). "
    "Keep placeholders such as {0} {1} exactly, keep emojis, punctuation style and line breaks (\\n). "
    "Do not translate brand or model names (Ferrari, Porsche 911, Clio…), nor 'XP', nor the app name 'Spot My Car'/'SpotMyCar'. "
    "Car-spotting vocabulary: 'spot' (noun/verb) may stay 'spot' in English; 'Paddock' stays 'Paddock'. "
    "Rarity tiers: Commune, Sportive, Rare, Exotique, Mythique → translate naturally (e.g. Common, Sporty, Rare, Exotic, Mythic)."
)


def call(model, prompt, thinking):
    body = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.2,
            "responseMimeType": "application/json",
            "responseSchema": {"type": "ARRAY", "items": {"type": "STRING"}},
        },
    }
    if thinking:
        body["generationConfig"]["thinkingConfig"] = thinking
    r = requests.post(URL.format(model), json=body, headers={"x-goog-api-key": KEY, "X-Firebase-AppId": APPID}, timeout=180)
    if not r.ok:
        raise RuntimeError(f"{r.status_code} {r.text[:200]}")
    return json.loads(r.json()["candidates"][0]["content"]["parts"][0]["text"])


def translate(batch, lang):
    prompt = (f"{CONTEXT}\nTarget language: {LANGS[lang]}\n"
              f"Translate each French string of this JSON array. Return a JSON array of the same length and order.\n"
              + json.dumps(batch, ensure_ascii=False))
    for model, thinking in (("gemini-3.5-flash-lite", {"thinkingLevel": "LOW"}), ("gemini-3.5-flash-lite", None), ("gemini-3.8-flash", {"thinkingBudget": 0})):
        for attempt in range(4):
            try:
                out = call(model, prompt, thinking)
                if len(out) == len(batch):
                    return out
                print(f"  longueur incorrecte ({len(out)}/{len(batch)}), nouvel essai")
            except Exception as e:
                print(f"  {model}: {e}")
                time.sleep(8 * (attempt + 1))
    return None


def placeholders_ok(src, dst):
    return sorted(re.findall(r"\{\d+\}", src)) == sorted(re.findall(r"\{\d+\}", dst))


fr = json.load(open("assets/i18n/fr.json", encoding="utf-8"))
keys = list(fr.keys())
for lang in LANGS:
    path = f"assets/i18n/{lang}.json"
    current = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
    todo = [k for k in keys if not current.get(k)]
    print(f"{lang}: {len(todo)} à traduire")
    for i in range(0, len(todo), 60):
        batch = todo[i:i + 60]
        out = translate(batch, lang)
        if out is None:
            print(f"  lot {i} abandonné")
            continue
        for k, v in zip(batch, out):
            if isinstance(v, str) and v.strip() and placeholders_ok(k, v):
                current[k] = v
        json.dump(dict(sorted(current.items())), open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        time.sleep(1)
    # on retire les clés disparues
    current = {k: current[k] for k in keys if k in current}
    json.dump(dict(sorted(current.items())), open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"{lang}: {len(current)}/{len(keys)}")
