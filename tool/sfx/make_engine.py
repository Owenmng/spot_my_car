"""Son « démarrage moteur » du contact du jour : démarreur, allumage, coup de gaz, ralenti.
usage : python3 tool/sfx/make_engine.py  → assets/audio/moteur.mp3"""
import pathlib, subprocess, tempfile, wave
import numpy as np

SR = 44100
rng = np.random.default_rng(7)

def engine(freq_curve, dur):
    n = int(dur * SR)
    f = np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(freq_curve)), freq_curve)
    phase = np.cumsum(2 * np.pi * f / SR)
    # Explosions des cylindres : impulsions riches en harmoniques
    sig = np.zeros(n)
    for k, a in [(1, 1.0), (2, 0.55), (3, 0.35), (4, 0.22), (6, 0.12), (8, 0.06)]:
        sig += a * np.sin(k * phase + rng.uniform(0, 6))
    sig = np.tanh(sig * 1.8)
    # Grondement d'échappement (bruit filtré modulé par le régime)
    noise = np.convolve(rng.normal(0, 1, n), np.ones(40) / 40, mode='same')
    sig += 0.35 * noise * (0.6 + 0.4 * np.sin(phase))
    return sig

def starter(dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    whine = np.sin(2 * np.pi * (380 + 40 * np.sin(2 * np.pi * 9 * t)) * t) * 0.25
    crank = (np.sin(2 * np.pi * 11 * t) > 0.6).astype(float)
    crank = np.convolve(crank, np.hanning(300), mode='same') / 150
    return whine * (0.5 + 0.5 * crank) + 0.2 * crank * rng.normal(0, 1, n)

s1 = starter(0.45)
s2 = engine([28, 70, 140, 175, 120, 70, 52, 48], 1.55)  # allumage → coup de gaz → ralenti
env2 = np.minimum(1, np.linspace(0, 8, len(s2))) * np.concatenate([np.ones(int(len(s2) * 0.75)), np.linspace(1, 0.0, len(s2) - int(len(s2) * 0.75))])
out = np.concatenate([s1, s2 * env2 * 0.9])
out = out / np.max(np.abs(out)) * 0.85

root = pathlib.Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory() as d:
    w = pathlib.Path(d) / 'm.wav'
    with wave.open(str(w), 'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(SR)
        f.writeframes((out * 32767).astype(np.int16).tobytes())
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', str(w), '-af', 'lowpass=f=5000,highpass=f=25', '-b:a', '96k', str(root / 'assets/audio/moteur.mp3')], check=True)
print('ok')
