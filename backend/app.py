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

# Import fungsi blur dari modul PCD
from services.pcd_main import process_frame_base64

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

        # 🔹 Proses frame menggunakan modul PCD
        processed_b64 = process_frame_base64(img_b64)

        # 🔹 Broadcast hasil blur ke semua klien (event: 'processed_frame')
        socketio.emit('processed_frame', {'image': processed_b64})

        print("→ Frame processed and broadcast to clients.")
        return jsonify({'status': 'processed'}), 200

    except Exception as e:
        print('✗ Error in /upload_frame:', e)
        return jsonify({'error': str(e)}), 500


# --- Run Server ---
if __name__ == '__main__':
    print("🚀 Flask PCD backend running on http://0.0.0.0:5000")
    socketio.run(app, host='0.0.0.0', port=5000)
