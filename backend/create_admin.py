"""
Script untuk membuat atau reset admin user dengan password yang di-hash dengan benar
Jalankan dengan: python create_admin.py
"""

from ppks_api.db import SessionLocal
from ppks_api.models import Admin
from ppks_api.security import hash_password

def create_or_update_admin(username: str, password: str):
    """Buat atau update admin user"""
    db = SessionLocal()
    try:
        # Cek apakah admin sudah ada
        admin = db.query(Admin).filter(Admin.username == username).first()
        
        if admin:
            # Update password yang sudah ada
            admin.password_hash = hash_password(password)
            db.commit()
            print(f"✓ Password admin '{username}' berhasil diupdate")
        else:
            # Buat admin baru
            new_admin = Admin(
                username=username,
                password_hash=hash_password(password)
            )
            db.add(new_admin)
            db.commit()
            print(f"✓ Admin '{username}' berhasil dibuat")
        
        print(f"\nKredensial login:")
        print(f"Username: {username}")
        print(f"Password: {password}")
        
    except Exception as e:
        print(f"✗ Error: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    print("=== Membuat Admin User ===\n")
    
    # Gunakan kredensial dari .env atau default
    username = input("Username [admin]: ").strip() or "admin"
    password = input("Password [admin123]: ").strip() or "admin123"
    
    create_or_update_admin(username, password)
