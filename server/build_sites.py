"""Génère server/apps_script/Sites.gs : pages web + règles Firestore encodées en base64
(HtmlService modifie les caractères < > &, donc on évite de passer par des fichiers HTML)."""
import base64, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
d = root / 'server/apps_script'
files = {
    '/index.html': d / 'site_index.html',
    '/admin/index.html': d / 'site_admin.html',
    '/confidentialite/index.html': d / 'site_privacy.html',
}
out = ['/** Fichier généré par server/build_sites.py : ne pas modifier à la main. */', 'const SITE_FILES = {']
for k, p in files.items():
    out.append(f"  '{k}': '{base64.b64encode(p.read_bytes()).decode()}',")
out.append('};')
out.append(f"const FIRESTORE_RULES_B64 = '{base64.b64encode((root / 'firestore.rules').read_bytes()).decode()}';")
(d / 'Sites.gs').write_text('\n'.join(out) + '\n')
print('ok', (d / 'Sites.gs').stat().st_size)
