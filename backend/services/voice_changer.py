"""Simple voice disguise utilities.

This module performs a light-weight pitch shift by resampling the audio.
It intentionally keeps dependencies minimal: it requires numpy and the
standard library. If ``scipy`` is available it uses ``scipy.signal.resample``
for higher quality; otherwise it falls back to a NumPy-based resample.

The public function is ``disguise_audio(input_wav: str|Path) -> Path`` which
creates a new WAV file next to the input with suffix ``_disguised.wav``.

Configuration via environment variables:
 - VOICE_CHANGER_SEMITONES (int, default=+3): number of semitones to shift
 - VOICE_CHANGER_TIME_STRETCH (float, default=1.0): speed factor (<1 slower,
   >1 faster). Applied after pitch shift.

This is intentionally conservative and runs entirely locally.
"""
from __future__ import annotations

import os
import wave
from pathlib import Path
import numpy as np
from typing import Optional

try:
    from scipy.signal import resample as scipy_resample
except Exception:
    scipy_resample = None


def _read_wav(path: Path):
    with wave.open(str(path), 'rb') as w:
        params = w.getparams()
        nchannels, sampwidth, framerate, nframes = params[:4]
        raw = w.readframes(nframes)
    dtype = None
    if sampwidth == 1:
        dtype = np.uint8
    elif sampwidth == 2:
        dtype = np.int16
    elif sampwidth == 3:
        # 24-bit: read as bytes and convert
        a = np.frombuffer(raw, dtype=np.uint8)
        a = a.reshape(-1, 3)
        # little-endian
        ints = (a[:, 0].astype(np.int32) |
                (a[:, 1].astype(np.int32) << 8) |
                (a[:, 2].astype(np.int32) << 16))
        # sign extend
        mask = ints & 0x800000
        ints = ints - (mask << 1)
        data = ints.astype(np.int32)
        if nchannels > 1:
            data = data.reshape(-1, nchannels)
        return data, framerate, sampwidth, nchannels
    else:
        dtype = np.int32 if sampwidth == 4 else None

    data = np.frombuffer(raw, dtype=dtype)
    if nchannels > 1:
        data = data.reshape(-1, nchannels)
    return data, framerate, sampwidth, nchannels


def _write_wav(path: Path, data: np.ndarray, framerate: int, sampwidth: int, nchannels: int):
    # Ensure directory exists
    path.parent.mkdir(parents=True, exist_ok=True)
    # Convert to bytes
    if sampwidth == 3:
        # 24-bit handling
        ints = data.astype(np.int32)
        a = np.empty((ints.size, 3), dtype=np.uint8)
        a[:, 0] = (ints & 0xFF).astype(np.uint8)
        a[:, 1] = ((ints >> 8) & 0xFF).astype(np.uint8)
        a[:, 2] = ((ints >> 16) & 0xFF).astype(np.uint8)
        raw = a.tobytes()
    else:
        raw = data.tobytes()

    with wave.open(str(path), 'wb') as w:
        w.setnchannels(nchannels)
        w.setsampwidth(sampwidth)
        w.setframerate(framerate)
        w.writeframes(raw)


def _resample_np(data: np.ndarray, old_sr: int, new_sr: int) -> np.ndarray:
    """Simple resample using linear interpolation (channels preserved)."""
    if old_sr == new_sr:
        return data
    ratio = new_sr / float(old_sr)
    length_old = data.shape[0]
    length_new = int(np.round(length_old * ratio))
    if data.ndim == 1:
        old_idx = np.arange(length_old)
        new_idx = np.linspace(0, length_old - 1, length_new)
        return np.interp(new_idx, old_idx, data).astype(data.dtype)
    else:
        # multichannel
        channels = []
        for ch in range(data.shape[1]):
            old = data[:, ch]
            old_idx = np.arange(length_old)
            new_idx = np.linspace(0, length_old - 1, length_new)
            ch_res = np.interp(new_idx, old_idx, old)
            channels.append(ch_res)
        return np.stack(channels, axis=1).astype(data.dtype)


def _resample(data: np.ndarray, old_sr: int, new_sr: int) -> np.ndarray:
    if scipy_resample is not None:
        # scipy_resample takes number of samples
        new_n = int(round(data.shape[0] * (new_sr / old_sr)))
        if data.ndim == 1:
            return scipy_resample(data, new_n).astype(data.dtype)
        else:
            out = np.zeros((new_n, data.shape[1]), dtype=data.dtype)
            for i in range(data.shape[1]):
                out[:, i] = scipy_resample(data[:, i], new_n)
            return out
    else:
        return _resample_np(data, old_sr, new_sr)


def disguise_audio(input_wav: str | Path, semitones: Optional[float] = None, time_stretch: Optional[float] = None) -> Path:
    """Create a disguised version of `input_wav` and return the new path.

    Pitch shifting is implemented by resampling the audio to a different
    sample rate and then writing the file back at the original sample rate.
    This changes perceived pitch without requiring heavy DSP libraries.
    """
    p = Path(input_wav)
    if not p.exists():
        raise FileNotFoundError(input_wav)

    # Read config from env if not explicitly provided
    if semitones is None:
        try:
            semitones = float(os.environ.get('VOICE_CHANGER_SEMITONES', '3'))
        except Exception:
            semitones = 3.0
    if time_stretch is None:
        try:
            time_stretch = float(os.environ.get('VOICE_CHANGER_TIME_STRETCH', '1.0'))
        except Exception:
            time_stretch = 1.0

    data, sr, sampwidth, nchannels = _read_wav(p)

    # compute pitch shift ratio (semitones => multiplier)
    pitch_ratio = 2 ** (semitones / 12.0)

    # Step 1: resample to achieve pitch shift
    target_sr = int(round(sr * pitch_ratio))
    shifted = _resample(data, sr, target_sr)

    # Step 2: time-stretch (implemented as resample back to adjust duration)
    # If time_stretch != 1.0 we adjust the final playback speed by resampling
    final_sr = int(round(target_sr * (1.0 / time_stretch)))
    final = _resample(shifted, target_sr, final_sr)

    # Finally, write output back at original sample rate so container/sample rate
    # is same as input; if final_sr != sr, resample to sr
    if final_sr != sr:
        out = _resample(final, final_sr, sr)
    else:
        out = final

    # Ensure dtype same as input where possible
    # Clip to range for common widths
    if sampwidth == 1:
        out = np.clip(out, 0, 255).astype(np.uint8)
    elif sampwidth == 2:
        out = np.clip(out, -32768, 32767).astype(np.int16)
    elif sampwidth == 3:
        out = out.astype(np.int32)
    else:
        out = out.astype(np.int32)

    out_path = p.with_name(p.stem + '_disguised' + p.suffix)
    _write_wav(out_path, out, sr, sampwidth, nchannels)
    return out_path


if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument('wav', help='Input WAV file')
    parser.add_argument('--semitones', type=float, default=None)
    parser.add_argument('--time-stretch', type=float, default=None)
    args = parser.parse_args()
    out = disguise_audio(args.wav, semitones=args.semitones, time_stretch=args.time_stretch)
    print('Disguised audio written to', out)
