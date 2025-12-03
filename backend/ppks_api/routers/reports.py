from datetime import datetime
import os
from pathlib import Path
import shutil
from typing import List, Optional
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from fastapi.security import APIKeyHeader
from sqlalchemy.orm import Session

from ..config import settings
from ..db import get_db
from ..models import Report, ReportStatus
from ..schemas import ReportCreate, ReportOut, ReportUpdate
from services.video_blur import BlurVideoError, blur_video_file
from .auth import get_current_admin

router = APIRouter(prefix="/reports", tags=["reports"])

_api_key_header = APIKeyHeader(name="X-Report-Api-Key", auto_error=False)
_BACKEND_ROOT = Path(__file__).resolve().parents[1]
_DEFAULT_STORAGE_DIR = _BACKEND_ROOT / "recordings" / "uploads"
_DEFAULT_STORAGE_DIR.mkdir(parents=True, exist_ok=True)


def _verify_report_api_key(api_key: Optional[str] = Depends(_api_key_header)) -> None:
    expected = settings.REPORT_API_KEY
    if expected is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Report ingest API key is not configured",
        )
    if not api_key or api_key != expected:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid report API key")


def _create_report(payload: ReportCreate, db: Session) -> Report:
    status_value = (payload.status or ReportStatus.NEW).value
    report = Report(
        title=payload.title,
        location=payload.location,
        recording_path=payload.recording_path,
        thumbnail_path=payload.thumbnail_path,
        status=status_value,
        duration_seconds=payload.duration_seconds,
        submitted_by=payload.submitted_by,
        reporter_phone=payload.reporter_phone,
        notes=payload.notes,
        captured_at=payload.captured_at,
    )
    db.add(report)
    db.commit()
    db.refresh(report)
    return report


def _get_storage_dir() -> Path:
    override = os.getenv("REPORT_STORAGE_DIR")
    if override:
        target = Path(override)
    else:
        target = _DEFAULT_STORAGE_DIR
    target.mkdir(parents=True, exist_ok=True)
    return target


def _persist_recording(upload: UploadFile) -> Path:
    storage_dir = _get_storage_dir()
    original_name = Path(upload.filename or "recording.mp4")
    suffix = original_name.suffix or ".mp4"
    target = storage_dir / f"report_{uuid4().hex}{suffix}"
    with target.open("wb") as dest:
        upload.file.seek(0)
        shutil.copyfileobj(upload.file, dest)
    try:
        return blur_video_file(target)
    except BlurVideoError as exc:
        print(f"⚠️  Video blur skipped: {exc}")
    except Exception as exc:  # pragma: no cover - defensive logging
        print(f"⚠️  Unexpected error while blurring video: {exc}")
    return target


@router.post("", response_model=ReportOut, status_code=status.HTTP_201_CREATED)
def ingest_report(
    payload: ReportCreate,
    _: None = Depends(_verify_report_api_key),
    db: Session = Depends(get_db),
):
    return _create_report(payload, db)


@router.post("/upload", response_model=ReportOut, status_code=status.HTTP_201_CREATED)
async def upload_report(
    recording: UploadFile = File(...),
    title: str = Form(...),
    location: str = Form(...),
    description: str = Form(...),
    email: str = Form(...),
    reporter_phone: str = Form(...),
    blur_type: Optional[str] = Form(default=None),
    captured_at: Optional[str] = Form(default=None),
    _: None = Depends(_verify_report_api_key),
    db: Session = Depends(get_db),
):
    saved_path = _persist_recording(recording)
    try:
        relative_path = saved_path.relative_to(_BACKEND_ROOT)
    except ValueError:
        relative_path = saved_path

    captured_at_dt: Optional[datetime] = None
    if captured_at:
        try:
            captured_at_dt = datetime.fromisoformat(captured_at)
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="captured_at harus berformat ISO 8601",
            ) from exc

    notes = description
    if blur_type:
        notes = f"{description}\nBlur: {blur_type}"

    payload = ReportCreate(
        title=title,
        location=location,
        recording_path=str(relative_path).replace("\\", "/"),
        thumbnail_path=None,
        status=ReportStatus.NEW,
        duration_seconds=None,
        submitted_by=email,
        reporter_phone=reporter_phone,
        notes=notes,
        captured_at=captured_at_dt,
    )
    return _create_report(payload, db)


@router.get("", response_model=List[ReportOut])
def list_reports(
    status_filter: Optional[ReportStatus] = None,
    limit: int = 100,
    offset: int = 0,
    db: Session = Depends(get_db),
    _: None = Depends(get_current_admin),
):
    query = db.query(Report).order_by(Report.created_at.desc())
    if status_filter is not None:
        query = query.filter(Report.status == status_filter.value)
    reports = query.offset(max(0, offset)).limit(max(1, min(limit, 200))).all()
    return reports


@router.get("/{report_id}", response_model=ReportOut)
def get_report(
    report_id: int,
    db: Session = Depends(get_db),
    _: None = Depends(get_current_admin),
):
    report = db.get(Report, report_id)
    if report is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Report not found")
    return report


@router.patch("/{report_id}", response_model=ReportOut)
def update_report(
    report_id: int,
    update: ReportUpdate,
    db: Session = Depends(get_db),
    _: None = Depends(get_current_admin),
):
    report = db.get(Report, report_id)
    if report is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Report not found")

    update_data = update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        if field == "status" and value is not None:
            setattr(report, field, value.value)
        else:
            setattr(report, field, value)

    db.commit()
    db.refresh(report)
    return report
