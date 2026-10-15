"""CP-8: original, deterministic combat sweeteners. Python stdlib only.

No sampled/third-party material. Kept separate from existing AW-36 impact/UI SFX.
Run from anywhere; output is assets/audio/sfx/*.wav (48 kHz mono PCM16).
"""
from pathlib import Path
import math
import random
import struct
import wave

RATE = 48_000
OUT = Path(__file__).resolve().parents[2] / "audio" / "sfx"


def render(name, duration, seed, voice):
    rng = random.Random(seed)
    samples = []
    low = 0.0
    for i in range(round(duration * RATE)):
        t = i / RATE
        u = t / duration
        raw = rng.uniform(-1.0, 1.0)
        low += 0.12 * (raw - low)
        samples.append(voice(t, u, raw, low))
    peak = max(abs(x) for x in samples) or 1.0
    # Modest peak leaves space for the existing impact + music voice.
    pcm = b"".join(struct.pack("<h", round(x / peak * 32767 * 0.42)) for x in samples)
    with wave.open(str(OUT / (name + ".wav")), "wb") as wav:
        wav.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        wav.writeframes(pcm)


def sine(hz, t):
    return math.sin(math.tau * hz * t)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    render("blade_whoosh", 0.18, 81, lambda t, u, n, low:
           (0.8 * low + 0.22 * n) * math.sin(math.pi * u) ** 1.4)
    render("magic_gather", 0.52, 82, lambda t, u, n, low:
           (0.45 * sine(220 + 180 * u, t) + 0.20 * sine(330 + 220 * u, t)
            + 0.3 * low) * math.sin(math.pi * u) ** 0.7)
    render("magic_release", 0.30, 83, lambda t, u, n, low:
           (0.7 * low + 0.25 * sine(660 - 360 * u, t))
           * min(1, t / 0.008) * (1 - u) ** 1.8)
    render("magic_impact", 0.42, 84, lambda t, u, n, low:
           (0.6 * low * math.exp(-t * 11) + 0.22 * sine(110, t) * math.exp(-t * 16)
            + 0.16 * sine(880, t) * math.exp(-t * 9)) * min(1, t / 0.003) * (1 - u))
    render("armor_drop", 0.32, 85, lambda t, u, n, low:
           (0.65 * low * math.exp(-t * 18) + 0.22 * sine(92, t) * math.exp(-t * 23)
            + 0.12 * sine(1423, t) * math.exp(-t * 32)) * min(1, t / 0.003) * (1 - u))


if __name__ == "__main__":
    main()
