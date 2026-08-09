# MAYA — Personal Movie Streaming Platform

> Your private cinema.

MAYA is a zero-cost, self-hosted personal media platform. An administrator uploads and manages movies; regular users browse, search, and watch them with full progress tracking and favorites.

---

## Features

- 🎬 **Movie library** — Upload, manage, and stream movies
- 🔐 **JWT authentication** — Secure role-based access (Admin / User)
- 📺 **HTTP Range streaming** — Proper seek support, no full-file loading
- ❤️ **Favorites** — Personal watchlist
- 📊 **Watch history** — Resume exactly where you left off
- 🔍 **Search** — Instant partial-match movie search
- 🏷️ **Genres** — Browse and filter by genre
- 📱 **Responsive** — Works on Android and Windows

---

## Tech Stack

| Layer | Tech |
|---|---|
| Frontend | Flutter (Dart) |
| State | Riverpod |
| Navigation | GoRouter |
| HTTP | Dio |
| Backend | FastAPI (Python) |
| ORM | SQLAlchemy (async) |
| Database | SQLite (PostgreSQL-ready) |
| Auth | JWT (python-jose + bcrypt) |
| Streaming | HTTP Range Requests (206) |

---

## Project Structure

```
maya/
├── backend/        ← FastAPI + SQLite
│   ├── app/
│   │   ├── core/       config, database, security
│   │   ├── models/     SQLAlchemy ORM models
│   │   ├── schemas/    Pydantic request/response schemas
│   │   ├── routers/    API route handlers
│   │   ├── dependencies/  auth guards
│   │   └── utils/      file handling
│   ├── media/
│   │   ├── movies/     video files
│   │   └── posters/    poster images
│   ├── seed.py         creates admin + default genres
│   ├── requirements.txt
│   └── .env.example
└── frontend/       ← Flutter app
    └── lib/
        ├── app/        theme, router
        ├── core/       API client, constants, storage
        ├── shared/     reusable widgets
        └── features/   auth, home, movies, player, search, ...
```

---

## Quick Start

### 1. Backend

```powershell
cd backend

# Create virtual environment
python -m venv venv
.\venv\Scripts\pip install -r requirements.txt

# Configure environment
copy .env.example .env
# Edit .env — change JWT_SECRET at minimum

# Create admin account and default genres
.\venv\Scripts\python seed.py

# Start server
.\venv\Scripts\uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

API docs available at: http://localhost:8000/docs

**Default admin credentials** (from .env):
- Username: `admin`
- Password: `changeme123`

> ⚠️ Change the password in `.env` before exposing to any network!

### 2. Frontend

```powershell
cd frontend
flutter pub get
flutter run  # for Android emulator or Windows
```

---

## Network Configuration

Edit `lib/core/constants/api_constants.dart`:

```dart
// For Android emulator
static const String baseUrl = 'http://10.0.2.2:8000';

// For physical phone (same Wi-Fi)
static const String baseUrl = 'http://192.168.1.X:8000';

// For Windows desktop
static const String baseUrl = 'http://localhost:8000';
```

---

## Environment Variables

| Variable | Description | Default |
|---|---|---|
| `DATABASE_URL` | SQLAlchemy database URL | `sqlite+aiosqlite:///./maya.db` |
| `JWT_SECRET` | JWT signing secret — **must change!** | dev-secret |
| `JWT_EXPIRE_MINUTES` | Token lifetime | `10080` (7 days) |
| `MEDIA_DIRECTORY` | Video storage path | `media/movies` |
| `POSTER_DIRECTORY` | Poster storage path | `media/posters` |
| `API_HOST` | Server bind host | `0.0.0.0` |
| `API_PORT` | Server port | `8000` |
| `CORS_ORIGINS` | Allowed origins (comma-separated) | localhost variants |
| `MAYA_ADMIN_USERNAME` | Admin username (seed only) | `admin` |
| `MAYA_ADMIN_EMAIL` | Admin email (seed only) | `admin@maya.local` |
| `MAYA_ADMIN_PASSWORD` | Admin password (seed only) | `changeme123` |

---

## API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/auth/login` | Login → JWT |
| POST | `/api/auth/register` | Register user |
| GET | `/api/auth/me` | Current user |
| GET | `/api/movies` | Movie list (paginated) |
| GET | `/api/movies/{id}` | Movie detail |
| POST | `/api/movies` | Upload movie (admin) |
| PUT | `/api/movies/{id}` | Edit movie (admin) |
| DELETE | `/api/movies/{id}` | Delete movie (admin) |
| GET | `/api/movies/{id}/stream` | Stream video (Range) |
| GET | `/api/movies/{id}/poster` | Serve poster |
| GET | `/api/favorites` | User favorites |
| POST | `/api/favorites/{id}` | Add favorite |
| DELETE | `/api/favorites/{id}` | Remove favorite |
| GET | `/api/history` | Watch history |
| POST | `/api/history/{id}/progress` | Save progress |
| GET | `/api/admin/stats` | Dashboard stats (admin) |
| GET | `/api/admin/users` | All users (admin) |
| GET | `/api/genres` | List genres |
| GET | `/api/health` | Health check |

---

## Connecting a Physical Phone

1. Make sure your phone and PC are on the same Wi-Fi
2. Find your PC's local IP: `ipconfig` → look for IPv4 (e.g. `192.168.1.42`)
3. Update `ApiConstants.baseUrl` to `http://192.168.1.42:8000`
4. Make sure Windows Firewall allows port 8000

---

## Upgrading to PostgreSQL

Replace `DATABASE_URL` in `.env`:
```
DATABASE_URL=postgresql+asyncpg://user:password@localhost/maya
```

Install the driver: `pip install asyncpg`

No other code changes needed — SQLAlchemy handles the rest.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `flutter pub get` fails | Check Flutter/Dart version: `flutter --version` |
| `Cannot reach server` | Ensure backend is running on port 8000, check CORS_ORIGINS |
| Android emulator can't connect | Use `10.0.2.2` as base URL, not `localhost` |
| Video won't play | Ensure the video file exists at the path stored in DB |
| Login fails | Re-run `python seed.py` to verify admin was created |

---

*MAYA is for personal use only. Only upload media you have the right to store and access.*
