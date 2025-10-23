import sys
import cv2
import numpy as np
from datetime import datetime
import os
import time

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

# --- Camera and Settings ---
capture = cv2.VideoCapture(0)

if not capture.isOpened():
    print("✗ Error: could not open video capture. Check your camera.")
    sys.exit(1)

# Get camera properties for video writer
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

# --- Helper Functions (Keep these as they are) ---
def _oddize(n: int) -> int:
    """Return an odd integer >= 3 based on n."""
    n = max(3, int(n))
    return n if (n % 2) == 1 else n + 1

def apply_gaussian_blur(image: np.ndarray, kernel_factor: int = 3) -> np.ndarray:
    """Apply Gaussian blur to image."""
    h, w = image.shape[:2]
    k = _oddize(max(3, min(h, w) // kernel_factor))
    # Add check for kernel size validity
    if k <= 0: return image # Return original if kernel is invalid
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

# --- Main Loop ---
while True:
    success, img = capture.read()
    if not success or img is None:
        print("Warning: failed to read frame from camera. Exiting.")
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

    cv2.imshow('Face Blur (DNN)', img)

    # Handle keyboard input (Keep this section as it is)
    key = cv2.waitKey(1) & 0xff
    if key == ord('q'):
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

# --- Cleanup ---
if recording:
    stop_recording()

capture.release()
cv2.destroyAllWindows()
print("✓ Application finished gracefully.")
