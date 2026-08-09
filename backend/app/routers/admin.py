"""
MAYA Backend — Admin Router
Dashboard statistics and user management. Admin-only.
"""
from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.dependencies.auth import require_admin
from app.models.favorite import Favorite
from app.models.movie import Movie
from app.models.user import User, UserRole
from app.models.watch_history import WatchHistory
from app.schemas.auth import UserResponse
from pydantic import BaseModel

router = APIRouter(prefix="/api/admin", tags=["Admin"])


class DashboardStats(BaseModel):
    total_movies: int
    total_users: int
    total_watch_sessions: int
    total_favorites: int
    total_watch_seconds: int
    active_movies: int


@router.get("/stats", response_model=DashboardStats)
async def get_stats(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Admin dashboard statistics."""
    total_movies = (await db.execute(select(func.count()).select_from(Movie))).scalar_one()
    active_movies = (await db.execute(select(func.count()).select_from(Movie).where(Movie.is_active == True))).scalar_one()
    total_users = (await db.execute(select(func.count()).select_from(User).where(User.role == UserRole.USER))).scalar_one()
    total_watch_sessions = (await db.execute(select(func.count()).select_from(WatchHistory))).scalar_one()
    total_favorites = (await db.execute(select(func.count()).select_from(Favorite))).scalar_one()
    total_watch_seconds_result = (await db.execute(select(func.sum(WatchHistory.progress_seconds)))).scalar_one()
    total_watch_seconds = total_watch_seconds_result or 0

    return DashboardStats(
        total_movies=total_movies,
        total_users=total_users,
        total_watch_sessions=total_watch_sessions,
        total_favorites=total_favorites,
        total_watch_seconds=total_watch_seconds,
        active_movies=active_movies,
    )


@router.get("/users", response_model=list[UserResponse])
async def list_users(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_admin),
):
    result = await db.execute(select(User).order_by(User.created_at.desc()))
    return result.scalars().all()


@router.put("/users/{user_id}/toggle-active", response_model=UserResponse)
async def toggle_user_active(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Enable or disable a user account. Cannot disable yourself."""
    from fastapi import HTTPException, status
    if user_id == admin.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot disable your own account")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    user.is_active = not user.is_active
    await db.flush()
    await db.refresh(user)
    return user
