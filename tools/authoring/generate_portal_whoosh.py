"""Synthesise the portal whoosh - the sound of a doorway opening onto elsewhere.

Run from the repository root:
    python3 tools/authoring/generate_portal_whoosh.py

Noise swept through a resonant band that rises and falls like something rushing
past, over a low sub that drops away, with a faint arcane ring in the tail. The
result is written as a mono 16-bit WAV for AudioStreamPlayer3D.
"""

from __future__ import annotations

import wave
from pathlib import Path

import numpy as np


PROJECT_ROOT = Path(__file__).resolve().parents[2]
OUT_PATH = PROJECT_ROOT / "assets/sounds/portal_whoosh.wav"

SAMPLE_RATE = 44100
DURATION = 1.15
SEED = 20260724


## One pass of a Chamberlin state-variable filter rolls off only 6 dB/octave,
## and white noise carries so much energy above the band that a single pass
## still reads as flat hiss. Three in series steepen the skirts enough for the
## moving band to become the sound.
BANDPASS_STAGES = 3


def swept_bandpass(
    signal: np.ndarray, centre: np.ndarray, resonance: np.ndarray
) -> np.ndarray:
    """A state-variable bandpass whose band moves per sample.

    The sweep is what makes a whoosh a whoosh: a static band just sounds like
    hiss, so the centre frequency has to travel across the tone while it plays.
    """
    f = 2.0 * np.sin(np.pi * centre / SAMPLE_RATE)
    q = 1.0 / resonance
    band = signal
    for _stage in range(BANDPASS_STAGES):
        source = band
        band = np.zeros_like(source)
        low_state = 0.0
        band_state = 0.0
        for index, sample in enumerate(source):
            high_state = sample - low_state - q[index] * band_state
            band_state += f[index] * high_state
            low_state += f[index] * band_state
            band[index] = band_state
    return band


def build() -> np.ndarray:
    count = int(SAMPLE_RATE * DURATION)
    time = np.arange(count) / SAMPLE_RATE
    progress = time / DURATION
    rng = np.random.default_rng(SEED)

    # The pass-by: the band climbs to its peak around a third of the way in,
    # then falls away, so the rush reads as moving rather than sitting still.
    arc = np.sin(np.pi * np.clip(progress, 0.0, 1.0) ** 0.78)
    centre = 170.0 + 2100.0 * arc
    resonance = 1.15 + 2.2 * arc

    # Swell and fall, peaking about a third of the way through: a rush that
    # arrives and passes, rather than a burst that only decays.
    swell = np.sin(np.pi * np.clip(progress, 0.0, 1.0) ** 0.62) ** 1.25
    rush = swept_bandpass(rng.normal(0.0, 1.0, count), centre, resonance)
    rush *= np.minimum(time / 0.015, 1.0) * swell * np.exp(-1.15 * progress)

    # A low body that drops as it goes, giving the whoosh some weight.
    sub_freq = 132.0 * np.exp(-1.35 * progress)
    sub = np.sin(2.0 * np.pi * np.cumsum(sub_freq) / SAMPLE_RATE)
    sub *= np.minimum(time / 0.012, 1.0) * np.exp(-5.4 * progress) * 0.55

    # A thin ring arriving late: the threshold settling, not a bell strike.
    ring_env = np.clip((progress - 0.22) / 0.14, 0.0, 1.0) * np.exp(-4.2 * progress)
    ring = (
        np.sin(2.0 * np.pi * 880.0 * time) * 0.6
        + np.sin(2.0 * np.pi * 1319.0 * time) * 0.4
    ) * ring_env * 0.12

    mixed = rush * 0.85 + sub + ring
    peak = float(np.max(np.abs(mixed)))
    if peak > 0.0:
        mixed = mixed / peak * 0.92

    # Fade the last 25 ms so the tail cannot click.
    tail = int(SAMPLE_RATE * 0.025)
    mixed[-tail:] *= np.linspace(1.0, 0.0, tail)
    return mixed


def main() -> None:
    samples = build()
    pcm = np.clip(samples, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype("<i2")
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT_PATH), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(pcm.tobytes())
    print(f"Wrote {OUT_PATH} ({len(pcm) / SAMPLE_RATE:.2f}s @ {SAMPLE_RATE} Hz)")


if __name__ == "__main__":
    main()
