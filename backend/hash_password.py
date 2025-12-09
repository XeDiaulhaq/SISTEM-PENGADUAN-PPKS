"""
Script sederhana untuk generate password hash yang kompatibel dengan bcrypt
Jalankan dengan: python hash_password.py
"""

import bcrypt

def hash_password_simple(password: str) -> str:
    """Hash password menggunakan bcrypt secara langsung"""
    # Encode password ke bytes
    password_bytes = password.encode('utf-8')
    # Generate salt dan hash
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password_bytes, salt)
    # Return sebagai string
    return hashed.decode('utf-8')

if __name__ == "__main__":
    print("=== Generate Password Hash ===\n")
    
    password = input("Masukkan password [admin123]: ").strip() or "admin123"
    
    try:
        hashed = hash_password_simple(password)
        print(f"\n✓ Password berhasil di-hash!")
        print(f"\nPassword: {password}")
        print(f"Hash: {hashed}")
        print("\n--- SQL Query untuk Insert Admin ---")
        print(f"DELETE FROM admins WHERE username='admin';")
        print(f"INSERT INTO admins (username, password_hash) VALUES ('admin', '{hashed}');")
        print("\nCopy SQL di atas dan jalankan di phpMyAdmin tab SQL")
    except Exception as e:
        print(f"✗ Error: {e}")
