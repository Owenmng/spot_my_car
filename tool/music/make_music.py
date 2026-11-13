"""Musiques d'ambiance originales de Spot My Car (boucles sans coupure), synthétisées en numpy.

usage : python3 tool/music/make_music.py <dossier_sortie>
Produit musique_synthwave.mp3, musique_lofi.mp3, musique_phonk.mp3, musique_circuit.mp3.
"""
import os
import subprocess
import sys
import wave

import numpy as np

SR = 44100
rng = np.random.default_rng(7)


def nf(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def t_(d):
    return np.arange(int(d * SR)) / SR


class Track:
    """Piste stéréo en boucle : ce qui dépasse de la fin revient au début (boucle parfaite)."""

    def __init__(self, dur):
        self.n = int(dur * SR)
        self.L = np.zeros(self.n)
        self.R = np.zeros(self.n)

    def add(self, sig, at, pan=0.0, g=1.0):
        i = int(at * SR) % self.n
        s = sig * g
        gl, gr = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        while len(s):
            j = min(self.n, i + len(s))
            k = j - i
            self.L[i:j] += s[:k] * gl * 1.414
            self.R[i:j] += s[:k] * gr * 1.414
            s = s[k:]
            i = 0


def lp(x, cutoff):
    """Passe-bas un pôle (rapide)."""
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    b = 1 - a
    # vectorisation par blocs : filtre IIR simple via lfilter maison
    from itertools import accumulate  # noqa
    for i in range(len(x)):
        acc = b * x[i] + a * acc
        y[i] = acc
    return y


def lp_fast(x, cutoff):
    """Passe-bas par FFT (pente douce), sans boucle python."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    H = 1 / np.sqrt(1 + (f / cutoff) ** 4)
    return np.fft.irfft(X * H, len(x))


def hp_fast(x, cutoff):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    H = 1 / np.sqrt(1 + (cutoff / np.maximum(f, 1)) ** 4)
    return np.fft.irfft(X * H, len(x))


def reverb(sig_l, sig_r, size=2.2, mix=0.25, damp=5000):
    """Réverbération par convolution circulaire avec une réponse impulsionnelle synthétique."""
    n = len(sig_l)
    out = []
    for ch, seed in ((sig_l, 1), (sig_r, 2)):
        r = np.random.default_rng(seed)
        ir_len = int(size * SR)
        ir = r.standard_normal(ir_len) * np.exp(-np.arange(ir_len) / SR * (6.9 / size))
        ir = lp_fast(ir, damp)
        ir[: int(0.012 * SR)] = 0
        ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
        pad = np.zeros(n)
        pad[: min(n, ir_len)] = ir[: min(n, ir_len)]
        wet = np.fft.irfft(np.fft.rfft(ch) * np.fft.rfft(pad), n)  # circulaire = boucle parfaite
        out.append(ch * (1 - mix) + wet * mix * 0.6)
    return out


def saw(f, d, detune=0.0):
    t = t_(d)
    ph = (t * f * 2 ** (detune / 1200)) % 1
    return 2 * ph - 1


def env_adsr(n, a, d, s, r, total):
    t = np.arange(n) / SR
    e = np.where(t < a, t / max(a, 1e-4), 1.0)
    e = np.where((t >= a) & (t < a + d), 1 - (1 - s) * (t - a) / max(d, 1e-4), e)
    e = np.where(t >= a + d, s, e)
    rel = np.clip((total - t) / max(r, 1e-4), 0, 1)
    return e * rel


def supersaw(m, d, voices=5, spread=18, cutoff=2500, a=0.02, r=0.3, s=0.8):
    sig = np.zeros(int(d * SR))
    for v in range(voices):
        det = (v - (voices - 1) / 2) * spread / max(1, (voices - 1) / 2)
        sig += saw(nf(m), d, det)
    sig /= voices
    sig = lp_fast(sig, cutoff)
    return sig * env_adsr(len(sig), a, 0.2, s, r, d)


def sine(m, d, a=0.005, decay=None):
    t = t_(d)
    s = np.sin(2 * np.pi * nf(m) * t)
    e = np.minimum(1, t / a)
    if decay:
        e *= np.exp(-t / decay)
    return s * e


def kick(punch=1.0, tone=48, dec=6.0):
    t = t_(0.5)
    f = tone + 120 * np.exp(-t * 32)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return (np.sin(ph) * np.exp(-t * dec) + 0.25 * np.sin(ph) * np.exp(-t * 40) * punch) * 0.9


def snare(dec=14, tone=0.35):
    t = t_(0.4)
    n = hp_fast(rng.standard_normal(len(t)), 1200)
    body = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 25)
    return (n * np.exp(-t * dec) * 0.6 + body * tone) * 0.8


def clap():
    t = t_(0.35)
    n = hp_fast(rng.standard_normal(len(t)), 900)
    e = np.exp(-t * 16)
    for k, off in enumerate((0.0, 0.011, 0.022)):
        i = int(off * SR)
        e[i : i + int(0.004 * SR)] += 0.8
    return n * e * 0.5


def hat(open_=False, g=1.0):
    t = t_(0.3 if open_ else 0.06)
    n = hp_fast(rng.standard_normal(len(t)), 7000)
    return n * np.exp(-t * (10 if open_ else 70)) * 0.35 * g


def crackle(dur):
    n = np.zeros(int(dur * SR))
    idx = rng.integers(0, len(n), int(dur * 12))
    n[idx] = rng.standard_normal(len(idx)) * 0.6
    hiss = lp_fast(rng.standard_normal(len(n)), 3000) * 0.012
    return lp_fast(n, 5000) + hiss


def bass808(m, d, slide=None):
    t = t_(d)
    f = np.full(len(t), nf(m))
    if slide is not None:
        f = nf(m) * (nf(slide) / nf(m)) ** np.clip((t - d * 0.6) / (d * 0.3), 0, 1)
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = np.tanh(np.sin(ph) * 1.8)
    return s * np.minimum(1, t / 0.004) * np.exp(-t * 0.8) * 0.7


def cowbell(m, d=0.22):
    t = t_(d)
    f = nf(m)
    s = np.sign(np.sin(2 * np.pi * f * t)) + np.sign(np.sin(2 * np.pi * f * 1.4836 * t))
    s = lp_fast(hp_fast(s, 500), 4000)
    return s * np.exp(-t * 13) * 0.09


def ep(ms, d, cutoff=1800):
    """Piano électrique doux (accord)."""
    t = t_(d)
    s = np.zeros(len(t))
    for m in ms:
        f = nf(m)
        s += np.sin(2 * np.pi * f * t) * np.exp(-t * 1.6) + 0.35 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 4)
        s += 0.12 * np.sin(2 * np.pi * 3.01 * f * t) * np.exp(-t * 7)
    s = lp_fast(s, cutoff) / len(ms)
    return s * np.minimum(1, t / 0.006) * np.minimum(1, (d - t) / 0.08)


def finish(tr, name, outdir, gain=1.0, rev=(2.2, 0.22)):
    L, R = reverb(tr.L, tr.R, size=rev[0], mix=rev[1])
    mix = np.stack([L, R], 1) * gain
    mix = np.tanh(mix * 1.1)
    mix /= np.abs(mix).max() / 0.89
    wav = os.path.join(outdir, name + '.wav')
    with wave.open(wav, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((mix * 32767).astype('<i2').tobytes())
    mp3 = os.path.join(outdir, name + '.mp3')
    subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', wav, '-codec:a', 'libmp3lame', '-b:a', '128k', mp3], check=True)
    os.remove(wav)
    print(name, len(mix) / SR, 's')


# ───────────────────────────── 1. Synthwave « Retro Drive » (100 BPM) ─────────────────────────────
def synthwave(outdir):
    bpm = 100
    beat = 60 / bpm
    bars = 24
    tr = Track(bars * 4 * beat)
    prog = [(57, [69, 72, 76]), (53, [69, 72, 77]), (48, [67, 72, 76]), (55, [67, 71, 74])]  # Am F C G
    arp = [0, 7, 12, 16, 12, 7, 3, 7]
    lead = [76, 74, 72, 74, 76, 79, 76, 74, 72, 71, 72, 74, 72, 69, 67, 69]
    for bar in range(bars):
        root, ch = prog[bar % 4]
        t0 = bar * 4 * beat
        for m in ch:
            tr.add(supersaw(m - 12, 4 * beat, voices=6, spread=22, cutoff=1500, a=0.35, r=0.6, s=0.9), t0, pan=(m % 3 - 1) * 0.5, g=0.11)
        for k in range(8):
            tr.add(supersaw(root - 12, beat / 2 * 0.9, voices=2, spread=8, cutoff=700, a=0.005, r=0.05, s=0.7), t0 + k * beat / 2, g=0.28)
        if bar >= 2:
            for k in range(16):
                m = root + 12 + arp[k % 8]
                tr.add(supersaw(m, beat / 4 * 0.9, voices=2, spread=6, cutoff=3200, a=0.002, r=0.06, s=0.5), t0 + k * beat / 4, pan=0.45 if k % 2 else -0.45, g=0.06)
        if bar >= 4:
            for b in range(4):
                tr.add(kick(), t0 + b * beat, g=0.7)
                tr.add(hat(g=0.8), t0 + b * beat + beat / 2, pan=0.3)
                if b % 2:
                    tr.add(snare(dec=10), t0 + b * beat, g=0.55)
        if 8 <= bar < 16 or bar >= 20:
            for k in range(4):
                m = lead[((bar - 8) * 4 + k) % 16]
                tr.add(supersaw(m, beat * 0.95, voices=3, spread=10, cutoff=2600, a=0.03, r=0.25, s=0.75), t0 + k * beat, g=0.075)
    finish(tr, 'musique_synthwave', outdir, rev=(2.8, 0.3))


# ───────────────────────────── 2. Lo-fi « Garage » (80 BPM, swing) ─────────────────────────────
def lofi(outdir):
    bpm = 80
    beat = 60 / bpm
    bars = 16
    tr = Track(bars * 4 * beat)
    chords = [[50, 53, 57, 60, 64], [43, 53, 55, 59, 62], [48, 52, 55, 59, 64], [45, 52, 55, 60, 64]]  # Dm9 G13 Cmaj7 Am7
    mel = [74, 72, 69, 72, 71, 67, 69, 64, 72, 71, 67, 64]
    sw = beat / 2 * 0.16
    for bar in range(bars):
        ch = chords[bar % 4]
        t0 = bar * 4 * beat
        tr.add(ep(ch[1:], 2 * beat, 1500), t0, g=0.55)
        tr.add(ep(ch[1:], 2 * beat, 1400), t0 + 2 * beat + sw, g=0.45)
        tr.add(sine(ch[0] - 12, 4 * beat * 0.95, a=0.01, decay=1.6), t0, g=0.55)
        tr.add(sine(ch[0] - 5, beat * 0.9, a=0.01, decay=0.6), t0 + 3 * beat + sw, g=0.3)
        for b in range(4):
            if b in (0, 2) or (b == 1 and bar % 2):
                tr.add(lp_fast(kick(tone=52, dec=8), 900), t0 + b * beat + (sw if b == 1 else 0), g=0.75)
            if b in (1, 3):
                tr.add(lp_fast(snare(dec=18, tone=0.2), 4000), t0 + b * beat, g=0.42)
            tr.add(lp_fast(hat(g=0.7), 6000), t0 + b * beat, pan=0.25)
            tr.add(lp_fast(hat(g=0.45), 6000), t0 + b * beat + beat / 2 + sw, pan=0.25)
        if bar >= 4 and bar % 2 == 0:
            for k in range(6):
                m = mel[(bar * 3 + k) % len(mel)]
                tr.add(ep([m], beat * 0.9, 2400), t0 + k * beat * 0.66 + (sw if k % 2 else 0), pan=-0.2, g=0.35)
    vinyl = crackle(tr.n / SR)
    tr.add(vinyl, 0, g=1.0)
    finish(tr, 'musique_lofi', outdir, rev=(1.8, 0.2), gain=0.9)


# ───────────────────────────── 3. Drift phonk (130 BPM) ─────────────────────────────
def phonk(outdir):
    bpm = 130
    beat = 60 / bpm
    bars = 24
    tr = Track(bars * 4 * beat)
    roots = [45, 45, 41, 43]
    mel = [69, 72, 76, 72, 74, 72, 69, 67, 69, 72, 76, 79, 76, 74, 72, 74]
    for bar in range(bars):
        t0 = bar * 4 * beat
        r = roots[bar % 4]
        tr.add(bass808(r - 12, 4 * beat * 0.98, slide=roots[(bar + 1) % 4] - 12 if bar % 2 else None), t0, g=0.8)
        for b in range(4):
            if b in (0, 2) or (b == 1 and bar % 2):
                tr.add(kick(tone=45, dec=5), t0 + b * beat, g=0.8)
            if b in (1, 3):
                tr.add(clap(), t0 + b * beat, g=0.6)
            for h in range(2):
                tr.add(hat(g=0.7 if h else 0.5), t0 + b * beat + h * beat / 2, pan=0.25)
        if bar % 4 == 3:
            for k in range(6):
                tr.add(hat(g=0.45), t0 + 3 * beat + k * beat / 6, pan=-0.25)
        if bar >= 2:
            for k in range(16):
                m = mel[k] - (2 if bar % 4 == 2 and k % 5 == 0 else 0)
                tr.add(cowbell(m), t0 + k * beat / 4, pan=0.35 if k % 2 else -0.35, g=1.0 if k % 2 == 0 else 0.7)
    finish(tr, 'musique_phonk', outdir, rev=(1.6, 0.18), gain=0.85)


# ───────────────────────────── 4. Circuit (house minimale, 122 BPM) ─────────────────────────────
def circuit(outdir):
    bpm = 122
    beat = 60 / bpm
    bars = 32
    tr = Track(bars * 4 * beat)
    stabs = [[57, 60, 64, 67], [53, 57, 60, 64], [55, 59, 62, 65], [52, 55, 59, 62]]  # Am7 Fmaj7 G7 Em7
    for bar in range(bars):
        t0 = bar * 4 * beat
        ch = stabs[bar % 4]
        for b in range(4):
            tr.add(kick(tone=50, dec=7), t0 + b * beat, g=0.75)
            tr.add(hat(open_=True, g=0.55), t0 + b * beat + beat / 2, pan=0.2)
            if b in (1, 3):
                tr.add(clap(), t0 + b * beat, g=0.45)
            for h in (1, 3):
                tr.add(hat(g=0.4), t0 + b * beat + h * beat / 4, pan=-0.3)
        for k, off in enumerate((0.75, 1.5, 2.75, 3.5)):
            tr.add(ep([m + 12 for m in ch], beat * 0.4, 2600 if 8 <= bar < 24 else 1600), t0 + off * beat, pan=(-0.3, 0.3)[k % 2], g=0.32)
        for k in range(8):
            if k in (0, 3, 6):
                tr.add(supersaw(ch[0] - 24, beat * 0.45, voices=2, spread=5, cutoff=500, a=0.003, r=0.05, s=0.8), t0 + k * beat / 2, g=0.35)
    finish(tr, 'musique_circuit', outdir, rev=(2.0, 0.2), gain=0.9)


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else '.'
    os.makedirs(out, exist_ok=True)
    which = sys.argv[2:] or ['synthwave', 'lofi', 'phonk', 'circuit']
    for w in which:
        globals()[w](out)
