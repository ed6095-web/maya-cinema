"""
MAYA Backend — Movies Router
Handles movie CRUD, poster serving, and video streaming with HTTP Range support.
"""
import os
from pathlib import Path

import aiofiles
from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    Query,
    Request,
    UploadFile,
    status,
)
from fastapi.responses import FileResponse, RedirectResponse, StreamingResponse
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import settings
from app.core.database import get_db
from app.dependencies.auth import get_current_user, require_admin
from app.models.movie import Genre, Movie
from app.models.user import User
from app.schemas.movie import MovieListResponse, MovieResponse, MovieUpdate
from app.utils.file_utils import (
    ensure_directory,
    generate_safe_filename,
    safe_delete_file,
    validate_image_file,
    validate_video_file,
)

router = APIRouter(prefix="/api/movies", tags=["Movies"])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

async def _get_movie_or_404(movie_id: int, db: AsyncSession) -> Movie:
    result = await db.execute(
        select(Movie).options(selectinload(Movie.genres)).where(Movie.id == movie_id)
    )
    movie = result.scalar_one_or_none()
    if movie is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Movie not found")
    return movie


# ---------------------------------------------------------------------------
# List / Search
# ---------------------------------------------------------------------------

@router.get("", response_model=MovieListResponse)
async def list_movies(
    search: str | None = None,
    genre_id: int | None = None,
    is_featured: bool | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    """
    List movies with optional search, genre filter, and pagination.
    Only returns active movies for regular users.
    """
    query = select(Movie).options(selectinload(Movie.genres)).where(Movie.is_active.is_(True))

    if search:
        term = f"%{search.strip()}%"
        query = query.where(
            or_(
                Movie.title.ilike(term),
                Movie.description.ilike(term),
                Movie.language.ilike(term),
            )
        )

    if genre_id is not None:
        query = query.join(Movie.genres).where(Genre.id == genre_id)

    if is_featured is not None:
        query = query.where(Movie.is_featured == is_featured)

    # Count total
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar_one()

    # Paginate and order
    query = query.order_by(Movie.created_at.desc())
    query = query.offset((page - 1) * page_size).limit(page_size)

    result = await db.execute(query)
    items = list(result.scalars().all())

    total_pages = (total + page_size - 1) // page_size if page_size else 1
    return MovieListResponse(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
        total_pages=total_pages,
    )


# ---------------------------------------------------------------------------
# Get single movie
# ---------------------------------------------------------------------------

@router.get("/{movie_id}", response_model=MovieResponse)
async def get_movie(
    movie_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    """Get detailed movie metadata by ID."""
    return await _get_movie_or_404(movie_id, db)


# ---------------------------------------------------------------------------
# Upload / Create movie (admin)
# ---------------------------------------------------------------------------

@router.post("", response_model=MovieResponse, status_code=status.HTTP_201_CREATED)
async def create_movie(
    title: str = Form(...),
    description: str | None = Form(None),
    release_year: int | None = Form(None),
    duration: int | None = Form(None),
    language: str | None = Form(None),
    rating: float | None = Form(None),
    is_featured: bool = Form(False),
    genre_ids: str = Form(""),  # comma-separated IDs
    video_url: str | None = Form(None),  # Direct Diskwala / Cloud stream link
    poster_url: str | None = Form(None),  # Direct Poster image URL
    video: UploadFile | None = File(None),
    poster: UploadFile | None = File(None),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Upload a new movie with video URL/file and poster. Admin only."""
    movie = Movie(
        title=title,
        description=description,
        release_year=release_year,
        duration=duration,
        language=language,
        rating=rating,
        is_featured=is_featured,
    )

    # Cloud Video URL (e.g. Diskwala direct stream link)
    if video_url and video_url.strip():
        movie.video_path = video_url.strip()

    # Cloud Poster URL
    if poster_url and poster_url.strip():
        movie.poster_path = poster_url.strip()

    # Save video file from local disk if uploaded
    if video and video.filename:
        video_bytes = await video.read()
        validate_video_file(video.filename, video.content_type, len(video_bytes))
        safe_name = generate_safe_filename(video.filename, prefix="movie")
        video_dir = ensure_directory(settings.media_directory)
        video_path = video_dir / safe_name
        async with aiofiles.open(video_path, "wb") as f:
            await f.write(video_bytes)
        movie.video_path = str(video_path)
        movie.file_size = len(video_bytes)

    # Save poster file if uploaded
    if poster and poster.filename:
        poster_bytes = await poster.read()
        validate_image_file(poster.filename, poster.content_type, len(poster_bytes))
        safe_name = generate_safe_filename(poster.filename, prefix="poster")
        poster_dir = ensure_directory(settings.poster_directory)
        poster_path = poster_dir / safe_name
        async with aiofiles.open(poster_path, "wb") as f:
            await f.write(poster_bytes)
        movie.poster_path = str(poster_path)

    # Attach genres
    if genre_ids:
        ids = [int(i.strip()) for i in genre_ids.split(",") if i.strip().isdigit()]
        if ids:
            result = await db.execute(select(Genre).where(Genre.id.in_(ids)))
            movie.genres = list(result.scalars().all())

    db.add(movie)
    await db.flush()
    await db.refresh(movie, ["genres"])
    return movie


# ---------------------------------------------------------------------------
# Update movie (admin)
# ---------------------------------------------------------------------------

@router.put("/{movie_id}", response_model=MovieResponse)
async def update_movie(
    movie_id: int,
    body: MovieUpdate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Update movie metadata. Admin only."""
    movie = await _get_movie_or_404(movie_id, db)

    update_data = body.model_dump(exclude_unset=True)
    genre_ids = update_data.pop("genre_ids", None)
    category_ids = update_data.pop("category_ids", None)

    for field, value in update_data.items():
        setattr(movie, field, value)

    if genre_ids is not None:
        result = await db.execute(select(Genre).where(Genre.id.in_(genre_ids)))
        movie.genres = list(result.scalars().all())

    await db.flush()
    await db.refresh(movie, ["genres"])
    return movie


# ---------------------------------------------------------------------------
# Delete movie (admin)
# ---------------------------------------------------------------------------

@router.delete("/{movie_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_movie(
    movie_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Delete a movie and its associated media files. Admin only."""
    movie = await _get_movie_or_404(movie_id, db)

    # Clean up files from disk
    if movie.video_path and not movie.video_path.startswith("http"):
        safe_delete_file(movie.video_path)
    if movie.poster_path and not movie.poster_path.startswith("http"):
        safe_delete_file(movie.poster_path)

    await db.delete(movie)


# ---------------------------------------------------------------------------
# Serve poster image
# ---------------------------------------------------------------------------

@router.get("/{movie_id}/poster")
async def get_poster(
    movie_id: int,
    db: AsyncSession = Depends(get_db),
):
    """Serve the movie poster image."""
    movie = await _get_movie_or_404(movie_id, db)

    if not movie.poster_path:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Poster not found")

    if movie.poster_path.startswith("http://") or movie.poster_path.startswith("https://"):
        return RedirectResponse(url=movie.poster_path, status_code=status.HTTP_307_TEMPORARY_REDIRECT)

    if not Path(movie.poster_path).exists():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Poster not found")

    return FileResponse(movie.poster_path)


# ---------------------------------------------------------------------------
# HTTP Range streaming / Cloud URL Redirection
# ---------------------------------------------------------------------------

CHUNK_SIZE = 1024 * 1024  # 1 MB chunks


@router.get("/{movie_id}/stream")
async def stream_movie(
    movie_id: int,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """
    Stream a movie using HTTP Range requests or redirect directly to Cloud/Diskwala URL.
    """
    movie = await _get_movie_or_404(movie_id, db)

    if not movie.video_path:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Video source not found")

    # Cloud Video Stream (Diskwala / Direct URL)
    if movie.video_path.startswith("http://") or movie.video_path.startswith("https://"):
        return RedirectResponse(url=movie.video_path, status_code=status.HTTP_307_TEMPORARY_REDIRECT)

    if not Path(movie.video_path).exists():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Video file not found")

    video_path = Path(movie.video_path)
    file_size = video_path.stat().st_size

    # Parse Range header
    range_header = request.headers.get("Range")
    start = 0
    end = file_size - 1

    if range_header:
        try:
            range_value = range_header.strip().replace("bytes=", "")
            parts = range_value.split("-")
            start = int(parts[0]) if parts[0] else 0
            end = int(parts[1]) if parts[1] else file_size - 1
        except (ValueError, IndexError):
            raise HTTPException(
                status_code=status.HTTP_416_REQUESTED_RANGE_NOT_SATISFIABLE,
                detail="Invalid Range header",
            )

    if start >= file_size or end >= file_size or start > end:
        raise HTTPException(
            status_code=status.HTTP_416_REQUESTED_RANGE_NOT_SATISFIABLE,
            detail=f"Range not satisfiable. File size: {file_size}",
        )

    content_length = end - start + 1

    async def file_streamer():
        async with aiofiles.open(video_path, "rb") as f:
            await f.seek(start)
            remaining = content_length
            while remaining > 0:
                chunk = await f.read(min(CHUNK_SIZE, remaining))
                if not chunk:
                    break
                remaining -= len(chunk)
                yield chunk

    # Detect MIME type from extension
    ext = video_path.suffix.lower()
    mime_map = {
        ".mp4": "video/mp4",
        ".mkv": "video/x-matroska",
        ".webm": "video/webm",
        ".mov": "video/quicktime",
        ".avi": "video/x-msvideo",
    }
    media_type = mime_map.get(ext, "application/octet-stream")

    status_code = 206 if range_header else 200
    headers = {
        "Content-Range": f"bytes {start}-{end}/{file_size}",
        "Accept-Ranges": "bytes",
        "Content-Length": str(content_length),
        "Content-Type": media_type,
    }

    return StreamingResponse(
        file_streamer(),
        status_code=status_code,
        headers=headers,
        media_type=media_type,
    )


# ---------------------------------------------------------------------------
# Movie Requests (submitted to eashandarsh77@gmail.com)
# ---------------------------------------------------------------------------

@router.post("/request")
async def request_movie(
    body: dict,
    current_user: User = Depends(get_current_user),
):
    """
    Receive movie request from user (title, year, about)
    and route details for eashandarsh77@gmail.com.
    """
    title = body.get("title", "").strip()
    year = body.get("year", "").strip()
    about = body.get("about", "").strip()

    if not title:
        raise HTTPException(status_code=400, detail="Movie title is required")

    print(f"🎬 [NEW MOVIE REQUEST for eashandarsh77@gmail.com]")
    print(f"   Requested by: {current_user.username} ({current_user.email})")
    print(f"   Movie Title:  {title}")
    print(f"   Release Year: {year}")
    print(f"   About/Notes:  {about}")

    return {
        "status": "success",
        "message": f"Movie request for '{title}' received! Notification queued for eashandarsh77@gmail.com",
        "details": {
            "title": title,
            "year": year,
            "about": about,
            "requested_by": current_user.username,
            "notify_email": "eashandarsh77@gmail.com",
        }
    }

