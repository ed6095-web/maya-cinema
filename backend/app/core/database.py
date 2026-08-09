"""
MAYA Backend — Database Engine & Session Factory
SQLAlchemy async setup for SQLite (upgradeable to PostgreSQL).
"""
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.core.config import settings

# Create async engine — SQLite by default, PostgreSQL-ready
engine = create_async_engine(
    settings.database_url,
    echo=settings.debug,
    # SQLite-specific: allow multi-threaded access (needed for async)
    connect_args={"check_same_thread": False} if "sqlite" in settings.database_url else {},
)

# Session factory
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


class Base(DeclarativeBase):
    """Base class for all SQLAlchemy ORM models."""
    pass


async def init_db() -> None:
    """Create all tables on startup and ensure persistent admin/user accounts exist."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    # Ensure default persistent accounts are always created and preserved
    from app.core.security import hash_password
    from app.models.user import User, UserRole
    from sqlalchemy import select

    async with AsyncSessionLocal() as session:
        # 1. Admin account
        result = await session.execute(select(User).where(User.username == "admin"))
        admin_user = result.scalar_one_or_none()
        if not admin_user:
            admin_user = User(
                username=settings.maya_admin_username,
                email=settings.maya_admin_email,
                password_hash=hash_password(settings.maya_admin_password),
                role=UserRole.ADMIN,
                is_active=True,
            )
            session.add(admin_user)

        # 2. Main Owner account (ed6095)
        result_ed = await session.execute(select(User).where(User.username == "ed6095"))
        ed_user = result_ed.scalar_one_or_none()
        if not ed_user:
            ed_user = User(
                username="ed6095",
                email="eashandarsh77@gmail.com",
                password_hash=hash_password("changeme123"),
                role=UserRole.ADMIN,
                is_active=True,
            )
            session.add(ed_user)
        else:
            # Ensure ed6095 has ADMIN role
            ed_user.role = UserRole.ADMIN

        # 3. Default Genres
        from app.models.movie import Genre
        default_genres = [
            ("Action", "action"),
            ("Sci-Fi", "sci-fi"),
            ("Thriller", "thriller"),
            ("Drama", "drama"),
            ("Comedy", "comedy"),
            ("Horror", "horror"),
            ("Romance", "romance"),
            ("Adventure", "adventure"),
            ("Animation", "animation"),
            ("Crime", "crime"),
            ("Mystery", "mystery"),
            ("Fantasy", "fantasy"),
        ]
        for name, slug in default_genres:
            res_g = await session.execute(select(Genre).where(Genre.slug == slug))
            if not res_g.scalar_one_or_none():
                session.add(Genre(name=name, slug=slug))

        await session.commit()



async def get_db() -> AsyncSession:
    """FastAPI dependency: yields a database session."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
