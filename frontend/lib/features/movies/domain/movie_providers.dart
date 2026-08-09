// MAYA — Favorites, History & Movie Riverpod Providers
// Central state for movies, favorites, genres, and watch history.
// Automatically responds to Auth state changes.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maya_app/features/auth/domain/auth_provider.dart';
import 'package:maya_app/features/movies/data/models.dart';
import 'package:maya_app/features/movies/data/movie_repository.dart';

// ============================================================================
// Movies & Genres Providers
// ============================================================================

/// Home movies list (60 items)
final homeMoviesProvider = FutureProvider.autoDispose<List<MovieModel>>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth is! AuthAuthenticated) return [];
  return const MovieRepository().getMovies(pageSize: 60);
});

/// Featured movies for carousel/banner
final featuredMoviesProvider = FutureProvider.autoDispose<List<MovieModel>>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth is! AuthAuthenticated) return [];
  return const MovieRepository().getMovies(featured: true, pageSize: 6);
});

/// Available genres list
final genresProvider = FutureProvider.autoDispose<List<GenreModel>>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth is! AuthAuthenticated) return [];
  return const MovieRepository().getGenres();
});

/// Currently selected genre filter for home screen
final selectedGenreProvider = StateProvider.autoDispose<int?>((ref) => null);

/// Movies filtered by selected genre
final filteredByGenreProvider = FutureProvider.autoDispose<List<MovieModel>>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth is! AuthAuthenticated) return [];
  final genreId = ref.watch(selectedGenreProvider);
  if (genreId == null) return [];
  return const MovieRepository().getMovies(genreId: genreId, pageSize: 40);
});

// ============================================================================
// Favorites
// ============================================================================

class FavoritesNotifier extends AsyncNotifier<List<FavoriteModel>> {
  @override
  Future<List<FavoriteModel>> build() async {
    final auth = ref.watch(authProvider);
    if (auth is! AuthAuthenticated) return [];
    return const MovieRepository().getFavorites();
  }

  Future<void> add(int movieId) async {
    final fav = await const MovieRepository().addFavorite(movieId);
    state = AsyncData([...state.value ?? [], fav]);
  }

  Future<void> remove(int movieId) async {
    await const MovieRepository().removeFavorite(movieId);
    state = AsyncData(
      (state.value ?? []).where((f) => f.movieId != movieId).toList(),
    );
  }

  bool isFavorite(int movieId) {
    return (state.value ?? []).any((f) => f.movieId == movieId);
  }
}

final favoritesProvider = AsyncNotifierProvider<FavoritesNotifier, List<FavoriteModel>>(
  FavoritesNotifier.new,
);

/// Set of favorited movie IDs for O(1) lookup.
final favoritedMovieIdsProvider = Provider<Set<int>>((ref) {
  final favs = ref.watch(favoritesProvider).value ?? [];
  return favs.map((f) => f.movieId).toSet();
});

// ============================================================================
// Watch History
// ============================================================================

class HistoryNotifier extends AsyncNotifier<List<WatchHistoryModel>> {
  @override
  Future<List<WatchHistoryModel>> build() async {
    final auth = ref.watch(authProvider);
    if (auth is! AuthAuthenticated) return [];
    return const MovieRepository().getHistory();
  }

  Future<void> updateProgress(int movieId, int progressSeconds, int? durationSeconds) async {
    await const MovieRepository().saveProgress(movieId, progressSeconds, durationSeconds);
    // Refresh to get updated entry
    state = AsyncData(await const MovieRepository().getHistory());
  }

  Future<void> remove(int movieId) async {
    await const MovieRepository().removeFromHistory(movieId);
    state = AsyncData(
      (state.value ?? []).where((h) => h.movieId != movieId).toList(),
    );
  }

  WatchHistoryModel? getProgress(int movieId) {
    return (state.value ?? []).where((h) => h.movieId == movieId).firstOrNull;
  }
}

final historyProvider = AsyncNotifierProvider<HistoryNotifier, List<WatchHistoryModel>>(
  HistoryNotifier.new,
);

/// Only entries that are not completed — for "Continue Watching".
final continueWatchingProvider = Provider<List<WatchHistoryModel>>((ref) {
  final history = ref.watch(historyProvider).value ?? [];
  return history.where((h) => !h.completed && h.progressSeconds > 0).toList();
});
