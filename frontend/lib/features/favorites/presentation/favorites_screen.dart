// MAYA — Favorites Screen (Phase 4 — real data)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maya_app/app/theme.dart';
import 'package:maya_app/features/movies/data/models.dart';
import 'package:maya_app/features/movies/data/movie_repository.dart';
import 'package:maya_app/features/movies/domain/movie_providers.dart';
import 'package:maya_app/shared/widgets/maya_movie_card.dart';

// We need the actual movies for each favorite
final _favMoviesProvider = FutureProvider.autoDispose<List<MovieModel>>((ref) async {
  final favIds = ref.watch(favoritedMovieIdsProvider);
  if (favIds.isEmpty) return [];
  // Fetch all movies and filter locally (good enough for personal library size)
  final all = await const MovieRepository().getMovies(pageSize: 200);
  return all.where((m) => favIds.contains(m.id)).toList();
});

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favMoviesAsync = ref.watch(_favMoviesProvider);
    final isLoading = ref.watch(favoritesProvider).isLoading;

    return Scaffold(
      backgroundColor: MayaColors.background,
      appBar: AppBar(
        title: const Text('My List'),
        actions: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: MayaColors.accent),
              ),
            ),
        ],
      ),
      body: favMoviesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: MayaColors.accent)),
        error: (e, _) => Center(
          child: Text(e.toString(), style: const TextStyle(color: MayaColors.error)),
        ),
        data: (movies) => movies.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bookmark_border, color: MayaColors.textMuted, size: 56),
                    const SizedBox(height: 16),
                    Text('Your list is empty.', style: MayaTextStyles.bodyMedium),
                    const SizedBox(height: 8),
                    Text('Tap the bookmark on any movie to save it here.',
                        style: MayaTextStyles.bodySmall),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(_favMoviesProvider),
                color: MayaColors.accent,
                child: Padding(
                  padding: const EdgeInsets.all(MayaSpacing.lg),
                  child: LayoutBuilder(builder: (context, c) {
                    final cols = (c.maxWidth / 175).floor().clamp(2, 7);
                    return GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: MayaSpacing.md,
                        mainAxisSpacing: MayaSpacing.md,
                      ),
                      itemCount: movies.length,
                      itemBuilder: (_, i) => MayaMovieCard(movie: movies[i]),
                    );
                  }),
                ),
              ),
      ),
    );
  }
}
