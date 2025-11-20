from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field

from .models import ReportStatus


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


class ReportBase(BaseModel):
    title: str
    recording_path: str
    thumbnail_path: Optional[str] = None
    status: ReportStatus = ReportStatus.NEW
    duration_seconds: Optional[int] = Field(default=None, ge=0)
    submitted_by: Optional[str] = None
    notes: Optional[str] = None
    captured_at: Optional[datetime] = None


class ReportCreate(ReportBase):
    status: Optional[ReportStatus] = None
    title: str = Field(..., min_length=3)


class ReportUpdate(BaseModel):
    title: Optional[str] = Field(default=None, min_length=3)
    thumbnail_path: Optional[str] = None
    status: Optional[ReportStatus] = None
    duration_seconds: Optional[int] = Field(default=None, ge=0)
    submitted_by: Optional[str] = None
    notes: Optional[str] = None


class ReportOut(ReportBase):
    id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
