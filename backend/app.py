"""Minimal starter Flask app with SocketIO and OpenCV placeholders.
This file is a safe starting point and does not perform real streaming.
"""
from flask import Flask, send_from_directory, jsonify, request
from flask_socketio import SocketIO
import os

app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret')
socketio = SocketIO(app, cors_allowed_origins='*')


@socketio.on('connect')
def handle_connect():
    print('✓ SocketIO client connected')


@socketio.on('disconnect')
def handle_disconnect():
    print('✓ SocketIO client disconnected')


@app.route('/')
def index():
    # If a built Flutter web exists, serve it so backend can host the frontend
    build_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'frontend', 'build', 'web'))
    index_file = os.path.join(build_dir, 'index.html')
    if os.path.exists(index_file):
        return send_from_directory(build_dir, 'index.html')

    return jsonify({'status': 'backend running'})


@app.route('/<path:filename>')
def static_files(filename: str):
    """Serve static files from frontend/build/web when available."""
    build_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'frontend', 'build', 'web'))
    file_path = os.path.join(build_dir, filename)
    if os.path.exists(file_path):
        return send_from_directory(build_dir, filename)
    # Fallback: file not found
    return jsonify({'error': 'file not found'}), 404



@app.route('/upload_frame', methods=['POST'])
def upload_frame():
    """Receive a base64-encoded image (JSON {"image":"..."}) and emit to connected clients.
    This allows an external process (pcd-main.py) to POST frames to the server, which will
    then broadcast them over Socket.IO under the event name 'frame'.
    """
    data = None
    try:
        data = request.get_json(force=True)
    except Exception:
        return jsonify({'error': 'invalid json body'}), 400

    if not data or 'image' not in data:
        return jsonify({'error': 'missing image field'}), 400

    img_b64 = data['image']
    # Broadcast to all connected clients
    print('→ Received /upload_frame, broadcasting frame to clients (sample length:', len(img_b64[:1]), '...)')
    try:
        socketio.emit('frame', {'image': img_b64})
    except Exception as e:
        print('✗ Error emitting frame:', e)
    return jsonify({'status': 'ok'}), 200


if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=5000)
