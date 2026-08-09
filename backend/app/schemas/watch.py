"""
MAYA Backend — Watch History & Favorites Pydantic Schemas
"""
from datetime import datetime
from pydantic import BaseModel


class WatchProgressUpdate(BaseModel):
    progress_seconds: int
    duration_seconds: int | None = None


class WatchHistoryResponse(BaseModel):
    id: int
    movie_id: int
    progress_seconds: int
    duration_seconds: int | None
    last_watched_at: datetime
    completed: bool
    model_config = {"from_attributes": True}


class FavoriteResponse(BaseModel):
    id: int
    movie_id: int
    created_at: datetime
    model_config = {"from_attributes": True}
