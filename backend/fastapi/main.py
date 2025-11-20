from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from .db import engine, Base, SessionLocal
from .models import Admin
from .routers import auth as auth_router
from .routers import reports as reports_router
from .config import settings
from .security import hash_password


def create_app() -> FastAPI:
    app = FastAPI(title="PPKS Admin API", version="0.1.0")

    # CORS: izinkan akses dari frontend saat pengembangan (Flutter web / dev server)
    # Catatan: allow_credentials=False agar wildcard origins (*) valid
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Buat tabel jika belum ada
    Base.metadata.create_all(bind=engine)

    # Registrasi router
    app.include_router(auth_router.router)
    app.include_router(reports_router.router)

    @app.get("/")
    def root():
        return {"status": "ok", "service": "fastapi", "version": "0.1.0"}

    return app


app = create_app()


def seed_admin_if_needed():
    """Opsional: seed admin dari env jika belum ada."""
    if not settings.ADMIN_SEED_USERNAME or not settings.ADMIN_SEED_PASSWORD:
        return
    db: Session = SessionLocal()
    try:
        exists = db.query(Admin).filter(Admin.username == settings.ADMIN_SEED_USERNAME).first()
        if not exists:
            admin = Admin(username=settings.ADMIN_SEED_USERNAME, password_hash=hash_password(settings.ADMIN_SEED_PASSWORD))
            db.add(admin)
            db.commit()
            print(f"✓ Admin seeded: {settings.ADMIN_SEED_USERNAME}")
    finally:
        db.close()


# Jalankan seeding ringan saat modul diimpor (tidak fatal bila gagal)
try:
    seed_admin_if_needed()
except Exception as _:
    pass
