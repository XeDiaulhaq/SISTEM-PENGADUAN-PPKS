import os
from dotenv import load_dotenv


load_dotenv()


class Settings:
    # JWT
    JWT_SECRET: str = os.getenv("JWT_SECRET", "change-this-secret")
    JWT_ALGORITHM: str = os.getenv("JWT_ALGORITHM", "HS256")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "60"))

    # Database
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./fastapi.db")

    # Seed admin (opsional)
    ADMIN_SEED_USERNAME: str | None = os.getenv("ADMIN_SEED_USERNAME")
    ADMIN_SEED_PASSWORD: str | None = os.getenv("ADMIN_SEED_PASSWORD")

    # Report ingest API (digunakan oleh services/pcd_main.py)
    REPORT_API_KEY: str | None = os.getenv("REPORT_API_KEY")


settings = Settings()
