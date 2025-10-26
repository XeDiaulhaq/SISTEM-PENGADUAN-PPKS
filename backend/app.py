"""
Flask Backend for PCD (Face Anonymization)
------------------------------------------
Handles:
 - Receiving frames (base64) from external PCD process (pcd_main.py)
 - Processing frames (face blur) via services.pcd_main
 - Broadcasting processed frames to connected clients via Socket.IO
 - Serving Flutter Web frontend (if built)
"""

from flask import Flask, send_from_directory, jsonify, request
from flask_socketio import SocketIO
import os
import subprocess
import sys

# Import modul pcd sebagai modul, jangan import fungsi yang memicu eksekusi loop pada import
from services import pcd_main

# --- Flask App Config ---
app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret')
socketio = SocketIO(app, cors_allowed_origins='*')


# --- SocketIO Events ---
@socketio.on('connect')
def handle_connect():
    print('✓ SocketIO client connected')


@socketio.on('disconnect')
def handle_disconnect():
    print('✓ SocketIO client disconnected')


# --- Serve Frontend (Flutter Web) ---
@app.route('/')
def index():
    """
    Serve built Flutter web (if available) or return JSON status.
    """
    build_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'frontend', 'build', 'web'))
    index_file = os.path.join(build_dir, 'index.html')
    if os.path.exists(index_file):
        return send_from_directory(build_dir, 'index.html')

    return jsonify({'status': 'backend running'})


@app.route('/<path:filename>')
def static_files(filename: str):
    """
    Serve static files from frontend/build/web when available.
    """
    build_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'frontend', 'build', 'web'))
    file_path = os.path.join(build_dir, filename)
    if os.path.exists(file_path):
        return send_from_directory(build_dir, filename)
    return jsonify({'error': 'file not found'}), 404


# --- Receive Frame API ---
@app.route('/upload_frame', methods=['POST'])
def upload_frame():
    """
    Receive a base64-encoded image (JSON {"image":"..."}) → process with PCD → broadcast via Socket.IO.
    This allows pcd_main.py or other clients to POST frames to the backend.
    """
    try:
        data = request.get_json(force=True)
        if not data or 'image' not in data:
            return jsonify({'error': 'missing image field'}), 400

        img_b64 = data['image']

        # 🔹 Proses frame menggunakan modul PCD (modul pcd_main)
        processed_b64 = pcd_main.process_frame_base64(img_b64)

        # 🔹 Broadcast hasil blur ke semua klien (event name 'frame' expected by frontend)
        socketio.emit('frame', {'image': processed_b64})

        print("→ Frame processed and broadcast to clients.")
        return jsonify({'status': 'processed'}), 200

    except Exception as e:
        print('✗ Error in /upload_frame:', e)
        return jsonify({'error': str(e)}), 500


# --- Run Server ---
def _start_pcd_subprocess():
    """Start pcd_main.py as a separate subprocess.

    This keeps camera/OpenCV work in a separate process and avoids blocking the Flask server.
    Returns the subprocess.Popen object or None on failure.
    """
    script_path = os.path.abspath(os.path.join(os.path.dirname(__file__), 'services', 'pcd_main.py'))
    if not os.path.exists(script_path):
        print(f"✗ pcd script not found: {script_path}")
        return None

    env = os.environ.copy()
    # Ensure pcd uploads frames to this backend
    env.setdefault('BACKEND_URL', 'http://127.0.0.1:5000')
    # Inherit NO_DISPLAY from the parent environment; default to '0' so GUI shows
    env['NO_DISPLAY'] = os.environ.get('NO_DISPLAY', '0')
    print(f"Starting pcd subprocess with NO_DISPLAY={env['NO_DISPLAY']}")

    try:
        proc = subprocess.Popen([sys.executable, script_path], env=env, cwd=os.path.dirname(__file__))
        print(f"✓ Started pcd subprocess (pid={proc.pid})")
        return proc
    except Exception as e:
        print('✗ Failed to start pcd subprocess:', e)
        return None


if __name__ == '__main__':
    print("🚀 Flask PCD backend running on http://0.0.0.0:5000")
    # Start PCD in a separate process so it runs alongside the server
    pcd_proc = _start_pcd_subprocess()
    try:
        socketio.run(app, host='0.0.0.0', port=5000)
    finally:
        # Try to gracefully terminate the pcd subprocess when server stops
        try:
            if pcd_proc is not None:
                print('Shutting down pcd subprocess...')
                pcd_proc.terminate()
        except Exception:
            pass
