"""
MAYA Backend — External Media Router
Endpoints for saving and managing external media links.
"""
import logging
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.dependencies.auth import get_optional_user, get_current_user
from app.models.external_media import ExternalMedia
from app.models.user import User, UserRole
from app.schemas.link import ExternalMediaCreate, ExternalMediaResponse

router = APIRouter(prefix="/api/external", tags=["External Media"])
logger = logging.getLogger(__name__)


@router.get("", response_model=list[ExternalMediaResponse])
async def get_external_media(
    db: AsyncSession = Depends(get_db),
    current_user: User | None = Depends(get_optional_user),
):
    """
    List external media items.
    If authenticated, returns user's external media (plus unassigned media).
    If guest, returns all unassigned external media.
    """
    if current_user:
        stmt = (
            select(ExternalMedia)
            .where((ExternalMedia.user_id == current_user.id) | (ExternalMedia.user_id == None))
            .order_by(ExternalMedia.created_at.desc())
        )
    else:
        stmt = (
            select(ExternalMedia)
            .order_by(ExternalMedia.created_at.desc())
        )

    result = await db.execute(stmt)
    return result.scalars().all()


@router.post("", response_model=ExternalMediaResponse, status_code=status.HTTP_201_CREATED)
async def create_external_media(
    payload: ExternalMediaCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User | None = Depends(get_optional_user),
):
    """Save an external media link to MAYA library ("Add to MAYA")."""
    item = ExternalMedia(
        user_id=current_user.id if current_user else None,
        title=payload.title,
        thumbnail=payload.thumbnail,
        duration=payload.duration,
        source_url=payload.source_url,
        provider=payload.provider,
        stream_type=payload.stream_type,
        media_type=payload.media_type,
    )
    db.add(item)
    await db.flush()
    await db.refresh(item)
    return item


@router.delete("/{media_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_external_media(
    media_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User | None = Depends(get_optional_user),
):
    """Delete an external media entry."""
    result = await db.execute(select(ExternalMedia).where(ExternalMedia.id == media_id))
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="External media not found")

    # Only owner or admin can delete (or if guest created and item has no user_id)
    if item.user_id and current_user:
        if item.user_id != current_user.id and current_user.role != UserRole.ADMIN:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")

    await db.delete(item)
