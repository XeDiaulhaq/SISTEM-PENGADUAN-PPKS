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

"""
pcd_main.py
------------
Production-ready face anonymization module.
Designed for server environments without GUI.
Accepts video streams or file inputs and returns anonymized outputs.
Includes robust error handling and logging.
"""

# --- DNN Model Configuration ---
prototxt_path = "models/deploy.prototxt.txt"
model_path = "models/res10_300x300_ssd_iter_140000.caffemodel"
confidence_threshold = 0.5  # Minimum probability to filter weak detections

# --- Load the DNN Model ---
try:
    net = cv2.dnn.readNetFromCaffe(prototxt_path, model_path)
    print("✓ DNN face detection model loaded successfully.")
except cv2.error as e:
    print(f"✗ Error loading DNN model: {e}")
    print("Make sure 'deploy.prototxt.txt' and 'res10_300x300_ssd_iter_140000.caffemodel' exist.")
    sys.exit(1)

# --- Command line args (allow using file/video as source) ---
parser = argparse.ArgumentParser(description='pcd-main: face blur and optional frame uploader')
parser.add_argument('--source', '-s', help='Path to image or video file to use instead of webcam')
parser.add_argument('--device', '-d', help='Camera device index (0,1,...) or path (/dev/video0). Overrides default camera when no --source provided')
parser.add_argument('--no-upload', action='store_true', help="Don't send frames to BACKEND_URL (for local testing)")
args = parser.parse_args()

# --- Camera and Settings ---
capture = None
image_source = None
if args.source:
    src = args.source
    if not os.path.exists(src):
        print(f"✗ Source not found: {src}")
        sys.exit(1)
    # If source is an image, load it once and reuse
    if os.path.splitext(src)[1].lower() in ('.jpg', '.jpeg', '.png', '.bmp'):
        image_source = cv2.imread(src)
        if image_source is None:
            print(f"✗ Failed to read image: {src}")
            sys.exit(1)
        print(f"Using image file as source: {src}")
        frame_width = int(image_source.shape[1])
        frame_height = int(image_source.shape[0])
        fps = 1
    else:
        capture = cv2.VideoCapture(src)
        if not capture.isOpened():
            print("✗ Error: could not open video file. Check the path and codecs.")
            sys.exit(1)
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
        sys.exit(1)

    capture = cap
    device = used
    frame_width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH))
    frame_height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = int(capture.get(cv2.CAP_PROP_FPS)) or 30

# Blur type selection
blur_type = 'gaussian'  # 'gaussian', 'mosaic', or 'none'
blur_enabled = True  # Toggle blur on/off

# Video recording setting
recording = False  # Toggle video recording
video_writer = None
output_dir = 'recordings'

# Create output directory if it doesn't exist
if not os.path.exists(output_dir):
    os.makedirs(output_dir)

# Display control: if NO_DISPLAY=1 then run headless (no cv2.imshow / keyboard handling)
display_enabled = os.environ.get('NO_DISPLAY', '0') != '1'

# Auto-detect if OpenCV was built with GUI support. If cv2.imshow would fail,
# switch to headless mode automatically.
if display_enabled:
    try:
        cv2.namedWindow('test')
        cv2.destroyWindow('test')
        use_cv2_display = True
    except cv2.error:
        print('⚠️ OpenCV has no GUI support, switching to matplotlib mode')
        use_cv2_display = False
else:
    use_cv2_display = False

# Try to use matplotlib as fallback for display
use_matplotlib = False
if display_enabled and not use_cv2_display:
    try:
        import matplotlib
        matplotlib.use('TkAgg')  # Use TkAgg backend for better compatibility
        import matplotlib.pyplot as plt
        from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
        import tkinter as tk
        use_matplotlib = True
        print('✓ Using Matplotlib with Tkinter for display')
    except ImportError as e:
        print(f'⚠️ Matplotlib/Tkinter not available: {e}')
        use_matplotlib = False
        display_enabled = False

print(f'Display enabled: {display_enabled} | Method: {"OpenCV" if use_cv2_display else ("Matplotlib" if use_matplotlib else "None")}')

# Initialize window name for display
WINDOW_NAME = 'Face Blur Detection (DNN) - Press Q to Quit'

# Frame queue for matplotlib display (thread-safe)
frame_queue = deque(maxlen=2)
frame_lock = threading.Lock()
matplotlib_window = None
matplotlib_fig = None
matplotlib_ax = None
stop_display_thread = False

# --- Helper Functions (Keep these as they are) ---
def _oddize(n: int) -> int:
    """Return an odd integer >= 3 based on n."""
    n = max(3, int(n))
    return n if (n % 2) == 1 else n + 1


def apply_gaussian_blur(image: np.ndarray, kernel_factor: int = 3) -> np.ndarray:
    """Apply Gaussian blur to an image using a kernel derived from image size.

    kernel_factor: larger values produce smaller kernels (less blur). The
    kernel size is computed from the smaller image dimension divided by
    kernel_factor and then made odd and at least 3.
    """
    if image is None or image.size == 0:
        return image
    h, w = image.shape[:2]
    # Protect against zero or negative kernel_factor
    try:
        kf = max(1, int(kernel_factor))
    except Exception:
        kf = 3
    k = _oddize(max(3, min(h, w) // kf))
    # Ensure k does not exceed image dimensions
    k = min(k, max(3, min(h, w) if min(h, w) % 2 == 1 else min(h, w) - 1))
    if k <= 1:
        return image
    return cv2.GaussianBlur(image, (k, k), 0)

def apply_mosaic_blur(image: np.ndarray, block_size: int = 10) -> np.ndarray:
    """Apply mosaic (pixelated) blur to image."""
    h, w = image.shape[:2]
    # Ensure block_size is reasonable
    block_size = max(1, block_size)
    small_h, small_w = max(1, h // block_size), max(1, w // block_size)
    temp = cv2.resize(image, (small_w, small_h), interpolation=cv2.INTER_LINEAR)
    mosaic = cv2.resize(temp, (w, h), interpolation=cv2.INTER_NEAREST)
    return mosaic

def start_recording():
    """Start video recording with timestamp filename."""
    global video_writer
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = os.path.join(output_dir, f'recording_{timestamp}.mp4')
    fourcc = cv2.VideoWriter_fourcc(*'mp4v') # Use 'mp4v' or 'XVID'
    video_writer = cv2.VideoWriter(filename, fourcc, fps, (frame_width, frame_height))
    if video_writer.isOpened():
        print(f"✓ Recording started: {filename}")
        return True
    else:
        print(f"✗ Failed to start recording")
        video_writer = None
        return False

def stop_recording():
    """Stop video recording."""
    global video_writer
    if video_writer is not None:
        video_writer.release()
        video_writer = None
        print("✓ Recording stopped")


def send_frame_to_backend(img: np.ndarray):
    """Encode frame as JPEG base64 and POST to backend /upload_frame if BACKEND_URL is set."""
    backend_url = os.environ.get('BACKEND_URL')
    if not backend_url:
        return False
    try:
        _, buffer = cv2.imencode('.jpg', img, [int(cv2.IMWRITE_JPEG_QUALITY), 80])
        jpg_b64 = base64.b64encode(buffer).decode('ascii')
        payload = {'image': jpg_b64}
        resp = requests.post(f'{backend_url.rstrip('/')}/upload_frame', json=payload, timeout=2.0)
        return resp.ok
    except Exception as e:
        print(f"✗ Failed to send frame to backend: {e}")
        return False

# --- Main Loop ---
loop_count = 0
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

    # --- DNN Face Detection ---
    (h, w) = img.shape[:2] # Frame height and width
    # Create blob: Resize to 300x300, apply mean subtraction (values specific to this model)
    blob = cv2.dnn.blobFromImage(cv2.resize(img, (300, 300)), 1.0,
        (300, 300), (104.0, 177.0, 123.0))

    # Pass blob through network
    net.setInput(blob)
    detections = net.forward()

    face_found = False # Flag to check if any face was detected in this frame

    # Loop over the detections
    for i in range(0, detections.shape[2]):
        # Extract confidence
        confidence = detections[0, 0, i, 2]

        # Filter out weak detections
        if confidence > confidence_threshold:
            face_found = True
            # Compute coordinates of the bounding box
            box = detections[0, 0, i, 3:7] * np.array([w, h, w, h])
            (startX, startY, endX, endY) = box.astype("int")

            # Ensure bounding box is within frame boundaries
            startX = max(0, startX)
            startY = max(0, startY)
            endX = min(w, endX)
            endY = min(h, endY)

            # Extract face ROI
            face_roi = img[startY:endY, startX:endX]

            # Check if ROI is valid before blurring
            if face_roi.size > 0:
                # Apply blur if enabled
                if blur_enabled:
                    box_w = endX - startX # Width of the detected face box
                    if blur_type == 'gaussian':
                        # Use box width for kernel calculation
                        k_factor = 3
                        # Adjust kernel size calculation
                        k = _oddize(max(3, box_w // k_factor))
                        blurred = apply_gaussian_blur(face_roi, kernel_factor=k_factor) # Pass k_factor instead
                    elif blur_type == 'mosaic':
                        # Use box width for block size calculation
                        mosaic_block_size = max(3, box_w // 15)
                        blurred = apply_mosaic_blur(face_roi, block_size=mosaic_block_size)
                    else: # 'none' or unknown
                        blurred = face_roi # No blurring if type is 'none' or invalid

                    # Put blurred face back into the frame
                    img[startY:endY, startX:endX] = blurred

            # Optional: Draw bounding box (can comment out if not needed)
            # cv2.rectangle(img, (startX, startY), (endX, endY), (0, 255, 0), 2)

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

    # Show frame only when display is enabled. In headless mode we skip GUI and
    # keyboard handling so the script can run on servers or when OpenCV lacks GUI support.
    if display_enabled:
        try:
            cv2.imshow(WINDOW_NAME, img)
        except cv2.error as e:
            print(f"⚠️ Error displaying frame: {e}")
            display_enabled = False

        # Best-effort: send frame to backend so web clients can receive it via Socket.IO
        # Enable by setting environment variable: BACKEND_URL=http://localhost:5000
        try:
            if not args.no_upload:
                send_frame_to_backend(img)
        except Exception:
            pass

        # Handle keyboard input (non-blocking with timeout)
        key = cv2.waitKey(1) & 0xff
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
                if not start_recording(): # Check if recording actually started
                    recording = False # Revert state if failed
            else:
                stop_recording()
    else:
        # Headless mode: still send frames to backend, sleep shortly, and rely on Ctrl+C to stop
        try:
            if not args.no_upload:
                send_frame_to_backend(img)
        except Exception:
            pass
        try:
            time.sleep(0.01)
        except KeyboardInterrupt:
            break

# --- Cleanup ---
if recording:
    stop_recording()

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


print("✓ Application finished gracefully.")
