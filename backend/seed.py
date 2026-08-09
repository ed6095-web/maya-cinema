"""
MAYA Backend — Admin Seed Script
Creates the initial admin account and default genres.
Run once: python seed.py

Reads credentials from .env:
  MAYA_ADMIN_USERNAME
  MAYA_ADMIN_EMAIL
  MAYA_ADMIN_PASSWORD
"""
import asyncio
import sys

# Fix Windows console encoding
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

# Import ALL models so SQLAlchemy can resolve all relationships
from app.core.database import AsyncSessionLocal, engine, init_db
from app.core.security import hash_password
from app.models.movie import Genre  # noqa: F401 — also registers Movie, Category
from app.models.user import User, UserRole
from app.models.favorite import Favorite  # noqa: F401
from app.models.watch_history import WatchHistory  # noqa: F401

DEFAULT_GENRES = [
    ("Action", "action"),
    ("Comedy", "comedy"),
    ("Drama", "drama"),
    ("Sci-Fi", "sci-fi"),
    ("Thriller", "thriller"),
    ("Horror", "horror"),
    ("Animation", "animation"),
    ("Documentary", "documentary"),
    ("Romance", "romance"),
    ("Adventure", "adventure"),
    ("Fantasy", "fantasy"),
    ("Crime", "crime"),
]


async def seed():
    from app.core.config import settings

    print("MAYA -- Seeding database...")
    await init_db()

    async with AsyncSessionLocal() as db:
        # Create admin user if not exists
        result = await db.execute(select(User).where(User.username == settings.maya_admin_username))
        existing_admin = result.scalar_one_or_none()

        if existing_admin:
            print(f"   [skip] Admin '{settings.maya_admin_username}' already exists.")
        else:
            admin = User(
                username=settings.maya_admin_username,
                email=settings.maya_admin_email,
                password_hash=hash_password(settings.maya_admin_password),
                role=UserRole.ADMIN,
                is_active=True,
            )
            db.add(admin)
            print(f"   [ok] Admin created: {settings.maya_admin_username} / {settings.maya_admin_email}")

        # Create default genres
        for name, slug in DEFAULT_GENRES:
            result = await db.execute(select(Genre).where(Genre.slug == slug))
            if not result.scalar_one_or_none():
                db.add(Genre(name=name, slug=slug))
                print(f"   [ok] Genre: {name}")
            else:
                print(f"   [skip] Genre '{name}' already exists.")

        await db.commit()

    print("\nMAYA database seeded successfully!")
    print(f"   Admin login: {settings.maya_admin_username}")
    print(f"   Visit http://localhost:8000/docs to explore the API.\n")


if __name__ == "__main__":
    asyncio.run(seed())
