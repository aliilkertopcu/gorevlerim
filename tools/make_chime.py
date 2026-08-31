"""Synthesize a warm celebration chime (no external deps).

Additive bell synthesis: each struck note is a set of inharmonic partials with
independent exponential decays (higher partials die faster, like a real bell),
plus a soft attack so it never clicks.
"""
import math
import struct
import wave

SR = 44100

# Bell partial ratios and their relative gain / decay multiplier.
PARTIALS = [
    (0.50, 0.28, 0.75),
    (1.00, 1.00, 1.00),
    (1.19, 0.42, 1.35),
    (1.56, 0.28, 1.70),
    (2.00, 0.22, 2.10),
    (2.66, 0.14, 2.70),
    (3.01, 0.10, 3.20),
    (4.07, 0.06, 4.20),
]


def note(buf, freq, start, amp, decay):
    """Mix one struck bell note into buf starting at `start` seconds."""
    i0 = int(start * SR)
    length = int(min(decay * 3.2, 3.0) * SR)
    attack = int(0.004 * SR)  # 4 ms, avoids a click
    for i in range(length):
        idx = i0 + i
        if idx >= len(buf):
            break
        t = i / SR
        env = math.exp(-t / decay)
        if i < attack:
            env *= i / attack
        s = 0.0
        for ratio, gain, dmul in PARTIALS:
            s += gain * math.exp(-t * dmul / decay) * math.sin(2 * math.pi * freq * ratio * t)
        buf[idx] += amp * env * s


def main():
    total = 3.0
    buf = [0.0] * int(total * SR)

    # C major triad rolling upward, then a soft high sparkle: friendly, not fanfare.
    notes = [
        (523.25, 0.00, 0.42, 1.15),   # C5
        (659.25, 0.11, 0.38, 1.10),   # E5
        (783.99, 0.22, 0.36, 1.05),   # G5
        (1046.50, 0.33, 0.34, 1.30),  # C6
        (1567.98, 0.62, 0.12, 0.90),  # G6 sparkle
        (2093.00, 0.80, 0.08, 0.80),  # C7 sparkle
    ]
    for freq, start, amp, decay in notes:
        note(buf, freq, start, amp, decay)

    peak = max(abs(v) for v in buf) or 1.0
    scale = 0.82 / peak  # headroom, never clips

    # Gentle fade-out on the tail so the file can end early without a cut.
    fade_from = int((total - 0.35) * SR)
    frames = bytearray()
    for i, v in enumerate(buf):
        x = v * scale
        if i >= fade_from:
            x *= max(0.0, 1.0 - (i - fade_from) / (len(buf) - fade_from))
        frames += struct.pack('<h', int(max(-1.0, min(1.0, x)) * 32767))

    out = 'chime.wav'
    with wave.open(out, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))
    print('wrote', out, len(frames), 'bytes of audio')


if __name__ == '__main__':
    main()
