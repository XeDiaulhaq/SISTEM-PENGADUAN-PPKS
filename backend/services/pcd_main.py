import sys
import cv2
import numpy as np
from datetime import datetime
import os
import base64
import requests
import time
import argparse
import threading
from collections import deque

try:
    from services.audio_recorder import AudioRecorder
except ImportError:  # fallback kalau dijalankan via `python services/pcd_main.py`
    from audio_recorder import AudioRecorder

# Try to import the centralized merge utility (works when running from backend/)
try:
    from services.merge_audio_video import merge_audio_video as _central_merge_fn
except Exception:
    try:
        from backend.services.merge_audio_video import merge_audio_video as _central_merge_fn
    except Exception:
        _central_merge_fn = None

"""
pcd_main.py
------------
Production-ready face anonymization module.
Designed for server environments without GUI.
Accepts video streams or file inputs and returns anonymized outputs.
Includes robust error handling and logging.
"""

# --- DNN Model Configuration ---
# Get the backend directory (parent of services directory)
_BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
prototxt_path = os.path.join(_BACKEND_DIR, "models/deploy.prototxt.txt")
model_path = os.path.join(_BACKEND_DIR, "models/res10_300x300_ssd_iter_140000.caffemodel")
confidence_threshold = 0.5  # Minimum probability to filter weak detections

# --- Load the DNN Model (kept at module import so process_frame_base64 dapat digunakan)
try:
    net = cv2.dnn.readNetFromCaffe(prototxt_path, model_path)
    # Try to use OpenCL FP16 if available for speed; fallback to CPU
    try:
        net.setPreferableBackend(cv2.dnn.DNN_BACKEND_OPENCV)
        try:
            net.setPreferableTarget(cv2.dnn.DNN_TARGET_OPENCL_FP16)
            print("✓ DNN target: OpenCL FP16")
        except Exception:
            net.setPreferableTarget(cv2.dnn.DNN_TARGET_CPU)
            print("ℹ️ DNN target: CPU")
    except Exception:
        pass
    print("✓ DNN face detection model loaded successfully.")
except cv2.error as e:
    print(f"✗ Error loading DNN model: {e}")
    print("Make sure 'deploy.prototxt.txt' and 'res10_300x300_ssd_iter_140000.caffemodel' exist.")
    # don't sys.exit here; raise so importing app can handle it if needed
    raise

# --- Command line args (allow using file/video as source) ---
def _parse_args(argv=None):
    parser = argparse.ArgumentParser(description='pcd-main: face blur and optional frame uploader')
    parser.add_argument('--source', '-s', help='Path to image or video file to use instead of webcam')
    parser.add_argument('--device', '-d', help='Camera device index (0,1,...) or path (/dev/video0). Overrides default camera when no --source provided')
    parser.add_argument('--no-upload', action='store_true', help="Don't send frames to BACKEND_URL (for local testing)")
    return parser.parse_args(argv)


def main(argv=None):
    """Main capture/process loop. Can be invoked as a subprocess or from code.

    argv: list or None. If None, defaults to sys.argv[1:]
    """
    args = _parse_args(argv)

    def _parse_audio_device(value):
        if value is None:
            return None
        value = str(value).strip()
        if not value:
            return None
        try:
            return int(value)
        except ValueError:
            return value

    # --- Helper utilities (local to main) ---
    # These are defined here so they can access main's local state (video_writer, etc.)
    video_writer = None
    recording = False
    output_dir = 'recordings'
    audio_recorder = None
    audio_enabled = os.environ.get('ENABLE_AUDIO', '1') != '0'
    audio_device_pref = _parse_audio_device(os.environ.get('AUDIO_DEVICE') or os.environ.get('AUDIO_DEVICE_INDEX'))
    
    # Current video and audio file paths (for merging)
    current_video_file = None
    current_audio_file = None
    current_recording_path = None
    recording_started_at = None
    output_dir = os.path.join(_BACKEND_DIR, 'recordings')

    def _notify_report_backend(file_path: str | None, started_at: datetime | None, ended_at: datetime | None):
        """Send metadata about a completed recording to FastAPI reports endpoint."""
        api_url = os.environ.get('REPORT_API_URL')
        if not api_url or not file_path:
            return

        try:
            payload = {
                'title': os.environ.get('REPORT_TITLE_PREFIX', 'Laporan PPKS') + ' ' + datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S'),
                'recording_path': file_path.replace('\\', '/'),
                'status': 'new',
                'duration_seconds': None,
                'submitted_by': os.environ.get('REPORT_SUBMITTED_BY', 'pcd_main'),
                'captured_at': started_at.isoformat() if started_at else None,
            }
            if started_at and ended_at and ended_at >= started_at:
                payload['duration_seconds'] = int((ended_at - started_at).total_seconds())

            headers = {'Content-Type': 'application/json'}
            api_key = os.environ.get('REPORT_API_KEY')
            if api_key:
                headers['X-Report-Api-Key'] = api_key

            resp = requests.post(api_url.rstrip('/'), json=payload, headers=headers, timeout=5)
            if resp.ok:
                try:
                    resp_payload = resp.json()
                except ValueError:
                    resp_payload = {}
                print(f"✓ Report metadata sent (id={resp_payload.get('id')})")
            else:
                print(f"✗ Failed to send report metadata (status={resp.status_code}): {resp.text}")
        except Exception as exc:
            print(f"✗ Exception sending report metadata: {exc}")

    def _oddize(n: int) -> int:
        """Return an odd integer >= 3 based on n."""
        n = max(3, int(n))
        return n if (n % 2) == 1 else n + 1

    def apply_gaussian_blur(image: np.ndarray, kernel_factor: int = 3) -> np.ndarray:
        """Apply Gaussian blur to an image using a kernel derived from image size."""
        if image is None or image.size == 0:
            return image
        h, w = image.shape[:2]
        try:
            kf = max(1, int(kernel_factor))
        except Exception:
            kf = 3
        k = _oddize(max(3, min(h, w) // kf))
        k = min(k, max(3, min(h, w) if min(h, w) % 2 == 1 else min(h, w) - 1))
        if k <= 1:
            return image
        return cv2.GaussianBlur(image, (k, k), 0)

    def apply_mosaic_blur(image: np.ndarray, block_size: int = 10) -> np.ndarray:
        """Apply mosaic (pixelated) blur to image."""
        h, w = image.shape[:2]
        block_size = max(1, block_size)
        small_h, small_w = max(1, h // block_size), max(1, w // block_size)
        temp = cv2.resize(image, (small_w, small_h), interpolation=cv2.INTER_LINEAR)
        mosaic = cv2.resize(temp, (w, h), interpolation=cv2.INTER_NEAREST)
        return mosaic

    def _start_audio_recording():
        """Start microphone capture if the feature is enabled.

        Sets `current_audio_file` to the path returned by the recorder so the
        merge step knows which file to use.
        """
        nonlocal audio_recorder, current_audio_file
        if not audio_enabled or audio_recorder is None:
            return
        if audio_recorder.is_recording:
            # already recording; ensure current_audio_file is populated
            current_audio_file = getattr(audio_recorder, 'output_path', None)
            return
        try:
            path = audio_recorder.start()
            current_audio_file = path
            print(f"✓ Audio recording started: {path}")
        except Exception as exc:
            print(f"✗ Failed to start audio recording: {exc}")

    def _stop_audio_recording():
        nonlocal audio_recorder
        if audio_recorder is None or not audio_recorder.is_recording:
            return
        try:
            path = audio_recorder.stop()
            if path:
                print(f"✓ Audio saved to: {path}")
                return path
        except Exception as exc:
            print(f"✗ Failed to stop audio recording cleanly: {exc}")
        return None

    def _merge_audio_video(video_file, audio_file):
        """Merge audio+video.

        Prefer the centralized `merge_audio_video` function (if available) which
        handles ffmpeg detection robustly. Otherwise fall back to a local
        subprocess ffmpeg merge.
        """
        # Basic checks
        if not os.path.exists(video_file) or not os.path.exists(audio_file):
            return False

        # 1) Try central merge function (from merge_audio_video.py)
        if _central_merge_fn is not None:
            try:
                # central function signature: merge_audio_video(video, audio, output)
                out = video_file  # overwrite original video file with merged result
                success = _central_merge_fn(video_file, audio_file, out)
                return bool(success)
            except Exception as e:
                print(f"⚠️ Central merge function failed: {e}")

        # 2) Fallback: local ffmpeg subprocess
        try:
            import subprocess
            # Ensure ffmpeg available
            try:
                subprocess.run(['ffmpeg', '-version'], capture_output=True, timeout=5)
            except Exception:
                print("⚠️ ffmpeg not available for fallback merge")
                return False

            base_name = os.path.splitext(video_file)[0]
            merged_file = base_name + '_merged.mp4'
            cmd = [
                'ffmpeg', '-y', '-i', video_file, '-i', audio_file,
                '-c:v', 'copy', '-c:a', 'aac', '-shortest', merged_file
            ]
            print(f"✓ Merging audio with video (fallback)...")
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
            if res.returncode == 0 and os.path.exists(merged_file):
                try:
                    os.replace(merged_file, video_file)
                except Exception:
                    try:
                        os.remove(video_file)
                        os.rename(merged_file, video_file)
                    except Exception:
                        pass
                # Optionally remove audio file
                try:
                    os.remove(audio_file)
                except Exception:
                    pass
                print(f"✓ Merged and replaced: {video_file}")
                return True
            else:
                print(f"⚠️ Fallback merge failed: {res.stderr if hasattr(res, 'stderr') else res}")
                return False
        except Exception as e:
            print(f"⚠️ Error during fallback merge: {e}")
            return False

    def start_recording():
        nonlocal video_writer, recording, current_video_file, current_audio_file
        nonlocal video_writer, recording, current_recording_path, recording_started_at
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)
        filename = os.path.join(output_dir, f'recording_{timestamp}.mp4')
        fourcc = cv2.VideoWriter_fourcc(*'mp4v')
        try:
            vw = cv2.VideoWriter(filename, fourcc, fps, (frame_width, frame_height))
            if vw.isOpened():
                video_writer = vw
                current_video_file = filename
                current_recording_path = filename
                recording_started_at = datetime.utcnow()
                print(f"✓ Recording started: {filename}")
                # Ensure audio filename matches video timestamp so merging is straightforward
                try:
                    if audio_recorder is not None:
                        # set prefix to include same timestamp
                        audio_recorder.filename_prefix = f"audio_capture_{timestamp}"
                except Exception:
                    pass
                _start_audio_recording()
                return True
            else:
                print("✗ Failed to start recording")
                video_writer = None
                current_video_file = None
                return False
        except Exception as e:
            print(f"✗ Exception starting recording: {e}")
            video_writer = None
            current_video_file = None
            return False

    def stop_recording():
        nonlocal video_writer, recording, current_video_file, current_audio_file
        nonlocal video_writer, recording, current_recording_path, recording_started_at
        finished_at = datetime.utcnow()
        if video_writer is not None:
            try:
                video_writer.release()
            except Exception:
                pass
            video_writer = None
            print("✓ Recording stopped")
        
        # Stop audio and get the audio file path
        audio_path = _stop_audio_recording()

        # Wait briefly for audio to be flushed and present on disk (retry a few times)
        if audio_path is None and current_audio_file:
            audio_path = current_audio_file

        # Retry loop: wait up to ~3 seconds for audio file to exist
        attempts = 0
        while attempts < 6 and (audio_path is None or not os.path.exists(audio_path)):
            time.sleep(0.5)
            attempts += 1
            if current_audio_file and os.path.exists(current_audio_file):
                audio_path = current_audio_file

        # Merge audio with video if both exist
        if current_video_file and audio_path:
            if os.path.exists(current_video_file) and os.path.exists(audio_path):
                merged_ok = _merge_audio_video(current_video_file, audio_path)
                if not merged_ok:
                    print("⚠️ Automatic merge failed; files kept for manual inspection:")
                    print(f"   Video: {current_video_file}")
                    print(f"   Audio: {audio_path}")

        current_video_file = None
        current_audio_file = None
        if current_recording_path:
            rel_path = os.path.relpath(current_recording_path, _BACKEND_DIR)
        else:
            rel_path = None
        _notify_report_backend(rel_path, recording_started_at, finished_at)
        current_recording_path = None
        recording_started_at = None

    def send_frame_to_backend(img: np.ndarray):
        """Encode frame as JPEG base64 and POST to backend /upload_frame if BACKEND_URL is set.

        Tunable via env vars:
         - UPLOAD_MAX_WIDTH (int, default 640): resize width while keeping aspect ratio
         - UPLOAD_JPEG_QUALITY (int, default 60): JPEG quality
        """
        backend_url = os.environ.get('BACKEND_URL')
        if not backend_url:
            return False
        try:
            up_max_w = int(os.environ.get('UPLOAD_MAX_WIDTH', '640'))
            jpg_q = int(os.environ.get('UPLOAD_JPEG_QUALITY', '60'))

            frame_to_send = img
            # Resize to reduce bandwidth if wider than target
            try:
                if up_max_w > 0 and frame_to_send.shape[1] > up_max_w:
                    ratio = up_max_w / float(frame_to_send.shape[1])
                    new_h = max(1, int(frame_to_send.shape[0] * ratio))
                    frame_to_send = cv2.resize(frame_to_send, (up_max_w, new_h), interpolation=cv2.INTER_AREA)
            except Exception:
                pass

            _, buffer = cv2.imencode('.jpg', frame_to_send, [int(cv2.IMWRITE_JPEG_QUALITY), max(30, min(95, jpg_q))])
            jpg_b64 = base64.b64encode(buffer).decode('ascii')
            payload = {'image': jpg_b64}
            resp = requests.post(f"{backend_url.rstrip('/')}/upload_frame", json=payload, timeout=2.0)
            return resp.ok
        except Exception as e:
            print(f"✗ Failed to send frame to backend: {e}")
            return False

    # --- Camera and Settings ---
    capture = None
    image_source = None
    if args.source:
        src = args.source
        if not os.path.exists(src):
            print(f"✗ Source not found: {src}")
            return 1
        # If source is an image, load it once and reuse
        if os.path.splitext(src)[1].lower() in ('.jpg', '.jpeg', '.png', '.bmp'):
            image_source = cv2.imread(src)
            if image_source is None:
                print(f"✗ Failed to read image: {src}")
                return 1
            print(f"Using image file as source: {src}")
            frame_width = int(image_source.shape[1])
            frame_height = int(image_source.shape[0])
            fps = 1
        else:
            capture = cv2.VideoCapture(src)
            if not capture.isOpened():
                print("✗ Error: could not open video file. Check the path and codecs.")
                return 1
            frame_width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH))
            frame_height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT))
            fps = int(capture.get(cv2.CAP_PROP_FPS)) or 30
            print(f"Using video file as source: {src}")
    else:
        # If user provided --device use it, otherwise default to 0
        device = args.device
        if device is None:
            device = 0
        else:
            # try convert numeric strings to int index
            try:
                device = int(device)
            except Exception:
                # leave as string path like '/dev/video0'
                pass

        def try_open_camera(dev):
            cap = cv2.VideoCapture(dev)
            if cap.isOpened():
                return cap, dev
            try:
                cap.release()
            except Exception:
                pass
            return None, None

        cap, used = try_open_camera(device)
        # If specified device failed and device is numeric index, try scanning 0..4
        if cap is None and isinstance(device, int):
            print(f"⚠️ Failed to open device index {device}, scanning indices 0..4 for available camera...")
            for i in range(0, 5):
                cap_try, used_try = try_open_camera(i)
                if cap_try is not None:
                    cap = cap_try
                    used = used_try
                    print(f"✓ Found camera at index {i}")
                    break

        if cap is None:
            print(f"✗ Error: could not open video capture (device={device}). Check your camera and permissions.")
            print("If you don't have a camera, run with --source path/to/image.jpg or use tools/send_sample.py")
            # Extra diagnostics suggestion
            print("Run 'ls -l /dev/video*' and 'v4l2-ctl --list-devices' (install v4l-utils) to inspect devices")
            return 1

        capture = cap
        device = used
        frame_width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH))
        frame_height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT))
        fps = int(capture.get(cv2.CAP_PROP_FPS)) or 30

    # Blur type selection (env override: BLUR_TYPE)
    blur_type = os.environ.get('BLUR_TYPE', 'mosaic').lower()  # 'gaussian', 'mosaic', or 'none'
    blur_enabled = True  # Toggle blur on/off

    # Video recording setting
    recording = False  # Toggle video recording
    video_writer = None

    # Create output directory if it doesn't exist
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    # Display control: if NO_DISPLAY=1 then run headless (no cv2.imshow / keyboard handling)
    display_enabled = os.environ.get('NO_DISPLAY', '0') != '1'
    use_cv2_display = False

    if display_enabled:
        try:
            cv2.namedWindow('pcd_display_probe')
            cv2.destroyWindow('pcd_display_probe')
            use_cv2_display = True
            print('✓ OpenCV GUI tersedia, akan menampilkan jendela.')
        except cv2.error as e:
            print('⚠️ OpenCV tidak memiliki dukungan GUI (detail: {})'.format(e))
            print('⚠️ Install paket "opencv-python" (bukan headless) jika ingin menampilkan jendela.')
            use_cv2_display = False

    if not use_cv2_display:
        print('ℹ️ Mode headless aktif. Set NO_DISPLAY=0 dan pastikan paket GUI tersedia untuk menampilkan jendela.')

    # --- Initialize Audio Recorder at startup ---
    if audio_enabled:
        try:
            audio_recorder = AudioRecorder(device=audio_device_pref)
            print(f"✓ Audio recorder initialized (device preference: {audio_device_pref})")
        except Exception as exc:
            print(f"⚠️ Failed to initialize audio recorder: {exc}")
            audio_recorder = None
            audio_enabled = False

    # Initialize window name for display
    WINDOW_NAME = 'Face Blur Detection (DNN) - Press Q to Quit'

    # Frame queue for matplotlib display (thread-safe)
    # --- Main Loop ---
    loop_count = 0
    upload_every_n = int(os.environ.get('UPLOAD_EVERY_N', '1'))  # send every Nth frame
    # Reuse detections between frames to reduce DNN calls (persist across frames)
    detect_every_n = int(os.environ.get('DETECT_EVERY_N', '2'))
    max_box_age = int(os.environ.get('MAX_BOX_AGE', '5'))
    last_boxes = []  # list of (startX, startY, endX, endY)
    last_boxes_age = 0
    while True:
        if image_source is not None:
            img = image_source.copy()
            success = True
        else:
            success, img = capture.read()
        if not success or img is None:
            print("Warning: failed to read frame. Exiting.")
            break

        # Apply mirror/flip (always enabled)
        img = cv2.flip(img, 1)

        # --- DNN Face Detection (every N frames) ---
        (h, w) = img.shape[:2]  # Frame height and width

        def _blur_boxes_on_img(boxes):
            nonlocal img
            if not blur_enabled or blur_type == 'none':
                return
            for (startX, startY, endX, endY) in boxes:
                # ensure bounds
                sx = max(0, min(startX, w-1)); ex = max(0, min(endX, w))
                sy = max(0, min(startY, h-1)); ey = max(0, min(endY, h))
                if ex <= sx or ey <= sy:
                    continue
                face_roi = img[sy:ey, sx:ex]
                if face_roi.size <= 0:
                    continue
                if blur_type == 'gaussian':
                    box_w = ex - sx
                    k_factor = 3
                    _ = _oddize(max(3, box_w // k_factor))
                    blurred = apply_gaussian_blur(face_roi, kernel_factor=k_factor)
                elif blur_type == 'mosaic':
                    mosaic_block_size = max(3, (ex - sx) // 15)
                    blurred = apply_mosaic_blur(face_roi, block_size=mosaic_block_size)
                else:
                    blurred = face_roi
                img[sy:ey, sx:ex] = blurred

        run_detection = (detect_every_n <= 1) or ((loop_count % detect_every_n) == 0)
        if run_detection:
            blob = cv2.dnn.blobFromImage(cv2.resize(img, (300, 300)), 1.0,
                (300, 300), (104.0, 177.0, 123.0))
            net.setInput(blob)
            detections = net.forward()

            current_boxes = []
            for i in range(0, detections.shape[2]):
                confidence = detections[0, 0, i, 2]
                if confidence > confidence_threshold:
                    box = detections[0, 0, i, 3:7] * np.array([w, h, w, h])
                    (startX, startY, endX, endY) = box.astype("int")
                    startX = max(0, startX)
                    startY = max(0, startY)
                    endX = min(w, endX)
                    endY = min(h, endY)
                    if endX > startX and endY > startY:
                        current_boxes.append((startX, startY, endX, endY))

            last_boxes = current_boxes
            last_boxes_age = 0
            _blur_boxes_on_img(last_boxes)
            face_found = len(current_boxes) > 0
        else:
            # reuse previous boxes for a few frames
            if last_boxes and last_boxes_age < max_box_age:
                _blur_boxes_on_img(last_boxes)
                last_boxes_age += 1
                face_found = True
            else:
                face_found = False

        # Display "No Face Found" if applicable
        if not face_found:
            cv2.putText(img, 'No Face Found!', (20, 50), cv2.FONT_HERSHEY_COMPLEX, 1, (0, 0, 255), 2)

        # Write frame to video file if recording
        if recording and video_writer is not None:
            video_writer.write(img)

        # Display current status
        blur_status = 'OFF' if not blur_enabled else blur_type.upper()
        recording_status = 'REC' if recording else 'OFF'
        mode_text = f'Blur: {blur_status} | Rec: {recording_status} | [G]aussian [M]osaic [B]lur ON/OFF [R]ec ON/OFF [Q]uit'
        cv2.putText(img, mode_text, (10, img.shape[0] - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 1)

        # Best-effort: send frame to backend with downsampling to reduce bandwidth/latency
        try:
            if not args.no_upload and (upload_every_n <= 1 or (loop_count % upload_every_n) == 0):
                send_frame_to_backend(img)
        except Exception:
            pass

        if display_enabled and use_cv2_display:
            try:
                cv2.imshow(WINDOW_NAME, img)
                key = cv2.waitKey(1) & 0xff
            except cv2.error as e:
                print(f"⚠️ Error menampilkan frame: {e}. Menonaktifkan display.")
                display_enabled = False
                use_cv2_display = False
                key = -1
            if key == ord('q') or key == 27:  # 'q' or ESC to quit
                print("✓ Quit command received")
                break
            elif key == ord('g'):
                blur_type = 'gaussian'
                blur_enabled = True
                print("✓ Switched to Gaussian Blur mode (ENABLED)")
            elif key == ord('m'):
                blur_type = 'mosaic'
                blur_enabled = True
                print("✓ Switched to Mosaic Blur mode (ENABLED)")
            elif key == ord('b'):
                blur_enabled = not blur_enabled
                status = "ENABLED" if blur_enabled else "DISABLED"
                print(f"✓ Blur {status}")
            elif key == ord('r'):
                recording = not recording
                if recording:
                    if not start_recording():  # Check if recording actually started
                        recording = False  # Revert state if failed
                else:
                    stop_recording()
        else:
            # Headless mode: sleep ringan dan lanjut loop
            try:
                time.sleep(0.005)
            except KeyboardInterrupt:
                break

        loop_count += 1

    # --- Cleanup ---
    if recording:
        stop_recording()
    else:
        _stop_audio_recording()

    # Release capture if it exists
    try:
        if capture is not None:
            capture.release()
    except Exception:
        pass

    # Only call destroyAllWindows if display is enabled and OpenCV supports it
    if display_enabled:
        try:
            cv2.destroyAllWindows()
            print("✓ Display windows closed.")
        except Exception:
            # Some OpenCV builds (headless) don't implement GUI functions
            pass

    print("✓ PCD main exited gracefully.")
    print("✓ Application finished gracefully.")


# === Modular function for backend integration ===
def process_frame_base64(img_b64: str) -> str:
    """
    Receive base64 image → decode → blur face → return base64 image (processed)
    Used by Flask backend when receiving /upload_frame.
    """
    import base64
    import cv2
    import numpy as np

    try:
        # Decode base64 → numpy array
        img_data = base64.b64decode(img_b64)
        np_arr = np.frombuffer(img_data, np.uint8)
        frame = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)

        if frame is None:
            print("✗ Invalid frame data received")
            return img_b64

        # --- DNN Face Detection ---
        (h, w) = frame.shape[:2]
        blob = cv2.dnn.blobFromImage(
            cv2.resize(frame, (300, 300)), 1.0,
            (300, 300), (104.0, 177.0, 123.0)
        )

        net.setInput(blob)
        detections = net.forward()

        # Loop over detections
        for i in range(0, detections.shape[2]):
            confidence = detections[0, 0, i, 2]

            if confidence > confidence_threshold:
                box = detections[0, 0, i, 3:7] * np.array([w, h, w, h])
                (x1, y1, x2, y2) = box.astype("int")

                # Validasi posisi agar tetap di dalam frame
                x1, y1 = max(0, x1), max(0, y1)
                x2, y2 = min(w, x2), min(h, y2)

                # Potong area wajah
                face = frame[y1:y2, x1:x2]
                if face.size > 0:
                    # Terapkan Gaussian blur ke area wajah
                    face = cv2.GaussianBlur(face, (51, 51), 30)
                    frame[y1:y2, x1:x2] = face

        # Encode kembali hasil frame ke base64
        _, buffer = cv2.imencode('.jpg', frame)
        processed_b64 = base64.b64encode(buffer).decode('ascii')
        return processed_b64

    except Exception as e:
        print(f"✗ Error processing frame: {e}")
        return img_b64  # fallback ke gambar asli bila error


print("✓ Module ready: pcd_main loaded")


if __name__ == '__main__':
    # When run as a script, start the main loop (returns exit code)
    try:
        sys.exit(main())
    except Exception as e:
        print(f"✗ Unhandled exception in main: {e}")
        raise
