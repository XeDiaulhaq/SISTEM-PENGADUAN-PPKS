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
- MySQL 8.x (atau RDBMS lain yang kompatibel dengan SQLAlchemy).

### Setup Database (MySQL)
1. Salin `.env.example` menjadi `.env` dan sesuaikan `DATABASE_URL`, `REPORT_API_KEY`, dan variabel lainnya.
2. Buat database + tabel awal dengan skrip `database/mysql/schema.sql`:

	```bash
	mysql -u root -p < database/mysql/schema.sql
	```

3. Pastikan driver MySQL (`pymysql`) terinstal saat menjalankan `pip install -r backend/requirements.txt`.
4. Jalankan FastAPI (`uvicorn backend.fastapi.main:app --port 65514`) dan pastikan log menampilkan koneksi sukses ke database MySQL.

### Variabel lingkungan penting
- `BACKEND_URL`: alamat Flask blur backend yang menerima `/upload_frame`.
- `REPORT_API_URL`: endpoint FastAPI untuk mencatat metadata rekaman (mis. `http://localhost:65514/reports`).
- `REPORT_API_KEY`: token sederhana untuk mengamankan endpoint ingest.
- `REPORT_TITLE_PREFIX` & `REPORT_SUBMITTED_BY` (opsional): kustomisasi judul laporan dan identitas pengirim ketika `services/pcd_main.py` mengirim metadata.

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
- web/: aset web statis (jika ada).

## Pengembangan & kontribusi

### Cara Kontribusi (Fork & Pull Request)

Terima kasih atas minat Anda untuk berkontribusi! Di bawah ini adalah alur kontribusi menggunakan fork dan pull request (PR) — cocok untuk kontributor eksternal.

Langkah singkat:

1. Fork repository ini melalui GitHub (klik tombol "Fork" di pojok kanan atas halaman repository).
2. Clone fork ke mesin lokal Anda:

	```bash
	git clone https://github.com/<username>/SISTEM-PENGADUAN-PPKS.git
	cd SISTEM-PENGADUAN-PPKS
	```

3. Tambahkan remote upstream untuk mengikuti repositori utama:

	```bash
	git remote add upstream https://github.com/XeDiaulhaq/SISTEM-PENGADUAN-PPKS.git
	git fetch upstream
	```

4. Buat branch baru untuk fitur atau perbaikan Anda (jangan bekerja langsung di `main`/`master`):

	```bash
	git checkout -b feat/nama-fitur-atau-fix
	```

5. Lakukan perubahan, jalankan pengecekan lokal (jalankan backend/frontend sesuai kebutuhan), lalu commit perubahan Anda:

	```bash
	git add .
	git commit -m "Deskripsi singkat: tambahkan fitur X atau perbaiki Y"
	```

6. Sebelum mengirimkan, sinkronkan branch `main` lokal Anda dengan upstream untuk menghindari konflik:

	```bash
	git checkout main
	git fetch upstream
	git merge upstream/main
	git checkout feat/nama-fitur-atau-fix
	git rebase main   # atau git merge main jika lebih nyaman
	```

7. Push branch Anda ke fork (origin):

	```bash
	git push origin feat/nama-fitur-atau-fix
	```

8. Buka Pull Request (PR) di GitHub: pilih branch pada fork Anda dan arahkan ke `XeDiaulhaq/SISTEM-PENGADUAN-PPKS:main` (atau cabang target lain yang ditentukan). Isi deskripsi PR dengan ringkasan perubahan, alasan, dan langkah verifikasi.

9. Tanggapi review jika maintainer meminta perubahan. Lakukan commit tambahan pada branch yang sama lalu push — PR akan terupdate otomatis.

10. Jika main upstream bergerak jauh dan Anda perlu memperbarui branch PR:

	 ```bash
	 git fetch upstream
	 git rebase upstream/main
	 git push --force-with-lease origin feat/nama-fitur-atau-fix
	 ```

Tips & konvensi:
- Gunakan pesan commit yang jelas dan ringkas.
- Pisahkan perubahan besar menjadi beberapa PR kecil bila memungkinkan.
- Jalankan dan sertakan langkah verifikasi yang jelas di deskripsi PR (bagaimana reviewer bisa mengetes perubahan).
- Ikuti gaya kode yang ada (lihat file yang relevan) dan jangan sertakan kredensial atau data sensitif.

Jika ada pertanyaan tentang alur kontribusi atau Anda ingin kontribusi besar (fitur arsitektur), silakan buka issue terlebih dahulu untuk mendiskusikannya.

---

Langkah pengembangan singkat (untuk kolaborator yang sudah memiliki akses):
1. Buat branch fitur: `git checkout -b feat/nama-fitur`
2. Jalankan komponen yang diperlukan (backend/frontend).
3. Ajukan pull request dengan deskripsi perubahan dan langkah verifikasi.

Catatan keamanan:
- Pastikan server menjalankan TLS dan hanya menyimpan video yang telah di-anonimkan.
- Batasi akses ke file video melalui autentikasi dan aturan hak akses.

## Tim
- Muhammad Dhia Ulhaq — Program PCD.
- Wildanul Hakim — Backend.
- M. Akmal — Frontend.
- Fauzi Syahril Harahap — UI/UX.

## Lisensi
Lisensi proyek: (sebutkan lisensi yang relevan, mis. MIT) — tambahkan file `LICENSE` jika perlu.

---
Versi: diperbarui secara ringkas untuk presentasi dan penggunaan pengembangan.
