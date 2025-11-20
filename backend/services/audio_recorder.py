"""Audio recording helpers for the computer-vision service.

This module keeps microphone recording concerns isolated from ``pcd_main`` so the
vision pipeline can simply start/stop an ``AudioRecorder`` when it boots.

Dependencies
------------
``PyAudio`` is required for realtime capture::

    pip install pyaudio

On Linux make sure the system package ``portaudio`` is installed (``sudo pacman -Syu portaudio``
for Manjaro/Arch). If your platform exposes multiple microphone devices pass the
``device`` index when constructing the recorder. The output is a standard PCM WAV
file placed in ``services/recordings/audio`` by default so existing artifacts stay grouped
under the service folder.
"""
from __future__ import annotations

import queue
import threading
import wave
from contextlib import contextmanager
from datetime import datetime
from pathlib import Path
from typing import Optional, Union

try:  # PyAudio gives portable access to PortAudio devices.
    import pyaudio
except ImportError:  # pragma: no cover - exercised only when dependency missing
    pyaudio = None  # type: ignore

# Directory that will contain audio captures (sits next to ``pcd_main``).
_RECORDINGS_DIR = Path(__file__).resolve().parent / "recordings" / "audio"

# Mapping of dtype -> WAV sample width in bytes and PyAudio format codes.
_SAMPLE_WIDTH = {
    "int16": 2,
    "int24": 3,
    "int32": 4,
    "float32": 4,
}

_FORMAT_CODES = {}
if pyaudio is not None:  # pragma: no branch - executed once at import
    _FORMAT_CODES = {
        "int16": pyaudio.paInt16,
        "int24": pyaudio.paInt24,
        "int32": pyaudio.paInt32,
        "float32": pyaudio.paFloat32,
    }


class AudioRecorder:
    """Small helper that records audio on a background thread.

    The recorder uses ``PyAudio`` (PortAudio) streams for portability. Frames are
    pushed through a queue so the OpenCV loop never blocks while the WAV writer
    drains audio samples to disk.
    """

    def __init__(
        self,
        *,
        sample_rate: int = 44_100,
        channels: int = 1,
        chunk_size: int = 2048,
        dtype: str = "int16",
        device: Optional[Union[int, str]] = None,
        output_dir: Optional[Path] = None,
        filename_prefix: str = "audio_capture",
    ) -> None:
        self.sample_rate = sample_rate
        self.channels = channels
        self.chunk_size = chunk_size
        self.dtype = dtype
        self.device = device
        self.filename_prefix = filename_prefix
        self.output_dir = Path(output_dir) if output_dir else _RECORDINGS_DIR

        self._queue: "queue.Queue[Optional[bytes]]" = queue.Queue(maxsize=32)
        self._writer_thread: Optional[threading.Thread] = None
        self._reader_thread: Optional[threading.Thread] = None
        self._stop_event = threading.Event()
        self._pyaudio: Optional["pyaudio.PyAudio"] = None  # type: ignore[name-defined]
        self._stream: Optional["pyaudio.Stream"] = None  # type: ignore[name-defined]
        self._wave_handle: Optional[wave.Wave_write] = None
        self._output_path: Optional[Path] = None

    # ------------------------------------------------------------------
    def start(self) -> Path:
        """Begin recording audio and return the WAV path."""
        if pyaudio is None:
            raise RuntimeError(
                "PyAudio is not installed. Run `pip install pyaudio` (and ensure portaudio is available)."
            )
        if self._stream is not None:
            return self._output_path  # type: ignore[return-value]

        self.output_dir.mkdir(parents=True, exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self._output_path = self.output_dir / f"{self.filename_prefix}_{timestamp}.wav"

        sample_width = _SAMPLE_WIDTH.get(self.dtype)
        fmt = _FORMAT_CODES.get(self.dtype)
        if sample_width is None or fmt is None:
            raise ValueError(
                f"Unsupported dtype '{self.dtype}'. Choose one of: {', '.join(sorted(_SAMPLE_WIDTH))}"
            )

        self._wave_handle = wave.open(str(self._output_path), "wb")
        self._wave_handle.setnchannels(self.channels)
        self._wave_handle.setsampwidth(sample_width)
        self._wave_handle.setframerate(self.sample_rate)

        # Writer thread drains bytes from the queue into the WAV file.
        self._stop_event.clear()
        self._writer_thread = threading.Thread(target=self._drain_queue, daemon=True)
        self._writer_thread.start()

        self._pyaudio = pyaudio.PyAudio()
        self._stream = self._open_stream_with_fallback(fmt)
        self._reader_thread = threading.Thread(target=self._capture_loop, daemon=True)
        self._reader_thread.start()
        return self._output_path

    def stop(self) -> Optional[Path]:
        """Stop recording and return the saved WAV path (if any)."""
        if self._stream is None:
            return self._output_path

        try:
            self._stop_event.set()
            if self._reader_thread is not None:
                self._reader_thread.join(timeout=2.0)
        finally:
            self._reader_thread = None

        try:
            if self._stream is not None:
                self._stream.stop_stream()
                self._stream.close()
        finally:
            self._stream = None
            if self._pyaudio is not None:
                self._pyaudio.terminate()
                self._pyaudio = None

        # Signal the writer thread to finish then close the WAV handle.
        self._queue.put(None)
        if self._writer_thread is not None:
            self._writer_thread.join(timeout=2.0)
            self._writer_thread = None

        if self._wave_handle is not None:
            self._wave_handle.close()
            self._wave_handle = None

        return self._output_path

    # ------------------------------------------------------------------
    def _capture_loop(self) -> None:  # pragma: no cover - best-effort threads
        if self._stream is None:
            return
        while not self._stop_event.is_set():
            try:
                data = self._stream.read(self.chunk_size, exception_on_overflow=False)
            except Exception as exc:
                print(f"⚠️ Audio capture error: {exc}")
                break
            try:
                self._queue.put_nowait(data)
            except queue.Full:
                try:
                    _ = self._queue.get_nowait()
                except queue.Empty:
                    pass
                self._queue.put_nowait(data)

    def _drain_queue(self) -> None:
        while not self._stop_event.is_set() or not self._queue.empty():
            try:
                chunk = self._queue.get(timeout=0.2)
            except queue.Empty:
                continue
            if chunk is None:
                break
            if self._wave_handle is not None:
                self._wave_handle.writeframes(chunk)

    # ------------------------------------------------------------------
    @property
    def is_recording(self) -> bool:
        return self._stream is not None and self._reader_thread is not None

    @property
    def output_path(self) -> Optional[Path]:
        return self._output_path

    # ------------------------------------------------------------------
    def _open_stream_with_fallback(self, fmt):
        if self._pyaudio is None:
            raise RuntimeError("PyAudio instance missing")

        candidates = self._candidate_device_indices(self.device)
        last_error = None
        for idx in candidates:
            try:
                label = 'default' if idx is None else f'index {idx}'
                stream = self._pyaudio.open(
                    format=fmt,
                    channels=self.channels,
                    rate=self.sample_rate,
                    input=True,
                    frames_per_buffer=self.chunk_size,
                    input_device_index=idx,
                )
                print(f"✓ Using audio input device ({label})")
                return stream
            except Exception as exc:
                last_error = exc
                print(f"⚠️ Failed to open audio device {label}: {exc}")
                continue

        self._log_available_devices()
        raise RuntimeError(f"Failed to open any audio input device. Last error: {last_error}")

    def _candidate_device_indices(self, requested: Optional[Union[int, str]]):
        if self._pyaudio is None:
            return [None]

        candidates: list[Optional[int]] = []

        def _append(idx: Optional[int]):
            if idx in candidates:
                return
            candidates.append(idx)

        if isinstance(requested, str):
            matches = self._match_device_name(requested)
            if matches:
                for idx in matches:
                    _append(idx)
            else:
                print(f"⚠️ Requested audio device '{requested}' not found; trying defaults.")
        elif isinstance(requested, int):
            _append(requested)

        try:
            default_idx = int(self._pyaudio.get_default_input_device_info().get('index'))
            _append(default_idx)
        except Exception:
            pass

        # Common PulseAudio/PipeWire/ALSA virtual devices
        for keyword in ('pulse', 'default'):
            for idx in self._match_device_name(keyword):
                _append(idx)

        # Fallback to first available input device
        for idx in range(self._pyaudio.get_device_count()):
            info = self._pyaudio.get_device_info_by_index(idx)
            if info.get('maxInputChannels', 0) > 0:
                _append(idx)
                break

        _append(None)  # Let PortAudio decide as last resort
        return candidates

    def _match_device_name(self, keyword: str):
        results = []
        if self._pyaudio is None:
            return results
        keyword = keyword.lower()
        for idx in range(self._pyaudio.get_device_count()):
            info = self._pyaudio.get_device_info_by_index(idx)
            name = info.get('name', '').lower()
            if keyword in name and info.get('maxInputChannels', 0) > 0:
                results.append(idx)
        return results

    def _log_available_devices(self) -> None:
        if self._pyaudio is None:
            return
        print("ℹ️ Available audio input devices:")
        for idx in range(self._pyaudio.get_device_count()):
            info = self._pyaudio.get_device_info_by_index(idx)
            max_input = int(info.get('maxInputChannels', 0))
            if max_input <= 0:
                continue
            print(f"   [{idx}] {info.get('name')} - {max_input} channel(s)")


@contextmanager
def audio_session(**kwargs):
    """Context manager that ensures the recorder stops even on exception."""
    recorder = AudioRecorder(**kwargs)
    try:
        recorder.start()
        yield recorder
    finally:
        recorder.stop()


if __name__ == "__main__":  # pragma: no cover
    import time

    if pyaudio is None:
        raise SystemExit("PyAudio is missing. Run `pip install pyaudio`.\n")

    print("Recording 5 seconds of audio to", _RECORDINGS_DIR)
    with audio_session() as rec:
        time.sleep(5)
        print("Recording saved to", rec.output_path)
