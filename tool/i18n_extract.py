"""Enveloppe les textes d'interface de lib/ dans tr(...) et génère assets/i18n/fr.json.

    'Bonjour'                 -> tr('Bonjour')
    'Encore ${n} XP'          -> tr('Encore {0} XP', [n])

Usage : python3 tool/i18n_extract.py [--write]
Les textes déjà enveloppés sont simplement recensés (relançable sans risque).
"""
import glob, json, re, sys

WRITE = '--write' in sys.argv
SKIP_FILES = {
    'lib/firebase_options.dart', 'lib/l10n/i18n.dart', 'lib/services/gemini_client.dart',
    'lib/shared/plate_formats.dart', 'lib/plate_input_formatter.dart', 'lib/services/custom_cache_manager.dart',
    # Valeurs internes (stockées ou servant de clés) : traduites à l'affichage seulement.
    'lib/shared/app_data.dart', 'lib/theme/app_theme.dart', 'lib/models/rarity.dart', 'lib/models/level_model.dart',
    'lib/services/audio_service.dart', 'lib/services/user_stats_service.dart', 'lib/services/fact_sheet_service.dart',
    'lib/main.dart',
}
# Textes envoyés à l'IA ou aux services : jamais traduits.
SKIP_REGIONS = [('lib/services/vehicle_recognition_service.dart', 'String _prompt('),
                ('lib/services/fact_sheet_service.dart', 'String _prompt(')]

BAD_BEFORE = re.compile(
    r"(import|export|part|collection\(|\.doc\(|where\(|orderBy\(|getString\(|setString\(|getBool\(|setBool\(|getInt\(|setInt\("
    r"|getStringList\(|setStringList\(|remove\(|print\(|debugPrint\(|log\(|RegExp\(|Uri\.parse\(|Uri\(|Image\.asset\(|AssetImage\("
    r"|this\.\w+\s*=|loadString\(|DateFormat\(|startsWith\(|endsWith\(|split\(|replaceAll\(|replaceFirst\(|contains\(|indexOf\(|FieldPath|"
    r"\bcase|==|!=|\btr\(|ValueKey\(|Key\(|fontFamily|jsonDecode|headers|Exception\(|Error\(|assert\(|parse\(|fromEnvironment|"
    r"mimeType|scheme|path:|host:|query:|contentType|'Content-Type'|'Accept'|SharePlus|XFile|name:\s*'spotmycar|Platform\.)\s*$")
IDENT = re.compile(r"^[a-z0-9_.\-/:@#]*$")
WORDY = re.compile(r"[A-Za-zÀ-ÿ]")


def literals(src):
    """Yield (start, end, raw_text, parts) for each Dart string literal outside comments."""
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith('//', i):
            i = src.find('\n', i)
            if i < 0:
                return
            continue
        if src.startswith('/*', i):
            i = src.find('*/', i) + 2
            continue
        raw = False
        if c in 'rR' and i + 1 < n and src[i + 1] in '\'"' and (i == 0 or not (src[i - 1].isalnum() or src[i - 1] == '_')):
            raw = True
            i += 1
            c = src[i]
        if c in '\'"':
            start = i - (1 if raw else 0)
            q = src[i:i + 3] if src[i:i + 3] in ("'''", '"""') else c
            j = i + len(q)
            parts = []  # list of ('text', str) / ('expr', str)
            buf = ''
            while j < n and not src.startswith(q, j):
                ch = src[j]
                if ch == '\\' and not raw:
                    buf += src[j:j + 2]
                    j += 2
                    continue
                if ch == '$' and not raw:
                    if j + 1 < n and src[j + 1] == '{':
                        depth, k = 1, j + 2
                        while k < n and depth:
                            if src[k] == '{':
                                depth += 1
                            elif src[k] == '}':
                                depth -= 1
                            elif src[k] in '\'"':  # nested string inside interpolation
                                qq = src[k]
                                k += 1
                                while k < n and src[k] != qq:
                                    k += 2 if src[k] == '\\' else 1
                            k += 1
                        parts.append(('text', buf)); buf = ''
                        parts.append(('expr', src[j + 2:k - 1]))
                        j = k
                        continue
                    m = re.match(r'\$([A-Za-z_]\w*)', src[j:])
                    if m:
                        parts.append(('text', buf)); buf = ''
                        parts.append(('expr', m.group(1)))
                        j += m.end()
                        continue
                buf += ch
                j += 1
            parts.append(('text', buf))
            end = j + len(q)
            yield start, end, q, raw, parts
            i = end
            continue
        i += 1


def is_ui(path, src, start, end, q, raw, parts):
    if raw:
        return False
    text = ''.join(p[1] if p[0] == 'text' else '{}' for p in parts)
    plain = ''.join(p[1] for p in parts if p[0] == 'text').strip()
    if not WORDY.search(plain) or len(plain) < 2:
        return False
    if len(text) > 700 or 'JSON' in text or 'Réponds' in text or 'Tu es ' in text or 'identifiant' in text:
        return False
    if IDENT.match(plain) and ' ' not in plain:
        return False
    if '://' in text or text.startswith(('assets/', 'http', 'package:', 'dart:')):
        return False
    if ' ' not in plain and not re.search(r'[À-ÿ!?…’«»]', plain) and not plain[:1].isupper():
        return False
    # Codes, formats et identifiants en majuscules sans espace (FR, XP, AA-123-AA…)
    if ' ' not in plain and re.fullmatch(r'[A-Z0-9#\-_.]+', plain):
        return False
    line_start = src.rfind('\n', 0, start) + 1
    line_end = src.find('\n', end)
    line = src[line_start:line_end]
    before = src[line_start:start]
    if "'description'" in line or 'responseSchema' in line:
        return False
    # Ligne qui n'est qu'une liste de valeurs ('Noir', 'Blanc', …) : valeurs internes.
    if re.fullmatch(r"\s*(?:(?:tr\()?'[^']*'\)?,\s*){3,}(?:(?:tr\()?'[^']*'\)?)?,?\s*", line):
        return False
    if before.lstrip().startswith(('import', 'export', 'part', '//', '///')):
        return False
    if BAD_BEFORE.search(before):
        return False
    after = src[end:end + 6].lstrip()
    prev = before.rstrip()[-1:] if before.strip() else ''
    if after.startswith(':') and prev != '?':  # clé de map
        return False
    if after.startswith('=>'):  # motif de switch
        return False
    if before.rstrip().endswith('['):  # m['clé']
        return False
    for f, marker in SKIP_REGIONS:
        if path == f:
            k = src.find(marker)
            if k >= 0 and k < start:
                close = src.find('\n  }\n', k)
                if close < 0 or start < close:
                    return False
    return True


def esc(s):
    return s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$')


keys = {}
changed = 0
for path in sorted(glob.glob('lib/**/*.dart', recursive=True)):
    if path in SKIP_FILES:
        continue
    src = open(path, encoding='utf-8').read()
    out, last, n_here = [], 0, 0
    for start, end, q, raw, parts in literals(src):
        before = src[max(0, start - 4):start]
        if before.endswith('tr('):
            # déjà traduit : on recense la clé
            key = ''.join(p[1] for p in parts if p[0] == 'text')
            if q in ("'", '"'):
                keys[bytes(key, 'utf-8').decode('unicode_escape').encode('latin-1', 'ignore').decode('utf-8', 'ignore') if False else key] = 1
            continue
        if not is_ui(path, src, start, end, q, raw, parts):
            continue
        exprs, tpl = [], ''
        for kind, val in parts:
            if kind == 'text':
                tpl += val
            else:
                tpl += '{%d}' % len(exprs)
                exprs.append(val)
        if q in ("'''", '"""'):
            tpl = tpl.replace('\n', '\\n')
        # normalise : on réécrit en simple quote
        decoded = tpl.replace("\\'", "'").replace('\\"', '"').replace('\\$', '$')
        key = decoded.encode('utf-8').decode('utf-8')
        key = key.replace('\\n', '\n')
        keys[key] = 1
        lit = "'" + esc(key).replace('\n', '\\n') + "'"
        call = f"tr({lit}" + (f", [{', '.join(e.strip() for e in exprs)}]" if exprs else '') + ')'
        out.append(src[last:start]); out.append(call); last = end
        n_here += 1
    if n_here:
        out.append(src[last:])
        new = ''.join(out)
        if 'l10n/i18n.dart' not in new:
            m = re.search(r"^import [^\n]+;\n", new, re.M)
            pos = m.start() if m else 0
            new = new[:pos] + "import 'package:spot_my_car/l10n/i18n.dart';\n" + new[pos:]
        changed += n_here
        if WRITE:
            open(path, 'w', encoding='utf-8').write(new)
        print(f'{path}: {n_here}')

# Recensement final (y compris les tr() déjà présents) depuis les fichiers réécrits
allkeys = {}
pat = re.compile(r"\btr\('((?:[^'\\]|\\.)*)'")
for path in glob.glob('lib/**/*.dart', recursive=True):
    s = open(path, encoding='utf-8').read()
    for m in pat.finditer(s):
        k = m.group(1).replace("\\'", "'").replace('\\$', '$').replace('\\n', '\n').replace('\\\\', '\\')
        allkeys[k] = k
print('wrapped', changed, 'keys', len(allkeys))
if WRITE:
    json.dump(dict(sorted(allkeys.items())), open('assets/i18n/fr.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
