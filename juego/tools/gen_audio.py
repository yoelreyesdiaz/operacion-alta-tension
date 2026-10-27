"""Sintetiza los sonidos placeholder (WAV mono 22 kHz).
Uso: python3 tools/gen_audio.py   (requiere numpy)"""
import os
import wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(60)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, a=0.005, r=0.05):
    e = np.ones(n)
    na, nr = max(1, int(SR * a)), max(1, int(SR * r))
    e[:na] = np.linspace(0, 1, na)
    e[-nr:] *= np.linspace(1, 0, nr)
    return e


def lowpass(x, k):
    return np.convolve(x, np.ones(k) / k, mode="same")


def loopable(x, fade=0.25):
    n = int(SR * fade)
    w = np.linspace(0, 1, n)
    head = x[:n] * w + x[-n:] * (1 - w)
    return np.concatenate([head, x[n:-n]])


def save(name, x, vol=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * vol
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes((x * 32767).astype("<i2").tobytes())


def noise(sec):
    return rng.standard_normal(int(SR * sec))


def tone(freq, sec, shape="sin"):
    ph = 2 * np.pi * freq * t(sec)
    return np.sign(np.sin(ph)) if shape == "sq" else np.sin(ph)


# Ambiente
rain = noise(4.25)
rain = rain - lowpass(rain, 6) + 0.3 * lowpass(noise(4.25), 40)
save("lluvia", loopable(rain), 0.5)

tt = t(4.25)
hum = np.sin(2 * np.pi * 60 * tt) + 0.6 * np.sin(2 * np.pi * 120 * tt) + 0.25 * np.sin(2 * np.pi * 180 * tt)
hum *= 1 + 0.05 * np.sin(2 * np.pi * 0.5 * tt)
save("zumbido", loopable(hum), 0.6)

tt = t(8.25)
drone = sum(np.sin(2 * np.pi * f * tt + p) * (1 + 0.3 * np.sin(2 * np.pi * r * tt))
            for f, p, r in ((55, 0, 0.125), (82.4, 1, 0.25), (110.3, 2, 0.375), (164.8, 0.5, 0.125)))
save("musica_tension", loopable(drone + 0.15 * lowpass(noise(8.25), 80), 1.0), 0.5)

tt = t(3.0)
th = lowpass(noise(3.0), 60) * np.exp(-tt * 1.4) * (1 + 0.6 * np.sin(2 * np.pi * 7 * tt))
th[: int(SR * 0.08)] += noise(0.08) * 0.8
save("trueno", th * env(len(th), 0.002, 0.5), 0.95)

# Eléctricos
tt = t(0.18)
save("interruptor", (lowpass(noise(0.18), 5) * np.exp(-tt * 45) + 0.8 * np.sin(2 * np.pi * 90 * tt) * np.exp(-tt * 25)), 0.9)
tt = t(0.05)
save("click", np.sin(2 * np.pi * 1400 * tt) * np.exp(-tt * 90), 0.5)
tt = t(0.35)
zap = (noise(0.35) - lowpass(noise(0.35), 3)) * (np.sin(2 * np.pi * 37 * tt) > 0.2) * np.exp(-tt * 6)
save("chispa", zap + 0.3 * tone(120, 0.35, "sq") * np.exp(-tt * 8), 0.8)
beep = tone(880, 0.16, "sq") * env(int(SR * 0.16))
save("alarma", np.concatenate([beep, np.zeros(int(SR * 0.1)), beep, np.zeros(int(SR * 0.3))]), 0.45)
save("error", tone(110, 0.3, "sq") * env(int(SR * 0.3)) + 0.5 * tone(116, 0.3, "sq"), 0.5)
tt = t(0.12)
save("fusible", np.sin(2 * np.pi * 520 * tt) * np.exp(-tt * 30) + 0.5 * lowpass(noise(0.12), 4) * np.exp(-tt * 60), 0.7)
tt = t(0.07)
save("girar", lowpass(noise(0.07), 3) * np.exp(-tt * 50) + 0.4 * np.sin(2 * np.pi * 300 * tt) * np.exp(-tt * 60), 0.6)

# Personaje / mundo
tt = t(0.09)
save("paso", lowpass(noise(0.09), 12) * np.exp(-tt * 45), 0.5)
save("recoger", np.concatenate([tone(660, 0.07), tone(990, 0.12)]) * env(int(SR * 0.19), 0.003, 0.08), 0.5)
sq = noise(0.22) - lowpass(noise(0.22), 4)
save("radio", np.concatenate([sq * env(len(sq), 0.002, 0.03) * 0.5, tone(1200, 0.06) * env(int(SR * 0.06))]), 0.4)
arp = np.concatenate([tone(f, 0.13) * env(int(SR * 0.13), 0.004, 0.06) for f in (392, 523, 659, 784)]
                     + [tone(1047, 0.5) * env(int(SR * 0.5), 0.004, 0.4)])
save("exito", arp, 0.6)
tt = t(2.6)
motor = tone(48, 2.6, "sq") * 0.4 + lowpass(noise(2.6), 8) * (0.6 + 0.4 * np.sin(2 * np.pi * 11 * tt))
save("porton", motor * env(len(motor), 0.15, 0.4), 0.7)
tt = t(1.4)
save("energia", np.sin(2 * np.pi * (40 + 80 * tt / 1.4) * tt) * env(len(tt), 0.6, 0.3) + 0.3 * lowpass(noise(1.4), 30), 0.8)
print("audio generado")
