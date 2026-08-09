// MAYA — Search Screen
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maya_app/app/theme.dart';
import 'package:maya_app/features/movies/data/models.dart';
import 'package:maya_app/features/movies/data/movie_repository.dart';
import 'package:maya_app/shared/widgets/maya_error_retry.dart';
import 'package:maya_app/shared/widgets/maya_movie_card.dart';

final _searchQueryProvider = StateProvider<String>((ref) => '');
final _searchResultsProvider = FutureProvider.autoDispose<List<MovieModel>>((ref) async {
  final query = ref.watch(_searchQueryProvider);
  if (query.trim().isEmpty) return [];
  return const MovieRepository().getMovies(search: query, pageSize: 40);
});

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(_searchQueryProvider);
    final resultsAsync = ref.watch(_searchResultsProvider);

    return Scaffold(
      backgroundColor: MayaColors.background,
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          style: MayaTextStyles.bodyLarge.copyWith(color: MayaColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search movies...',
            hintStyle: MayaTextStyles.bodyMedium,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
          onChanged: (v) => ref.read(_searchQueryProvider.notifier).state = v,
        ),
      ),
      body: query.trim().isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search, color: MayaColors.textMuted, size: 48),
                  const SizedBox(height: 12),
                  Text('Type to search for movies', style: MayaTextStyles.bodyMedium),
                ],
              ),
            )
          : resultsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: MayaColors.accent)),
              error: (e, _) => MayaErrorRetry(
                error: e,
                onRetry: () => ref.invalidate(_searchResultsProvider),
              ),
              data: (movies) => movies.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.movie_filter_outlined, color: MayaColors.textMuted, size: 48),
                          const SizedBox(height: 12),
                          Text('No results for "$query"', style: MayaTextStyles.bodyMedium),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(MayaSpacing.lg),
                      child: LayoutBuilder(builder: (context, constraints) {
                        final cols = (constraints.maxWidth / 180).floor().clamp(2, 6);
                        return GridView.builder(
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
    );
  }
}
