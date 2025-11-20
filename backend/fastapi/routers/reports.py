from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import APIKeyHeader
from sqlalchemy.orm import Session

from ..config import settings
from ..db import get_db
from ..models import Report, ReportStatus
from ..schemas import ReportCreate, ReportOut, ReportUpdate
from .auth import get_current_admin

router = APIRouter(prefix="/reports", tags=["reports"])

_api_key_header = APIKeyHeader(name="X-Report-Api-Key", auto_error=False)


def _verify_report_api_key(api_key: Optional[str] = Depends(_api_key_header)) -> None:
    expected = settings.REPORT_API_KEY
    if expected is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Report ingest API key is not configured",
        )
    if not api_key or api_key != expected:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid report API key")


@router.post("", response_model=ReportOut, status_code=status.HTTP_201_CREATED)
def ingest_report(
    payload: ReportCreate,
    _: None = Depends(_verify_report_api_key),
    db: Session = Depends(get_db),
):
    status_value = (payload.status or ReportStatus.NEW).value
    report = Report(
        title=payload.title,
        recording_path=payload.recording_path,
        thumbnail_path=payload.thumbnail_path,
        status=status_value,
        duration_seconds=payload.duration_seconds,
        submitted_by=payload.submitted_by,
        notes=payload.notes,
        captured_at=payload.captured_at,
    )
    db.add(report)
    db.commit()
    db.refresh(report)
    return report


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
