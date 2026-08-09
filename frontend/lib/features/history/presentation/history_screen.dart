// MAYA — Watch History Screen (Phase 4 — real data)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maya_app/app/router.dart';
import 'package:maya_app/app/theme.dart';
import 'package:maya_app/features/movies/data/models.dart';
import 'package:maya_app/features/movies/data/movie_repository.dart';
import 'package:maya_app/features/movies/domain/movie_providers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

// Movies with their history entries for display
class _HistoryEntry {
  final MovieModel movie;
  final WatchHistoryModel history;
  const _HistoryEntry({required this.movie, required this.history});
}

final _historyWithMoviesProvider = FutureProvider.autoDispose<List<_HistoryEntry>>((ref) async {
  final history = ref.watch(historyProvider).value ?? [];
  if (history.isEmpty) return [];
  final all = await const MovieRepository().getMovies(pageSize: 200);
  final movieMap = {for (final m in all) m.id: m};
  return history
      .where((h) => movieMap.containsKey(h.movieId))
      .map((h) => _HistoryEntry(movie: movieMap[h.movieId]!, history: h))
      .toList()
    ..sort((a, b) => b.history.lastWatchedAt.compareTo(a.history.lastWatchedAt));
});

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(_historyWithMoviesProvider);

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
        appBar: AppBar(
          title: const Text('Watch History'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: MayaColors.textPrimary),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(MayaRoutes.home);
              }
            },
          ),
        ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: MayaColors.accent)),
        error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: MayaColors.error))),
        data: (entries) => entries.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.history, color: MayaColors.textMuted, size: 56),
                    const SizedBox(height: 16),
                    Text('No watch history yet.', style: MayaTextStyles.bodyMedium),
                    const SizedBox(height: 8),
                    Text('Start watching movies to build your history.', style: MayaTextStyles.bodySmall),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(historyProvider);
                },
                color: MayaColors.accent,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(MayaSpacing.md),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(color: MayaColors.divider, height: 1),
                  itemBuilder: (context, i) => _HistoryTile(
                    entry: entries[i],
                    onRemove: () async {
                      await ref.read(historyProvider.notifier).remove(entries[i].movie.id);
                    },
                  ),
                ),
              ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final _HistoryEntry entry;
  final VoidCallback onRemove;

  const _HistoryTile({required this.entry, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final movie = entry.movie;
    final history = entry.history;
    final posterUrl = const MovieRepository().posterUrl(movie.id);
    final dateStr = DateFormat('MMM d, yyyy').format(history.lastWatchedAt.toLocal());

    return InkWell(
      onTap: () => context.go(MayaRoutes.movieDetailPath(movie.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MayaSpacing.sm),
        child: Row(
          children: [
            // Poster
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: posterUrl,
                width: 56,
                height: 76,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 56, height: 76,
                  color: MayaColors.surfaceElevated,
                  child: const Icon(Icons.movie_outlined, color: MayaColors.textMuted, size: 18),
                ),
              ),
            ),
            const SizedBox(width: MayaSpacing.md),

            // Info + progress
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(movie.title, style: MayaTextStyles.bodyMedium.copyWith(
                    color: MayaColors.textPrimary, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(
                    history.completed ? 'Watched · $dateStr' : 'Paused at ${_formatDuration(history.progressSeconds)} · $dateStr',
                    style: MayaTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  if (!history.completed && history.progressPercent > 0)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: history.progressPercent,
                        backgroundColor: MayaColors.surfaceElevated,
                        valueColor: const AlwaysStoppedAnimation(MayaColors.accent),
                        minHeight: 3,
                      ),
                    ),
                  if (history.completed)
                    Row(children: [
                      const Icon(Icons.check_circle, color: MayaColors.success, size: 14),
                      const SizedBox(width: 4),
                      Text('Completed', style: MayaTextStyles.labelSmall.copyWith(color: MayaColors.success)),
                    ]),
                ],
              ),
            ),

            // Resume / Remove
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.play_circle_outline, color: MayaColors.accent, size: 24),
                  onPressed: () => context.go(MayaRoutes.playerPath(movie.id)),
                  tooltip: history.completed ? 'Rewatch' : 'Resume',
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: MayaColors.textMuted, size: 18),
                  onPressed: onRemove,
                  tooltip: 'Remove from history',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
