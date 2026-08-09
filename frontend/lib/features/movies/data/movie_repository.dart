// MAYA — Movie Repository (complete with edit + favorites + history)

import 'package:dio/dio.dart';
import 'package:maya_app/core/constants/api_constants.dart';
import 'package:maya_app/core/network/api_client.dart';
import 'package:maya_app/features/movies/data/models.dart';

class MovieRepository {
  const MovieRepository();

  // -------------------------------------------------------------------------
  // Movies
  // -------------------------------------------------------------------------

  Future<List<MovieModel>> getMovies({
    int page = 1,
    int pageSize = 20,
    String? search,
    int? genreId,
    int? year,
    bool? featured,
  }) async {
    try {
      final response = await apiClient.get(
        ApiConstants.movies,
        queryParameters: {
          'page': page,
          'page_size': pageSize,
          if (search != null && search.isNotEmpty) 'search': search,
          if (genreId != null) 'genre_id': genreId,
          if (year != null) 'year': year,
          if (featured != null) 'featured': featured,
        },
      );
      final items = response.data['items'] as List<dynamic>;
      return items.map((m) => MovieModel.fromJson(m as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(extractErrorMessage(e));
    }
  }

  Future<MovieModel> getMovieById(int id) async {
    try {
      final response = await apiClient.get(ApiConstants.movieById(id));
      return MovieModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(extractErrorMessage(e));
    }
  }

  Future<List<GenreModel>> getGenres() async {
    try {
      final response = await apiClient.get(ApiConstants.genres);
      return (response.data as List<dynamic>)
          .map((g) => GenreModel.fromJson(g as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(extractErrorMessage(e));
    }
  }

  // -------------------------------------------------------------------------
  // Create movie (multipart)
  // -------------------------------------------------------------------------

  Future<MovieModel> createMovie({
    required String title,
    String? description,
    int? releaseYear,
    int? duration,
    String? language,
    double? rating,
    bool isFeatured = false,
    List<int> genreIds = const [],
    String? videoFilePath,
    String? posterFilePath,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      final fields = <String, dynamic>{
        'title': title,
        if (description != null && description.isNotEmpty) 'description': description,
        if (releaseYear != null) 'release_year': releaseYear.toString(),
        if (duration != null) 'duration': duration.toString(),
        if (language != null && language.isNotEmpty) 'language': language,
        if (rating != null) 'rating': rating.toString(),
        'is_featured': isFeatured.toString(),
        'genre_ids': genreIds.join(','),
      };

      if (videoFilePath != null) {
        fields['video'] = await MultipartFile.fromFile(videoFilePath);
      }
      if (posterFilePath != null) {
        fields['poster'] = await MultipartFile.fromFile(posterFilePath);
      }

      final response = await apiClient.post(
        ApiConstants.movies,
        data: FormData.fromMap(fields),
        options: Options(
          sendTimeout: ApiConstants.uploadTimeout,
          receiveTimeout: ApiConstants.uploadTimeout,
        ),
        onSendProgress: onSendProgress,
      );
      return MovieModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(extractErrorMessage(e));
    }
  }

  // -------------------------------------------------------------------------
  // Update movie metadata (JSON — no file re-upload)
  // -------------------------------------------------------------------------

  Future<MovieModel> updateMovie(
    int id, {
    String? title,
    String? description,
    int? releaseYear,
    int? duration,
    String? language,
    double? rating,
    bool? isFeatured,
    bool? isActive,
    List<int>? genreIds,
  }) async {
    try {
      final body = <String, dynamic>{
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (releaseYear != null) 'release_year': releaseYear,
        if (duration != null) 'duration': duration,
        if (language != null) 'language': language,
        if (rating != null) 'rating': rating,
        if (isFeatured != null) 'is_featured': isFeatured,
        if (isActive != null) 'is_active': isActive,
        if (genreIds != null) 'genre_ids': genreIds,
      };
      final response = await apiClient.put(ApiConstants.movieById(id), data: body);
      return MovieModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(extractErrorMessage(e));
    }
  }

  Future<void> deleteMovie(int id) async {
    try {
      await apiClient.delete(ApiConstants.movieById(id));
    } on DioException catch (e) {
      throw Exception(extractErrorMessage(e));
    }
  }

  // -------------------------------------------------------------------------
  // Favorites
  // -------------------------------------------------------------------------

  Future<List<FavoriteModel>> getFavorites() async {
    try {
      final response = await apiClient.get(ApiConstants.favorites);
      return (response.data as List<dynamic>)
          .map((f) => FavoriteModel.fromJson(f as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(extractErrorMessage(e));
    }
  }

  Future<FavoriteModel> addFavorite(int movieId) async {
    try {
      final response = await apiClient.post(ApiConstants.favoriteById(movieId));
      return FavoriteModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(extractErrorMessage(e));
    }
  }

  Future<void> removeFavorite(int movieId) async {
    try {
      await apiClient.delete(ApiConstants.favoriteById(movieId));
    } on DioException catch (e) {
      throw Exception(extractErrorMessage(e));
    }
  }

  // -------------------------------------------------------------------------
  // Watch History
  // -------------------------------------------------------------------------

  Future<List<WatchHistoryModel>> getHistory() async {
    try {
      final response = await apiClient.get(ApiConstants.history);
      return (response.data as List<dynamic>)
          .map((h) => WatchHistoryModel.fromJson(h as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(extractErrorMessage(e));
    }
  }

  Future<void> saveProgress(int movieId, int progressSeconds, int? durationSeconds) async {
    try {
      await apiClient.post(
        ApiConstants.historyProgress(movieId),
        data: {
          'progress_seconds': progressSeconds,
          if (durationSeconds != null) 'duration_seconds': durationSeconds,
        },
      );
    } on DioException catch (e) {
      throw Exception(extractErrorMessage(e));
    }
  }

  Future<void> removeFromHistory(int movieId) async {
    try {
      await apiClient.delete(ApiConstants.historyById(movieId));
    } on DioException catch (e) {
      throw Exception(extractErrorMessage(e));
    }
  }

  // -------------------------------------------------------------------------
  // URL helpers
  // -------------------------------------------------------------------------

  String streamUrl(int movieId) =>
      '${ApiConstants.baseUrl}${ApiConstants.movieStream(movieId)}';

  String posterUrl(int movieId) =>
      '${ApiConstants.baseUrl}${ApiConstants.moviePoster(movieId)}';
}
