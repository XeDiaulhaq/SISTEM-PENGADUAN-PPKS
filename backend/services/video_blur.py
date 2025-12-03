"""Utility helpers to blur faces inside recorded videos before storage."""
from __future__ import annotations

from pathlib import Path
from typing import Optional
import shutil
import subprocess

import cv2
import numpy as np

_BACKEND_DIR = Path(__file__).resolve().parents[1]
_PROTOTXT = _BACKEND_DIR / "models" / "deploy.prototxt.txt"
_MODEL = _BACKEND_DIR / "models" / "res10_300x300_ssd_iter_140000.caffemodel"
_CONFIDENCE_THRESHOLD = 0.5


class BlurVideoError(RuntimeError):
    """Raised when a video cannot be processed for face blurring."""


_net = None


def _load_net() -> cv2.dnn_Net:
    global _net  # lazy-load the DNN once and reuse between requests
    if _net is None:
        if not _PROTOTXT.exists() or not _MODEL.exists():
            raise BlurVideoError("Face detection model files are missing in backend/models")
        _net = cv2.dnn.readNetFromCaffe(str(_PROTOTXT), str(_MODEL))
    return _net


def _blur_frame(frame: np.ndarray, net: cv2.dnn_Net) -> np.ndarray:
    """Apply Gaussian blur to every detected face inside the frame."""
    if frame is None or frame.size == 0:
        return frame

    (h, w) = frame.shape[:2]
    blob = cv2.dnn.blobFromImage(
        cv2.resize(frame, (300, 300)),
        1.0,
        (300, 300),
        (104.0, 177.0, 123.0),
    )
    net.setInput(blob)
    detections = net.forward()

    for i in range(0, detections.shape[2]):
        confidence = float(detections[0, 0, i, 2])
        if confidence < _CONFIDENCE_THRESHOLD:
            continue

        box = detections[0, 0, i, 3:7] * np.array([w, h, w, h])
        (start_x, start_y, end_x, end_y) = box.astype("int")

        start_x = max(0, start_x)
        start_y = max(0, start_y)
        end_x = min(w, end_x)
        end_y = min(h, end_y)
        if end_x <= start_x or end_y <= start_y:
            continue

        face_roi = frame[start_y:end_y, start_x:end_x]
        if face_roi.size == 0:
            continue
        blurred = cv2.GaussianBlur(face_roi, (51, 51), 30)
        frame[start_y:end_y, start_x:end_x] = blurred

    return frame


def _merge_audio_tracks(original: Path, blurred: Path) -> bool:
    """Try to copy the original audio track onto the blurred video using ffmpeg."""
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        print("⚠️  ffmpeg not found; blurred video will be silent.")
        return False

    temp_output = blurred.with_name(f"{blurred.stem}_with_audio{blurred.suffix}")
    cmd = [
        ffmpeg,
        "-y",
        "-i",
        str(blurred),
        "-i",
        str(original),
        "-map",
        "0:v:0",
        "-map",
        "1:a?",
        "-c:v",
        "copy",
        "-c:a",
        "aac",
        "-shortest",
        str(temp_output),
    ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
    except Exception as exc:  # pragma: no cover - defensive logging
        print(f"⚠️  ffmpeg merge failed: {exc}")
        return False

    if result.returncode != 0 or not temp_output.exists():
        print("⚠️  Unable to merge audio track; keeping silent video.")
        if result.stderr:
            print(result.stderr.splitlines()[-1])
        return False

    try:
        blurred.unlink(missing_ok=True)
    except FileNotFoundError:
        pass
    temp_output.replace(blurred)
    return True


def blur_video_file(source: Path, destination: Optional[Path] = None) -> Path:
    """Blur all detected faces in *source* video and store the result.

    When *destination* is omitted the original file will be replaced in-place.
    Returns the final path that holds the blurred video.
    """

    source_path = Path(source)
    if not source_path.exists():
        raise BlurVideoError(f"Source video not found: {source_path}")

    net = _load_net()
    capture = cv2.VideoCapture(str(source_path))
    if not capture.isOpened():
        raise BlurVideoError("Cannot open video for processing")

    width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH)) or 640
    height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT)) or 480
    fps = float(capture.get(cv2.CAP_PROP_FPS) or 0) or 24.0

    replace_original = destination is None
    final_output = Path(destination) if destination else source_path
    working_output = (
        final_output
        if destination
        else source_path.with_name(f"{source_path.stem}_blurpass{source_path.suffix}")
    )

    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    writer = cv2.VideoWriter(str(working_output), fourcc, fps, (width, height))
    if not writer.isOpened():
        capture.release()
        raise BlurVideoError("Unable to open video writer for blurred output")

    success = False
    try:
        while True:
            ret, frame = capture.read()
            if not ret:
                success = True
                break
            processed = _blur_frame(frame, net)
            writer.write(processed)
    finally:
        capture.release()
        writer.release()

    if not success:
        if working_output.exists():
            working_output.unlink()
        raise BlurVideoError("Video processing ended unexpectedly")

    _merge_audio_tracks(source_path, working_output)

    if replace_original:
        backup_original = source_path.with_name(f"{source_path.stem}_raw{source_path.suffix}")
        if backup_original.exists():
            backup_original.unlink()
        source_path.replace(backup_original)
        working_output.replace(source_path)
        try:
            backup_original.unlink()
        except OSError:
            pass
        return source_path

    return working_output
