// MAYA — Movie Detail Screen (Phase 4 — favorite button + real data)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maya_app/app/router.dart';
import 'package:maya_app/app/theme.dart';
import 'package:maya_app/features/movies/data/models.dart';
import 'package:maya_app/features/movies/data/movie_repository.dart';
import 'package:maya_app/features/movies/domain/movie_providers.dart';
import 'package:cached_network_image/cached_network_image.dart';

final _movieDetailProvider = FutureProvider.autoDispose.family<MovieModel, int>((ref, id) async {
  return const MovieRepository().getMovieById(id);
});

class MovieDetailScreen extends ConsumerWidget {
  final int movieId;
  const MovieDetailScreen({super.key, required this.movieId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movieAsync = ref.watch(_movieDetailProvider(movieId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(MayaRoutes.home);
        }
      },
      child: Scaffold(
        backgroundColor: MayaColors.background,
        body: movieAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: MayaColors.accent)),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: MayaColors.error, size: 48),
                const SizedBox(height: 16),
                Text(e.toString(), style: const TextStyle(color: MayaColors.textMuted)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(MayaRoutes.home);
                    }
                  },
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
          data: (movie) => _MovieDetailContent(movie: movie, movieId: movieId),
        ),
      ),
    );
  }
}

class _MovieDetailContent extends ConsumerWidget {
  final MovieModel movie;
  final int movieId;
  const _MovieDetailContent({required this.movie, required this.movieId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posterUrl = const MovieRepository().posterUrl(movie.id);
    final isWide = MediaQuery.of(context).size.width > 700;
    final isFav = ref.watch(favoritedMovieIdsProvider).contains(movieId);
    final history = ref.watch(historyProvider).value
        ?.firstWhere((h) => h.movieId == movieId, orElse: () => WatchHistoryModel(
              id: 0, movieId: movieId, progressSeconds: 0, lastWatchedAt: DateTime.now(), completed: false));

    return CustomScrollView(
      slivers: [
        // Hero backdrop
        SliverAppBar(
          expandedHeight: isWide ? 360 : 240,
          pinned: true,
          backgroundColor: MayaColors.background,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: MayaColors.textPrimary),
            onPressed: () => context.pop(),
          ),
          actions: [
            // Favorite toggle
            IconButton(
              icon: Icon(
                isFav ? Icons.bookmark : Icons.bookmark_border,
                color: isFav ? MayaColors.accent : MayaColors.textSecondary,
              ),
              tooltip: isFav ? 'Remove from My List' : 'Add to My List',
              onPressed: () async {
                try {
                  if (isFav) {
                    await ref.read(favoritesProvider.notifier).remove(movieId);
                  } else {
                    await ref.read(favoritesProvider.notifier).add(movieId);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: MayaColors.error),
                    );
                  }
                }
              },
            ),
            const SizedBox(width: 8),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: 'movie-poster-${movie.id}',
                  child: CachedNetworkImage(
                    imageUrl: posterUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(color: MayaColors.surfaceSecondary),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x33000000), Color(0xFF050505)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(MayaSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(movie.title, style: MayaTextStyles.displayMedium),
                const SizedBox(height: MayaSpacing.sm),

                // Metadata row
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (movie.releaseYear != null)
                      _MetaBadge(text: '${movie.releaseYear}'),
                    if (movie.genres.isNotEmpty)
                      _MetaBadge(text: movie.genreNames, isHighlight: true),
                    if (movie.durationFormatted.isNotEmpty)
                      _MetaBadge(text: movie.durationFormatted),
                    if (movie.language != null)
                      _MetaBadge(text: movie.language!),
                    if (movie.rating != null)
                      _MetaBadge(text: '★ ${movie.rating!.toStringAsFixed(1)}', isHighlight: true),
                  ],
                ),
                const SizedBox(height: MayaSpacing.lg),

                // Continue watching progress
                if (history != null && history.progressSeconds > 0 && !history.completed) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Continue from ${_formatDur(history.progressSeconds)}',
                        style: MayaTextStyles.bodySmall.copyWith(color: MayaColors.accent),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: history.progressPercent,
                          backgroundColor: MayaColors.surfaceElevated,
                          valueColor: const AlwaysStoppedAnimation(MayaColors.accent),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: MayaSpacing.md),
                ],

                // Action buttons
                Wrap(
                  spacing: MayaSpacing.md,
                  runSpacing: MayaSpacing.sm,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => context.push(MayaRoutes.playerPath(movie.id)),
                      icon: const Icon(Icons.play_arrow, size: 20),
                      label: Text(
                        history != null && history.progressSeconds > 0 && !history.completed
                            ? 'Resume'
                            : 'Play',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          if (isFav) {
                            await ref.read(favoritesProvider.notifier).remove(movieId);
                          } else {
                            await ref.read(favoritesProvider.notifier).add(movieId);
                          }
                        } catch (_) {}
                      },
                      icon: Icon(isFav ? Icons.bookmark : Icons.bookmark_border, size: 18),
                      label: Text(isFav ? 'Saved' : 'My List'),
                    ),
                  ],
                ),

                // Description
                if (movie.description != null && movie.description!.isNotEmpty) ...[
                  const SizedBox(height: MayaSpacing.xl),
                  Text('About', style: MayaTextStyles.titleSmall),
                  const SizedBox(height: MayaSpacing.sm),
                  Text(movie.description!, style: MayaTextStyles.bodyLarge),
                ],

                const SizedBox(height: MayaSpacing.xxl),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDur(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}

class _MetaBadge extends StatelessWidget {
  final String text;
  final bool isHighlight;
  const _MetaBadge({required this.text, this.isHighlight = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: MayaTextStyles.bodyMedium.copyWith(
        color: isHighlight ? MayaColors.accent : MayaColors.textSecondary,
      ),
    );
  }
}
