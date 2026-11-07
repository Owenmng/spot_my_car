"""Génère la bande-son de Spot My Car (musique d'ambiance + effets), 100 % synthétisée.

Aucun sample externe : pas de droits à payer, pas de licence à vérifier.
Usage : python3 tool/sound_synth.py  (nécessite numpy, scipy, ffmpeg)
"""
import os
import subprocess
import tempfile

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')
rng = np.random.default_rng(7)


def t_(dur):
    return np.arange(int(dur * SR)) / SR


def lp(x, f, order=2):
    return sosfilt(butter(order, f, 'low', fs=SR, output='sos'), x)


def hp(x, f, order=2):
    return sosfilt(butter(order, f, 'high', fs=SR, output='sos'), x)


def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], 'band', fs=SR, output='sos'), x)


def env(n, a, r, sustain=None):
    """Enveloppe attaque / relâche exponentielle."""
    e = np.ones(n)
    na = max(1, int(a * SR))
    e[:na] = np.linspace(0, 1, na)
    if sustain is None:
        e[na:] = np.exp(-np.arange(n - na) / (r * SR))
    else:
        ns = int(sustain * SR)
        rest = n - na - ns
        if rest > 0:
            e[na + ns:] = np.exp(-np.arange(rest) / (r * SR))
    return e


def saw(f, t):
    return 2 * ((f * t) % 1) - 1


def midi(n):
    return 440 * 2 ** ((n - 69) / 12)


def export(name, stereo, bitrate='128k'):
    stereo = np.asarray(stereo, dtype=np.float64)
    peak = np.max(np.abs(stereo)) or 1
    stereo = stereo / peak * 0.89
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        wavfile.write(f.name, SR, (stereo * 32767).astype(np.int16))
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', f.name, '-codec:a', 'libmp3lame', '-b:a', bitrate,
                        os.path.join(OUT, name)], check=True)
    os.unlink(f.name)
    print('écrit', name, f'{len(stereo) / SR:.2f}s')


def circular_reverb(x, seconds=2.2, mix=0.25):
    """Réverbe circulaire : la queue retombe au début, la boucle reste parfaitement raccord."""
    n = len(x)
    ir_n = int(seconds * SR)
    ir = rng.standard_normal(ir_n) * np.exp(-np.arange(ir_n) / (0.45 * SR))
    ir = lp(ir, 5000)
    pad = np.zeros(n)
    pad[:ir_n] = ir
    wet = np.real(np.fft.ifft(np.fft.fft(x) * np.fft.fft(pad)))
    wet = wet / (np.max(np.abs(wet)) or 1) * np.max(np.abs(x))
    return x * (1 - mix) + wet * mix


# ------------------------------------------------------------------ musique

def music():
    """« Night drive » : synthwave feutrée, 92 BPM, 16 mesures qui bouclent sans couture."""
    bpm = 92
    beat = 60 / bpm
    bars = 16
    n = int(bars * 4 * beat * SR)
    L = np.zeros(n)
    R = np.zeros(n)

    # Progression mineure nocturne : Am9 – Fmaj7 – Cmaj7 – Em7 (2 mesures chacune).
    chords = [[57, 60, 64, 67, 71], [53, 57, 60, 64], [48, 55, 59, 64], [52, 55, 59, 62]]
    roots = [45, 41, 48, 40]

    # Nappe : scies désaccordées filtrées, attaque lente.
    for i in range(bars // 2):
        ch = chords[i % 4]
        start = int(i * 8 * beat * SR)
        dur = 8 * beat + 0.6
        t = t_(dur)
        e = env(len(t), 1.2, 0.5, sustain=8 * beat - 1.2)
        for k, note in enumerate(ch):
            f = midi(note)
            v = sum(saw(f * d, t + rng.random()) for d in (0.996, 1.0, 1.004)) / 3
            v = lp(v, 1400) * e * 0.06
            pan = 0.35 + 0.3 * (k / len(ch))
            end = min(n, start + len(v))
            seg = v[:end - start]
            L[start:end] += seg * (1 - pan)
            R[start:end] += seg * pan
            if end - start < len(v):  # la nappe déborde : on la replie au début pour boucler
                tail = v[end - start:]
                L[:len(tail)] += tail * (1 - pan)
                R[:len(tail)] += tail * pan

    # Kick doux + basse en croches avec « pompe ».
    pump = np.ones(n)
    kick_t = t_(0.35)
    kick = np.sin(2 * np.pi * (45 * kick_t + 90 * (1 - np.exp(-kick_t * 30)) / 30)) * np.exp(-kick_t * 9) * 0.5
    for b in range(bars * 4):
        s = int(b * beat * SR)
        if b >= 8:  # le beat arrive après 2 mesures d'intro
            e = min(n, s + len(kick))
            L[s:e] += kick[:e - s]
            R[s:e] += kick[:e - s]
        d = int(0.25 * SR)
        pump[s:s + d] = np.minimum(pump[s:s + d], 0.45 + 0.55 * np.linspace(0, 1, len(pump[s:s + d])) ** 0.6)

    for step in range(bars * 8):
        bar = step // 8
        root = roots[(bar // 2) % 4]
        s = int(step * beat / 2 * SR)
        t = t_(beat / 2)
        f = midi(root - 12 + (12 if step % 8 == 7 else 0))
        v = (np.sin(2 * np.pi * f * t) + 0.35 * lp(saw(f, t), 600)) * env(len(t), 0.004, 0.18) * 0.22
        e = min(n, s + len(v))
        L[s:e] += v[:e - s]
        R[s:e] += v[:e - s]

    # Charley en contretemps + claquement feutré sur 2 et 4.
    for b in range(8, bars * 4):
        s = int((b + 0.5) * beat * SR)
        h = hp(rng.standard_normal(int(0.05 * SR)), 7000) * env(int(0.05 * SR), 0.001, 0.012) * 0.07
        e = min(n, s + len(h))
        L[s:e] += h[:e - s] * 0.7
        R[s:e] += h[:e - s]
        if b % 2 == 1:
            s = int(b * beat * SR)
            sn = bp(rng.standard_normal(int(0.2 * SR)), 900, 5000) * env(int(0.2 * SR), 0.002, 0.06) * 0.12
            e = min(n, s + len(sn))
            L[s:e] += sn[:e - s]
            R[s:e] += sn[:e - s]

    # Arpège cristallin sur la deuxième moitié.
    pattern = [0, 2, 3, 4, 3, 2, 1, 2]
    for step in range(bars * 8 // 2, bars * 8):
        bar = step // 8
        ch = chords[(bar // 2) % 4]
        note = ch[pattern[step % 8] % len(ch)] + 12
        s = int(step * beat / 2 * SR)
        t = t_(0.5)
        f = midi(note)
        v = (np.sin(2 * np.pi * f * t) + 0.25 * np.sin(4 * np.pi * f * t)) * env(len(t), 0.003, 0.12) * 0.07
        # écho ping-pong en croche pointée
        d = int(0.75 * beat * SR)
        for k, (lg, rg) in enumerate([(1, 0.6), (0.25, 0.5), (0.3, 0.12)]):
            ss = (s + k * d) % n
            e = min(n, ss + len(v))
            L[ss:e] += v[:e - ss] * lg
            R[ss:e] += v[:e - ss] * rg

    L *= pump ** 0.5
    R *= pump ** 0.5
    L = circular_reverb(L)
    R = circular_reverb(R)
    L = lp(hp(L, 30), 9000)
    R = lp(hp(R, 30), 9000)
    export('musique_calme.mp3', np.stack([L, R], axis=1), bitrate='112k')


# ------------------------------------------------------------------ effets

def mono_to_st(x, width=0.0):
    return np.stack([x, np.roll(x, int(width * SR))], axis=1)


def sfx_tap():
    t = t_(0.06)
    x = np.sin(2 * np.pi * 1800 * t) * np.exp(-t * 140) * 0.6 + bp(rng.standard_normal(len(t)), 2000, 6000) * np.exp(-t * 300) * 0.25
    export('clic_principal.mp3', mono_to_st(x))


def sfx_tick():
    t = t_(0.04)
    x = np.sin(2 * np.pi * 2600 * t) * np.exp(-t * 220) * 0.4
    export('clic_leger.mp3', mono_to_st(x))


def sfx_whoosh():
    t = t_(0.35)
    noise = rng.standard_normal(len(t))
    sweep = np.zeros_like(noise)
    # balayage de filtre par blocs
    blocks = 14
    size = len(t) // blocks
    for i in range(blocks):
        f = 400 + 3800 * (i / blocks) ** 1.4
        seg = bp(noise, f * 0.7, min(f * 1.4, 18000))[i * size:(i + 1) * size]
        sweep[i * size:(i + 1) * size] = seg
    x = sweep * np.sin(np.pi * t / t[-1]) ** 1.5 * 0.5
    export('transition_page.mp3', mono_to_st(x, 0.004))


def chime(notes, dur=1.2, gap=0.07, decay=0.45, vol=0.35):
    t = t_(dur + gap * len(notes))
    x = np.zeros_like(t)
    for i, nn in enumerate(notes):
        s = int(i * gap * SR)
        tt = t_(dur)
        f = midi(nn)
        v = (np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(2 * np.pi * 2 * f * tt) + 0.12 * np.sin(2 * np.pi * 3.01 * f * tt))
        x[s:s + len(tt)] += v * env(len(tt), 0.004, decay) * vol
    return x


def sfx_notification():
    x = chime([76, 83], dur=0.8, gap=0.11, decay=0.25)
    export('notification.mp3', mono_to_st(x, 0.006))


def rev(dur=1.1, f0=55, f1=150):
    """Montée en régime : quelques harmoniques de moteur 4 cylindres qui accélèrent."""
    t = t_(dur)
    curve = np.clip(t / (dur * 0.75), 0, 1) ** 1.6
    f = f0 + (f1 - f0) * curve
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = sum(a * np.sign(np.sin(k * ph)) for k, a in [(1, 0.5), (2, 0.3), (3, 0.15), (4, 0.1)])
    x = lp(x, 1800) + 0.05 * bp(rng.standard_normal(len(t)), 300, 2500)
    e = np.minimum(1, t / 0.08) * np.exp(-np.maximum(0, t - dur * 0.8) * 14)
    return x * e * 0.4


def blowoff(dur=0.35):
    t = t_(dur)
    return hp(bp(rng.standard_normal(len(t)), 2500, 9000), 2000) * np.exp(-t * 11) * 0.35


def sfx_success():
    r = rev(0.9, 60, 135)
    b = blowoff()
    c = chime([69, 73, 76, 81], dur=1.0, gap=0.06, decay=0.35, vol=0.32)
    x = np.zeros(len(r) + len(c))
    x[:len(r)] += r
    s = int(0.82 * SR)
    x[s:s + len(b)] += b
    s = int(0.7 * SR)
    x[s:s + len(c)] += c
    export('succes.mp3', mono_to_st(x, 0.005))


def sfx_levelup():
    r = rev(1.6, 50, 190)
    c = chime([64, 69, 73, 76, 81, 85], dur=1.4, gap=0.07, decay=0.6, vol=0.3)
    x = np.zeros(len(r) + len(c))
    x[:len(r)] += r
    s = int(1.35 * SR)
    x[s:s + len(c)] += c
    b = blowoff(0.4)
    s = int(1.45 * SR)
    x[s:s + len(b)] += b
    export('level_up.mp3', mono_to_st(x, 0.006))


def sfx_achievement():
    x = chime([72, 76, 79, 84], dur=1.3, gap=0.09, decay=0.5, vol=0.33)
    export('succes_debloque.mp3', mono_to_st(x, 0.006))


def sfx_flip():
    t = t_(0.25)
    x = bp(rng.standard_normal(len(t)), 1200, 6000) * np.exp(-t * 18) * 0.4 + np.sin(2 * np.pi * 220 * t) * np.exp(-t * 30) * 0.3
    export('flip.mp3', mono_to_st(x, 0.003))


def sfx_shutter():
    t = t_(0.18)
    a = bp(rng.standard_normal(len(t)), 1500, 8000) * np.exp(-t * 60)
    b = np.roll(a, int(0.07 * SR)) * 0.7
    x = (a + b) * 0.4
    export('shutter.mp3', mono_to_st(x))


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    sfx_tap()
    sfx_tick()
    sfx_whoosh()
    sfx_notification()
    sfx_success()
    sfx_levelup()
    sfx_achievement()
    sfx_flip()
    sfx_shutter()
    music()
