# Sistem Pengaduan Publik — Satgas PPKS
Politeknik Negeri Lhokseumawe

[![Status](https://img.shields.io/badge/Status-Development-blue)](https://github.com)
[![Backend](https://img.shields.io/badge/Backend-Flask%20%2F%20OpenCV-orange)](backend/)
[![Frontend](https://img.shields.io/badge/Frontend-Flutter%20Web-blueviolet)](frontend/)

Deskripsi singkat:
Sistem ini memungkinkan pelaporan kejadian ke Satgas PPKS dengan perekaman video yang menjamin anonimitas pelapor melalui anonimisasi wajah (blur) secara realtime di sisi server. Aplikasi terdiri dari frontend Flutter Web untuk capture dan preview, serta backend Flask yang melakukan deteksi wajah dan menyimpan video yang sudah di-blur.

## Ringkasan Fitur
- Anonimisasi wajah realtime (server-side) menggunakan OpenCV DNN.
- Penyimpanan video yang sudah di-blur di server (raw video tidak disimpan).
- Preview aman untuk pelapor: tampilan stream yang sudah di-blur dikirim kembali ke klien.
- Dashboard terproteksi untuk admin Satgas PPKS (manajemen laporan & akses terautentikasi).

## Kontrak singkat (inputs / outputs / error modes)
- Input: video stream WebRTC/WebSocket dari browser klien.
- Output: file video yang sudah di-blur (di server) + stream preview yang sudah di-blur untuk klien.
- Error modes: kehilangan koneksi, kegagalan deteksi wajah, ruang disk penuh.

## Arsitektur singkat
- Frontend: Flutter Web — menangkap kamera, mengirim stream mentah, menampilkan preview yang di-blur.
- Backend: Flask + Flask-SocketIO — menerima stream, melakukan deteksi wajah & blur (OpenCV), menyimpan video hasil pemrosesan.
- Database: menyimpan metadata laporan (opsional: PostgreSQL/MySQL).
- Infrastuktur tipikal: Nginx sebagai reverse proxy / terminasi TLS.

## Prasyarat
- Python 3.9+
- Flutter SDK untuk target Web
- PostgreSQL atau database relasional (opsional)

## Cara menjalankan (dev)
Catatan: instruksi di bawah ini untuk lingkungan pengembangan. Periksa `backend/requirements.txt` dan `frontend/pubspec.yaml` untuk detail dependensi.

Backend (Linux / macOS / WSL):

```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
export FLASK_APP=app.py
flask run --host=0.0.0.0 --port=5000
```

Frontend (Flutter Web):

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

## Struktur proyek (ringkas)
- backend/: kode server (Flask, pemrosesan video, penyimpanan)
- database/: skema SQL dan skrip migrasi
- frontend/: aplikasi Flutter (Web)
- web/: aset web statis (jika ada)

## Pengembangan & kontribusi
1. Fork repository ini.
2. Buat branch fitur: git checkout -b feat/nama-fitur
3. Jalankan komponen yang diperlukan (backend/frontend).
4. Ajukan pull request dengan deskripsi perubahan dan langkah verifikasi.

Catatan keamanan:
- Pastikan server menjalankan TLS dan hanya menyimpan video yang telah di-anonimkan.
- Batasi akses ke file video melalui autentikasi dan aturan hak akses.

## Tim
- Muhammad Dhia Ulhaq — Program PCD
- Wildanul Hakim — Backend
- M. Akmal — Frontend
- Fauzi Syahril Harahap — UI/UX

## Lisensi
Lisensi proyek: (sebutkan lisensi yang relevan, mis. MIT) — tambahkan file `LICENSE` jika perlu.

---
Versi: diperbarui secara ringkas untuk presentasi dan penggunaan pengembangan.
