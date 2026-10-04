import argparse
import array
import math
import sys
import wave
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(description="Verify Roamer Fixture PCM16 WAV evidence")
    parser.add_argument("wav", type=Path)
    parser.add_argument("expected_hz", type=float)
    parser.add_argument("--reject-hz", type=float)
    parser.add_argument("--duration-sec", type=float)
    return parser.parse_args()


def tone_amplitude(samples, sample_rate, frequency):
    step = 2 * math.pi * frequency / sample_rate
    real = 0.0
    imaginary = 0.0
    for index, value in enumerate(samples):
        angle = step * index
        real += value * math.cos(angle)
        imaginary -= value * math.sin(angle)
    return 2 * math.hypot(real, imaginary) / len(samples)


def main():
    args = parse_args()
    with wave.open(str(args.wav), "rb") as audio:
        channels = audio.getnchannels()
        sample_rate = audio.getframerate()
        sample_width = audio.getsampwidth()
        frame_count = audio.getnframes()
        compression = audio.getcomptype()
        raw = audio.readframes(frame_count)

    assert compression == "NONE", f"expected PCM WAV, got {compression}"
    assert sample_width == 2, f"expected PCM16, got {sample_width * 8}-bit"
    assert channels > 0 and sample_rate > 0 and frame_count > 0

    duration = frame_count / sample_rate
    if args.duration_sec is not None:
        assert args.duration_sec > 0 and math.isfinite(args.duration_sec)
        assert frame_count >= math.ceil(args.duration_sec * sample_rate), (
            frame_count,
            args.duration_sec * sample_rate,
        )
        assert duration <= args.duration_sec + 0.1, (duration, args.duration_sec)

    pcm = array.array("h")
    pcm.frombytes(raw)
    if sys.byteorder != "little":
        pcm.byteswap()
    mono = [
        sum(pcm[index + channel] for channel in range(channels)) / channels / 32768.0
        for index in range(0, len(pcm), channels)
    ]
    trim = min(int(sample_rate * 0.1), len(mono) // 4)
    analyzed = mono[trim : len(mono) - trim] if trim else mono
    assert analyzed

    rms = math.sqrt(sum(value * value for value in analyzed) / len(analyzed))
    peak = max(abs(value) for value in analyzed)
    expected = tone_amplitude(analyzed, sample_rate, args.expected_hz)
    assert rms >= 1e-4, f"audio is silent: rms={rms}"
    assert peak >= 1e-3, f"audio peak is too small: peak={peak}"
    assert expected >= 0.005, f"expected {args.expected_hz} Hz is missing: amplitude={expected}"

    print(
        f"channels={channels} sampleRate={sample_rate} frames={frame_count} "
        f"duration={duration:.6f} rms={rms:.9f} peak={peak:.9f}"
    )
    print(f"expected_{args.expected_hz:g}Hz_amplitude={expected:.9f}")

    if args.reject_hz is not None:
        reject = tone_amplitude(analyzed, sample_rate, args.reject_hz)
        ratio_db = 20 * math.log10(max(reject, 1e-12) / expected)
        print(f"reject_{args.reject_hz:g}Hz_amplitude={reject:.9f}")
        print(f"reject_vs_expected_db={ratio_db:.3f}")
        assert ratio_db <= -30, f"reject frequency leaked into capture: {ratio_db:.3f} dB"

    print("audio verification PASS")


if __name__ == "__main__":
    main()
