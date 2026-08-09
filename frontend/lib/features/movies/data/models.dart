// MAYA — Data Models (API response types)

class UserModel {
  final int id;
  final String username;
  final String email;
  final String role;
  final String? avatarPath;
  final bool isActive;

  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    this.avatarPath,
    required this.isActive,
  });

  bool get isAdmin => role == 'ADMIN';

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as int,
        username: json['username'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        avatarPath: json['avatar_path'] as String?,
        isActive: json['is_active'] as bool,
      );
}

class GenreModel {
  final int id;
  final String name;
  final String slug;

  const GenreModel({required this.id, required this.name, required this.slug});

  factory GenreModel.fromJson(Map<String, dynamic> json) => GenreModel(
        id: json['id'] as int,
        name: json['name'] as String,
        slug: json['slug'] as String,
      );
}

class MovieModel {
  final int id;
  final String title;
  final String? description;
  final int? releaseYear;
  final int? duration; // seconds
  final String? language;
  final double? rating;
  final String? posterPath;
  final String? videoPath;
  final int? fileSize;
  final String? resolution;
  final bool isFeatured;
  final bool isActive;
  final List<GenreModel> genres;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MovieModel({
    required this.id,
    required this.title,
    this.description,
    this.releaseYear,
    this.duration,
    this.language,
    this.rating,
    this.posterPath,
    this.videoPath,
    this.fileSize,
    this.resolution,
    required this.isFeatured,
    required this.isActive,
    required this.genres,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Formatted duration string e.g. "2h 49m"
  String get durationFormatted {
    if (duration == null) return '';
    final h = duration! ~/ 3600;
    final m = (duration! % 3600) ~/ 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  String get genreNames => genres.map((g) => g.name).join(', ');

  factory MovieModel.fromJson(Map<String, dynamic> json) => MovieModel(
        id: json['id'] as int,
        title: json['title'] as String,
        description: json['description'] as String?,
        releaseYear: json['release_year'] as int?,
        duration: json['duration'] as int?,
        language: json['language'] as String?,
        rating: (json['rating'] as num?)?.toDouble(),
        posterPath: json['poster_path'] as String?,
        videoPath: json['video_path'] as String?,
        fileSize: json['file_size'] as int?,
        resolution: json['resolution'] as String?,
        isFeatured: json['is_featured'] as bool? ?? false,
        isActive: json['is_active'] as bool? ?? true,
        genres: (json['genres'] as List<dynamic>? ?? [])
            .map((g) => GenreModel.fromJson(g as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class WatchHistoryModel {
  final int id;
  final int movieId;
  final int progressSeconds;
  final int? durationSeconds;
  final DateTime lastWatchedAt;
  final bool completed;

  const WatchHistoryModel({
    required this.id,
    required this.movieId,
    required this.progressSeconds,
    this.durationSeconds,
    required this.lastWatchedAt,
    required this.completed,
  });

  double get progressPercent {
    if (durationSeconds == null || durationSeconds == 0) return 0.0;
    return (progressSeconds / durationSeconds!).clamp(0.0, 1.0);
  }

  factory WatchHistoryModel.fromJson(Map<String, dynamic> json) =>
      WatchHistoryModel(
        id: json['id'] as int,
        movieId: json['movie_id'] as int,
        progressSeconds: json['progress_seconds'] as int,
        durationSeconds: json['duration_seconds'] as int?,
        lastWatchedAt: DateTime.parse(json['last_watched_at'] as String),
        completed: json['completed'] as bool? ?? false,
      );
}

class FavoriteModel {
  final int id;
  final int movieId;
  final DateTime createdAt;

  const FavoriteModel({
    required this.id,
    required this.movieId,
    required this.createdAt,
  });

  factory FavoriteModel.fromJson(Map<String, dynamic> json) => FavoriteModel(
        id: json['id'] as int,
        movieId: json['movie_id'] as int,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class AdminStats {
  final int totalMovies;
  final int totalUsers;
  final int totalWatchSessions;
  final int totalFavorites;
  final int totalWatchSeconds;
  final int activeMovies;

  const AdminStats({
    required this.totalMovies,
    required this.totalUsers,
    required this.totalWatchSessions,
    required this.totalFavorites,
    required this.totalWatchSeconds,
    required this.activeMovies,
  });

  String get totalWatchFormatted {
    final hours = totalWatchSeconds ~/ 3600;
    return '${hours}h';
  }

  factory AdminStats.fromJson(Map<String, dynamic> json) => AdminStats(
        totalMovies: json['total_movies'] as int,
        totalUsers: json['total_users'] as int,
        totalWatchSessions: json['total_watch_sessions'] as int,
        totalFavorites: json['total_favorites'] as int,
        totalWatchSeconds: json['total_watch_seconds'] as int,
        activeMovies: json['active_movies'] as int,
      );
}
