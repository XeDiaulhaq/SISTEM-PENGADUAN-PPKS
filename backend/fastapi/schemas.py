from pydantic import BaseModel
from datetime import datetime


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int


class AdminOut(BaseModel):
    id: int
    username: str
    created_at: datetime | None = None

    class Config:
        from_attributes = True
