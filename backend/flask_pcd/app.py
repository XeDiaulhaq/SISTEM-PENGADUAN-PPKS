"""
Flask Backend for PCD (Face Anonymization)
------------------------------------------
Dipisahkan ke folder khusus `backend/flask_pcd` agar tidak bercampur dengan layanan FastAPI.

Handles:
 - Menerima frame (base64) dari proses PCD eksternal (services/pcd_main.py)
 - Memproses frame (face blur) via services.pcd_main
 - Broadcast ke klien via Socket.IO
 - Menyajikan Flutter Web (jika build tersedia)
"""

from flask import Flask, send_from_directory, jsonify, request
from flask_socketio import SocketIO
import os
import subprocess
import sys

# Import modul pcd sebagai modul, jangan import fungsi yang memicu eksekusi loop pada import
# Pastikan modul services dapat ditemukan saat menjalankan file ini langsung
CURRENT_DIR = os.path.dirname(__file__)
BACKEND_ROOT = os.path.abspath(os.path.join(CURRENT_DIR, '..'))
if BACKEND_ROOT not in sys.path:
    sys.path.insert(0, BACKEND_ROOT)

from services import pcd_main  # type: ignore

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
    Sajikan Flutter web build (jika ada) atau kembalikan status JSON.
    """
    build_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'frontend', 'build', 'web'))
    index_file = os.path.join(build_dir, 'index.html')
    if os.path.exists(index_file):
        return send_from_directory(build_dir, 'index.html')

    return jsonify({'status': 'flask pcd backend running'})


@app.route('/<path:filename>')
def static_files(filename: str):
    """
    Sajikan file statis dari frontend/build/web jika tersedia.
    """
    build_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'frontend', 'build', 'web'))
    file_path = os.path.join(build_dir, filename)
    if os.path.exists(file_path):
        return send_from_directory(build_dir, filename)
    return jsonify({'error': 'file not found'}), 404


# --- Receive Frame API ---
@app.route('/upload_frame', methods=['POST'])
def upload_frame():
    """
    Terima image base64 (JSON {"image":"..."}) → (opsional) proses via PCD → broadcast via Socket.IO
    """
    try:
        data = request.get_json(force=True)
        if not data or 'image' not in data:
            return jsonify({'error': 'missing image field'}), 400

        img_b64 = data['image']

        # Untuk mengurangi latency, default: JANGAN proses ulang di sini
        # Set REPROCESS_FRAMES=1 jika ingin memproses di Flask juga (double pass)
        reprocess = os.environ.get('REPROCESS_FRAMES', '0') in ('1', 'true', 'True')
        if reprocess:
            try:
                img_b64 = pcd_main.process_frame_base64(img_b64)
            except Exception as _:
                # Jika gagal memproses, fallback kirim as-is
                pass

        # Broadcast ke semua klien
        # Catatan: python-socketio/flask-socketio tidak menerima argumen 'compress' di emit()
        # Kompresi sudah ditangani oleh JPEG; hapus argumen khusus untuk menghindari error.
        socketio.emit('frame', {'image': img_b64})

        print("→ Frame processed and broadcast to clients.")
        return jsonify({'status': 'processed'}), 200

    except Exception as e:
        print('✗ Error in /upload_frame:', e)
        return jsonify({'error': str(e)}), 500


# --- Run Server ---
def _start_pcd_subprocess():
    """Menjalankan services/pcd_main.py sebagai subprocess.
    """
    script_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'services', 'pcd_main.py'))
    if not os.path.exists(script_path):
        print(f"✗ pcd script not found: {script_path}")
        return None

    env = os.environ.copy()
    env.setdefault('BACKEND_URL', 'http://127.0.0.1:5001')  # port default untuk Flask PCD terpisah
    env['NO_DISPLAY'] = os.environ.get('NO_DISPLAY', '0')
    print(f"Starting pcd subprocess with NO_DISPLAY={env['NO_DISPLAY']}")

    try:
        # Jalankan dari root backend agar path relatif 'models/...' tetap valid untuk pcd_main.py
        proc = subprocess.Popen([sys.executable, script_path], env=env, cwd=BACKEND_ROOT)
        print(f"✓ Started pcd subprocess (pid={proc.pid})")
        return proc
    except Exception as e:
        print('✗ Failed to start pcd subprocess:', e)
        return None


if __name__ == '__main__':
    print("🚀 Flask PCD backend running on http://0.0.0.0:5001")
    pcd_proc = _start_pcd_subprocess()
    try:
        socketio.run(app, host='0.0.0.0', port=5001)
    finally:
        try:
            if pcd_proc is not None:
                print('Shutting down pcd subprocess...')
                pcd_proc.terminate()
        except Exception:
            pass
