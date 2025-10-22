"""Minimal starter Flask app with SocketIO and OpenCV placeholders.
This file is a safe starting point and does not perform real streaming.
"""
from flask import Flask, send_from_directory, jsonify
from flask_socketio import SocketIO
import os

app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret')
socketio = SocketIO(app, cors_allowed_origins='*')


@app.route('/')
def index():
    return jsonify({'status': 'backend running'})


if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=5000)
