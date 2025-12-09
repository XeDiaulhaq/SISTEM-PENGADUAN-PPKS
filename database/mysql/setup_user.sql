-- Setup MySQL User untuk PPKS
-- Jalankan dengan: mysql -u root -p < database\mysql\setup_user.sql

-- Hapus user lama jika ada (opsional)
DROP USER IF EXISTS 'ppks_user'@'localhost';

-- Buat user baru
CREATE USER 'ppks_user'@'localhost' IDENTIFIED BY 'strong_password';

-- Buat database jika belum ada
CREATE DATABASE IF NOT EXISTS ppks CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Berikan hak akses penuh ke database ppks
GRANT ALL PRIVILEGES ON ppks.* TO 'ppks_user'@'localhost';

-- Refresh privileges
FLUSH PRIVILEGES;

-- Tampilkan user yang sudah dibuat
SELECT user, host FROM mysql.user WHERE user='ppks_user';

-- Tampilkan privileges user
SHOW GRANTS FOR 'ppks_user'@'localhost';
