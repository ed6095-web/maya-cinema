// MAYA — Home Screen (Phase 4 — full implementation)
// Sections: Continue Watching, Recently Added, Featured, Browse by Genre

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maya_app/app/router.dart';
import 'package:maya_app/app/theme.dart';
import 'package:maya_app/features/auth/domain/auth_provider.dart';
import 'package:maya_app/features/movies/domain/movie_providers.dart';
import 'package:maya_app/shared/widgets/maya_error_retry.dart';
import 'package:maya_app/shared/widgets/maya_movie_card.dart';
import 'package:maya_app/shared/widgets/maya_section.dart';


// ============================================================================
// Home Screen
// ============================================================================

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: MayaColors.background,
      body: Column(
        children: [
          if (!isWide) _MayaMobileTopBar(isAdmin: user?.isAdmin ?? false),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(homeMoviesProvider);
                ref.invalidate(featuredMoviesProvider);
                ref.invalidate(genresProvider);
                ref.invalidate(favoritesProvider);
                ref.invalidate(historyProvider);
              },
              color: MayaColors.accent,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        MayaSpacing.lg, MayaSpacing.lg, MayaSpacing.lg, 0),
                      child: _HomeHeader(user: user, isWide: isWide),
                    ),
                  ),
                  // Continue Watching
                  const SliverToBoxAdapter(child: _ContinueWatchingSection()),
                  // Featured
                  const SliverToBoxAdapter(child: _FeaturedSection()),
                  // Recently Added
                  const SliverToBoxAdapter(child: _RecentlyAddedSection()),
                  // Genre browser
                  const SliverToBoxAdapter(child: _GenreBrowserSection()),
                  // Bottom padding
                  const SliverToBoxAdapter(child: SizedBox(height: MayaSpacing.xxl)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Header
// ============================================================================

class _HomeHeader extends StatelessWidget {
  final dynamic user;
  final bool isWide;
  const _HomeHeader({this.user, required this.isWide});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good ${_timeGreeting()}, ${user?.username ?? 'there'}.',
                style: MayaTextStyles.titleLarge,
              ),
              const SizedBox(height: 4),
              Text('What would you like to watch?', style: MayaTextStyles.bodyMedium),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => context.go(MayaRoutes.search),
          icon: const Icon(Icons.search, size: 16),
          label: const Text('Search'),
        ),
      ],
    );
  }

  String _timeGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 18) return 'afternoon';
    return 'evening';
  }
}

// ============================================================================
// Continue Watching Section
// ============================================================================

class _ContinueWatchingSection extends ConsumerWidget {
  const _ContinueWatchingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continueWatching = ref.watch(continueWatchingProvider);
    final moviesAsync = ref.watch(homeMoviesProvider);

    if (continueWatching.isEmpty) return const SizedBox();

    final movies = moviesAsync.value ?? [];
    // Map movie_id → MovieModel
    final movieMap = {for (final m in movies) m.id: m};

    final pairs = continueWatching
        .where((h) => movieMap.containsKey(h.movieId))
        .map((h) => (movie: movieMap[h.movieId]!, history: h))
        .toList();

    if (pairs.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.fromLTRB(MayaSpacing.lg, MayaSpacing.xl, MayaSpacing.lg, 0),
      child: MayaSection(
        title: 'Continue Watching',
        child: SizedBox(
          height: 195,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: pairs.length,
            separatorBuilder: (_, __) => const SizedBox(width: MayaSpacing.md),
            itemBuilder: (context, i) => SizedBox(
              width: 130,
              child: MayaMovieCard(
                movie: pairs[i].movie,
                progressPercent: pairs[i].history.progressPercent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Featured Section
// ============================================================================

class _FeaturedSection extends ConsumerWidget {
  const _FeaturedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featuredAsync = ref.watch(featuredMoviesProvider);

    return featuredAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.fromLTRB(MayaSpacing.lg, MayaSpacing.xl, MayaSpacing.lg, 0),
        child: MayaRowSkeleton(),
      ),
      error: (_, __) => const SizedBox(),
      data: (movies) {
        if (movies.isEmpty) return const SizedBox();
        return Padding(
          padding: const EdgeInsets.fromLTRB(MayaSpacing.lg, MayaSpacing.xl, MayaSpacing.lg, 0),
          child: MayaSection(
            title: 'Featured',
            child: SizedBox(
              height: 195,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: movies.length,
                separatorBuilder: (_, __) => const SizedBox(width: MayaSpacing.md),
                itemBuilder: (_, i) => SizedBox(
                  width: 130,
                  child: MayaMovieCard(movie: movies[i]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// Recently Added Section
// ============================================================================

class _RecentlyAddedSection extends ConsumerWidget {
  const _RecentlyAddedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moviesAsync = ref.watch(homeMoviesProvider);

    return moviesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.fromLTRB(MayaSpacing.lg, MayaSpacing.xl, MayaSpacing.lg, 0),
        child: MayaGridSkeleton(),
      ),
      error: (e, st) => Padding(
        padding: const EdgeInsets.all(MayaSpacing.lg),
        child: MayaErrorRetry(
          error: e,
          onRetry: () => ref.invalidate(homeMoviesProvider),
        ),
      ),
      data: (movies) {
        if (movies.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(MayaSpacing.xl),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.movie_creation_outlined, color: MayaColors.textMuted, size: 56),
                  const SizedBox(height: 16),
                  Text('No movies in the library yet.', style: MayaTextStyles.bodyMedium),
                  const SizedBox(height: 6),
                  Text('An admin needs to upload movies first.', style: MayaTextStyles.bodySmall),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(MayaSpacing.lg, MayaSpacing.xl, MayaSpacing.lg, 0),
          child: MayaSection(
            title: 'Recently Added',
            child: LayoutBuilder(builder: (context, c) {
              final cols = (c.maxWidth / 175).floor().clamp(2, 7);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: MayaSpacing.md,
                  mainAxisSpacing: MayaSpacing.md,
                ),
                itemCount: movies.take(18).length,
                itemBuilder: (_, i) => MayaMovieCard(movie: movies[i]),
              );
            }),
          ),
        );
      },
    );
  }
}

// ============================================================================
// Genre Browser Section
// ============================================================================

class _GenreBrowserSection extends ConsumerWidget {
  const _GenreBrowserSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genresAsync = ref.watch(genresProvider);
    final selectedGenreId = ref.watch(selectedGenreProvider);
    final filteredAsync = ref.watch(filteredByGenreProvider);

    return genresAsync.when(
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
      data: (genres) {
        if (genres.isEmpty) return const SizedBox();

        return Padding(
          padding: const EdgeInsets.fromLTRB(MayaSpacing.lg, MayaSpacing.xl, MayaSpacing.lg, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Browse by Genre', style: MayaTextStyles.titleMedium),
              const SizedBox(height: MayaSpacing.md),

              // Genre chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: genres.map((g) {
                    final selected = selectedGenreId == g.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          ref.read(selectedGenreProvider.notifier).state =
                              selected ? null : g.id;
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? MayaColors.accent : MayaColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected ? MayaColors.accent : MayaColors.border,
                            ),
                          ),
                          child: Text(
                            g.name,
                            style: MayaTextStyles.labelMedium.copyWith(
                              color: selected ? MayaColors.background : MayaColors.textSecondary,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Genre results
              if (selectedGenreId != null) ...[
                const SizedBox(height: MayaSpacing.lg),
                filteredAsync.when(
                  loading: () => const MayaGridSkeleton(),
                  error: (e, _) => Text(e.toString(),
                      style: MayaTextStyles.bodySmall.copyWith(color: MayaColors.error)),
                  data: (movies) => movies.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(MayaSpacing.xl),
                          child: Center(
                            child: Text(
                              'No movies in this genre yet.',
                              style: MayaTextStyles.bodyMedium,
                            ),
                          ),
                        )
                      : LayoutBuilder(builder: (context, c) {
                          final cols = (c.maxWidth / 175).floor().clamp(2, 7);
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
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
              ],
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// Mobile Top Bar
// ============================================================================

class _MayaMobileTopBar extends StatelessWidget {
  final bool isAdmin;
  const _MayaMobileTopBar({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MayaColors.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: MayaSpacing.md),
          child: Row(
            children: [
              Image.asset('assets/images/maya_logo.jpg', width: 28, height: 28),
              const SizedBox(width: 8),
              Text('MAYA', style: MayaTextStyles.logoText.copyWith(fontSize: 14, letterSpacing: 3)),
              const Spacer(),
              if (isAdmin)
                IconButton(
                  onPressed: () => context.push(MayaRoutes.admin),
                  icon: const Icon(Icons.dashboard_outlined, color: MayaColors.accent, size: 20),
                  tooltip: 'Admin Dashboard',
                ),
              IconButton(
                onPressed: () => context.push(MayaRoutes.search),
                icon: const Icon(Icons.search, color: MayaColors.textSecondary, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

