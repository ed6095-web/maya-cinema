"""
MAYA Backend — Application Configuration
Reads settings from .env file using Pydantic Settings.
"""
from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # Database
    database_url: str = "sqlite+aiosqlite:///./maya.db"

    # JWT
    jwt_secret: str = "dev-secret-change-in-production"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 10080  # 7 days

    # Media directories
    media_directory: str = "media/movies"
    poster_directory: str = "media/posters"
    thumbnail_directory: str = "media/thumbnails"

    # Server
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    port: int = 8000

    # CORS origins (comma-separated string from env)
    cors_origins: str = "http://localhost,http://localhost:8000,http://10.0.2.2:8000"

    # Admin seed account
    maya_admin_username: str = "admin"
    maya_admin_email: str = "admin@maya.local"
    maya_admin_password: str = "changeme123"

    @property
    def cors_origins_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",")]

    # Application metadata
    app_name: str = "MAYA"
    app_version: str = "1.0.0"
    debug: bool = True


@lru_cache
def get_settings() -> Settings:
    """Return cached settings instance."""
    return Settings()


settings = get_settings()
