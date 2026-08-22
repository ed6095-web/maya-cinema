"""MAYA Backend — Models package init."""
from app.models.user import User, UserRole
from app.models.movie import Movie, Genre, Category, movie_genres, movie_categories
from app.models.favorite import Favorite
from app.models.watch_history import WatchHistory
from app.models.external_media import ExternalMedia

__all__ = [
    "User",
    "UserRole",
    "Movie",
    "Genre",
    "Category",
    "movie_genres",
    "movie_categories",
    "Favorite",
    "WatchHistory",
    "ExternalMedia",
]
