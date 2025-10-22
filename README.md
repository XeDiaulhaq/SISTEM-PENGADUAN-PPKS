# Sistem Pengaduan Publik Satgas PPKS
### Politeknik Negeri Lhokseumawe

![Status](https://img.shields.io/badge/Status-Development-blue)
![Tech-Backend](https://img.shields.io/badge/Backend-Flask%20%2F%20OpenCV-orange)
![Tech-Frontend](https://img.shields.io/badge/Frontend-Flutter%20Web-blueviolet)

[cite_start]Proyek ini adalah implementasi dari "Bilik Interogasi Digital" yang dirancang untuk Satgas PPKS Politeknik Negeri Lhokseumawe[cite: 3, 11].

## 📝 Latar Belakang Masalah
[cite_start]Sistem ini dirancang untuk memecahkan masalah krusial: Satgas PPKS membutuhkan bukti visual (video) untuk sebuah laporan, namun pelapor seringkali mengkhawatirkan eksposur identitas mereka[cite: 13]. [cite_start]Solusinya adalah sistem perekaman *realtime* yang menjamin **anonimitas visual sejak detik pertama perekaman**[cite: 14].

## ✨ Fitur Utama
* [cite_start]**Anonimisasi Realtime:** Server mendeteksi wajah (menggunakan OpenCV DNN) dan menerapkan efek *blur* secara otomatis pada *stream* video *live*[cite: 22, 23].
* **Perekaman Sisi Server:** Fungsionalitas inti sistem. [cite_start]*Stream* video yang **sudah diburamkan** disimpan langsung ke server sebagai file video[cite: 25].
* [cite_start]**Jaminan Privasi:** Data video mentah (wajah asli pelapor) **tidak pernah** disimpan di server[cite: 31].
* [cite_start]**Umpan Balik (Preview) Aman:** Pelapor dapat melihat *preview* video mereka yang sudah di-*blur* secara *realtime* untuk memberikan rasa aman[cite: 24].
* [cite_start]**Dashboard Admin:** Antarmuka terproteksi (via *login*) bagi Satgas PPKS untuk mengakses dan meninjau arsip laporan video[cite: 27].

## 🏛️ Arsitektur Sistem
[cite_start]Sistem ini mengadopsi arsitektur **Client-Server (Realtime)**[cite: 41].

* [cite_start]**Frontend (Klien): Flutter Web** [cite: 42, 79]
    * Bertugas menangkap video dari *webcam* klien.
    * Mengirim *stream* video mentah ke server.
    * Menerima dan menampilkan kembali *stream* yang sudah di-*blur* dari server sebagai *preview*.

* [cite_start]**Backend (Server): Flask (Python)** [cite: 43, 74]
    * [cite_start]Menerima *stream* mentah dari klien (via WebSocket/SocketIO)[cite: 75].
    * [cite_start]Memproses *stream* (deteksi wajah & *blur*) menggunakan OpenCV[cite: 43, 76].
    * [cite_start]Menyimpan *stream* yang sudah di-*blur* ke *disk* server[cite: 25].
    * Mengirimkan *stream* yang sudah di-*blur* kembali ke klien untuk *preview*.

## 🛠️ Tumpukan Teknologi (Tech Stack)

| Kategori | Teknologi | Tujuan |
| :--- | :--- | :--- |
| **Backend** | [cite_start]Python [cite: 73] | Bahasa pemrograman utama |
| | [cite_start]Flask [cite: 74] | Framework web |
| | [cite_start]Flask-SocketIO [cite: 75] | Mengelola koneksi WebSocket *realtime* |
| | [cite_start]OpenCV (DNN) [cite: 76] | Deteksi wajah dan pemrosesan gambar |
| | [cite_start]NumPy [cite: 77] | Manipulasi array gambar |
| **Frontend** | [cite_start]Flutter (Web) [cite: 79] | UI/UX dan logika sisi klien |
| | [cite_start]Dart / JavaScript [cite: 80] | Mengakses Web API (kamera) & koneksi WebSocket |
| **Database** | [cite_start]PostgreSQL / MySQL [cite: 82] | Menyimpan metadata laporan & akun admin |
| **Infrastruktur**| [cite_start]Nginx [cite: 83] | *Reverse proxy* dan peladen WebSocket |

## 🚀 Instalasi & Menjalankan

*(Instruksi akan ditambahkan di sini)*

### Prasyarat
- Python 3.9+
- Flutter SDK (Channel Web)
- PostgreSQL (atau server database lain)

### Backend
```bash
# Pindah ke direktori backend
cd backend

# Buat virtual environment
python -m venv venv
source venv/bin/activate  # (atau venv\Scripts\activate di Windows)

# Install dependencies
pip install -r requirements.txt

# Jalankan server
flask run
```

### Frontend

```bash
# Pindah ke direktori frontend
cd frontend

# Install dependencies
flutter pub get

# Jalankan aplikasi di browser Chrome
flutter run -d chrome
```

## 👥 Tim Pengembang

  * [cite\_start]**Muhammad Dhia Ulhaq** (Program PCD) [cite: 6]
  * [cite\_start]**Wildanul Hakim** (Backend) [cite: 7]
  * **M. [cite\_start]Akmal** (Frontend) [cite: 8]
  * [cite\_start]**Fauzi Syahril Harahap** (UI/UX) [cite: 9]

<!-- end list -->
