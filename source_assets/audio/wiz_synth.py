#!/usr/bin/env python3
"""Procedural SFX synthesis for the air-cast sigil system. Pure numpy.
The sketch loop and the rune-completion stinger share one breathy, non-tonal
"energy in the air" identity."""
import numpy as np
import wave
import os

SR = 44100
OUT = os.environ.get("OUT_DIR", ".")
os.makedirs(OUT, exist_ok=True)


def t_axis(dur):
    return np.linspace(0, dur, int(SR * dur), endpoint=False)


def lowpass(x, cutoff_hz):
    dt = 1.0 / SR
    rc = 1.0 / (2 * np.pi * cutoff_hz)
    alpha = dt / (rc + dt)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha * (x[i] - acc)
        y[i] = acc
    return y


def highpass(x, cutoff_hz):
    return x - lowpass(x, cutoff_hz)


def to_stereo(l, r=None):
    if r is None:
        r = l
    st = np.stack([l, r], axis=-1)
    peak = np.max(np.abs(st))
    if peak > 0:
        st = st / peak * 0.89
    return st


def save_wav(name, stereo):
    ints = (np.clip(stereo, -1, 1) * 32767).astype(np.int16)
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(ints.tobytes())
    print("wrote", path, f"{len(stereo)/SR:.2f}s")


def seamless_loop(mono, fade=0.25):
    n = int(SR * fade)
    if n * 2 >= len(mono):
        return mono
    fi = np.sqrt(np.linspace(0, 1, n))
    fo = np.sqrt(np.linspace(1, 0, n))
    mixed = mono[-n:] * fo + mono[:n] * fi
    return np.concatenate([mixed, mono[n:-n]])


# ---------------------------------------------------------------------------
# sketch_loop -- breathy energy whoosh while a stroke is traced. Non-tonal
# bandpassed noise with a moving comb (flange) and a slow amplitude breath.
# ---------------------------------------------------------------------------
def make_sketch_loop():
    dur = 2.4
    t = t_axis(dur)
    n = np.random.randn(len(t))
    bp = highpass(lowpass(n, 3200), 450)          # band ~450-3200 Hz
    lfo = 0.5 + 0.5 * np.sin(2 * np.pi * 0.4 * t)
    maxd = int(SR * 0.006)
    idx = np.clip(np.arange(len(t)) - (lfo * maxd).astype(int), 0, len(t) - 1)
    flanged = bp + bp[idx]                          # moving comb = whoosh
    amp = 0.35 + 0.65 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.5 * t + 1.0))
    mono = flanged * amp * 0.5
    mono += 0.04 * np.sin(2 * np.pi * 300 * t) * amp  # faint airy resonance
    mono = seamless_loop(mono, 0.25)
    idx2 = np.clip(np.arange(len(mono)) - int(SR * 0.004), 0, len(mono) - 1)
    return to_stereo(mono, mono[idx2])


# ---------------------------------------------------------------------------
# rune_ignite -- one-shot completion in the same air family: a filtered-noise
# whoosh that swells and brightens (filter opening), then blooms and settles
# on a soft low "lands" thump. No bells/chimes, so it matches the sketch feel.
# ---------------------------------------------------------------------------
def make_rune_ignite():
    dur = 1.3
    t = t_axis(dur)
    n = np.random.randn(len(t))
    lp = lowpass(n, 6500)
    dark = highpass(lp, 300)
    bright = highpass(lp, 1600)
    # attack swell then exponential decay
    attack = np.clip(t / 0.10, 0, 1)
    decay = np.exp(-np.clip(t - 0.10, 0, None) * 3.2)
    env = attack * decay
    # filter "opens" over the attack: dark -> bright as the energy resolves
    openness = np.clip(t / 0.16, 0, 1)
    whoosh = (dark * (1 - openness) + bright * openness) * env
    # airy motion (flange) matching the sketch texture
    lfo = 0.5 + 0.5 * np.sin(2 * np.pi * 3.0 * t)
    maxd = int(SR * 0.005)
    idx = np.clip(np.arange(len(t)) - (lfo * maxd).astype(int), 0, len(t) - 1)
    whoosh = whoosh + whoosh[idx] * 0.7
    # faint rising resonance -- a whisper of "forming", not a note
    rise = 220.0 * (2.0 ** np.clip(t / 0.35, 0, 1))
    res = 0.05 * np.sin(2 * np.pi * np.cumsum(rise) / SR) * env
    # weighty low bloom that "lands": filtered-noise body + a felt sub-thump
    # (a low pitch drop, felt not heard, so it stays non-tonal).
    body_env = np.exp(-t * 6.0) * np.clip(t / 0.008, 0, 1)
    body = lowpass(np.random.randn(len(t)), 160) * body_env * 1.6
    sub_f = 60.0 + 58.0 * np.exp(-t * 12.0)          # ~118 -> 60 Hz drop
    sub = np.sin(2 * np.pi * np.cumsum(sub_f) / SR) \
        * np.exp(-t * 5.0) * np.clip(t / 0.006, 0, 1) * 0.85
    mono = whoosh * 0.72 + res + body + sub
    # a little air/space
    tail = np.zeros_like(mono)
    for dl, g in [(0.06, 0.25), (0.13, 0.14)]:
        s = int(SR * dl)
        tail += np.concatenate([np.zeros(s), mono[:-s]]) * g
    mono = mono + tail
    idx2 = np.clip(np.arange(len(mono)) - int(SR * 0.004), 0, len(mono) - 1)
    return to_stereo(mono, mono[idx2])


if __name__ == "__main__":
    np.random.seed(11)   # reproduces the approved "air" sketch loop exactly
    save_wav("sketch_loop.wav", make_sketch_loop())
    np.random.seed(23)
    save_wav("rune_ignite.wav", make_rune_ignite())
