// MAYA — Admin Dashboard Screen (Phase 3 — full implementation)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maya_app/app/router.dart';
import 'package:maya_app/app/theme.dart';
import 'package:maya_app/core/constants/api_constants.dart';
import 'package:maya_app/core/network/api_client.dart';
import 'package:maya_app/features/admin/presentation/movie_upload_edit_screen.dart';
import 'package:maya_app/features/auth/domain/auth_provider.dart';
import 'package:maya_app/features/movies/data/models.dart';
import 'package:maya_app/features/movies/data/movie_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ============================================================================
// Providers
// ============================================================================

final _adminStatsProvider = FutureProvider.autoDispose<AdminStats>((ref) async {
  final response = await apiClient.get(ApiConstants.adminStats);
  return AdminStats.fromJson(response.data as Map<String, dynamic>);
});

final _adminMoviesProvider = FutureProvider.autoDispose<List<MovieModel>>((ref) async {
  return const MovieRepository().getMovies(pageSize: 100);
});

final _adminGenresProvider = FutureProvider.autoDispose<List<GenreModel>>((ref) async {
  return const MovieRepository().getGenres();
});

// ============================================================================
// Admin Dashboard
// ============================================================================

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(_adminStatsProvider);
    ref.invalidate(_adminMoviesProvider);
    ref.invalidate(_adminGenresProvider);
  }

  void _openUpload() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MovieUploadEditScreen(onSaved: _refresh),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

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
          backgroundColor: MayaColors.surface,
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
          title: Row(
          children: [
            Image.asset('assets/images/maya_logo.jpg', width: 26, height: 26),
            const SizedBox(width: 10),
            Text('MAYA', style: MayaTextStyles.logoText.copyWith(fontSize: 14, letterSpacing: 4)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: MayaColors.accentSubtle,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: MayaColors.accentDim),
              ),
              child: Text('ADMIN', style: MayaTextStyles.accentLabel.copyWith(fontSize: 10)),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: MayaColors.accent,
          labelColor: MayaColors.accent,
          unselectedLabelColor: MayaColors.textMuted,
          labelStyle: MayaTextStyles.labelMedium,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Movies'),
            Tab(text: 'Genres'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined, color: MayaColors.textSecondary),
            tooltip: 'Back to Home',
            onPressed: () => context.go(MayaRoutes.home),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: MayaColors.textSecondary),
            tooltip: 'Sign Out',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openUpload,
        backgroundColor: MayaColors.accent,
        foregroundColor: MayaColors.background,
        icon: const Icon(Icons.add),
        label: const Text('Add Movie'),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Overview / Stats
          _OverviewTab(onRefresh: _refresh),
          // Tab 2: Movies
          _MoviesTab(onRefresh: _refresh),
          // Tab 3: Genres
          _GenresTab(onRefresh: _refresh),
        ],
      ),
    ),
  );
}
}

// ============================================================================
// Overview Tab
// ============================================================================

class _OverviewTab extends ConsumerWidget {
  final VoidCallback onRefresh;
  const _OverviewTab({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_adminStatsProvider);

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: MayaColors.accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(MayaSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dashboard Overview', style: MayaTextStyles.titleLarge),
            const SizedBox(height: MayaSpacing.sm),
            Text('Your MAYA library at a glance.', style: MayaTextStyles.bodyMedium),
            const SizedBox(height: MayaSpacing.xl),

            statsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(color: MayaColors.accent),
                ),
              ),
              error: (e, _) => _ErrorCard(message: e.toString()),
              data: (stats) => Column(
                children: [
                  // Stats grid
                  LayoutBuilder(builder: (context, c) {
                    final cols = c.maxWidth > 600 ? 4 : 2;
                    return GridView.count(
                      crossAxisCount: cols,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: MayaSpacing.md,
                      mainAxisSpacing: MayaSpacing.md,
                      childAspectRatio: 1.8,
                      children: [
                        _StatCard(
                          label: 'Total Movies',
                          value: '${stats.totalMovies}',
                          sub: '${stats.activeMovies} active',
                          icon: Icons.movie_outlined,
                        ),
                        _StatCard(
                          label: 'Users',
                          value: '${stats.totalUsers}',
                          sub: 'registered accounts',
                          icon: Icons.people_outline,
                        ),
                        _StatCard(
                          label: 'Watch Sessions',
                          value: '${stats.totalWatchSessions}',
                          sub: '${stats.totalFavorites} favorites',
                          icon: Icons.play_circle_outline,
                        ),
                        _StatCard(
                          label: 'Hours Watched',
                          value: stats.totalWatchFormatted,
                          sub: 'total playback time',
                          icon: Icons.schedule_outlined,
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final IconData icon;

  const _StatCard({required this.label, required this.value, required this.sub, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MayaSpacing.md),
      decoration: BoxDecoration(
        color: MayaColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(MayaSpacing.cardRadius),
        border: Border.all(color: MayaColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: MayaColors.accent, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(label, style: MayaTextStyles.labelMedium)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: MayaTextStyles.titleLarge.copyWith(color: MayaColors.accent)),
              Text(sub, style: MayaTextStyles.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Movies Tab
// ============================================================================

class _MoviesTab extends ConsumerWidget {
  final VoidCallback onRefresh;
  const _MoviesTab({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moviesAsync = ref.watch(_adminMoviesProvider);

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: MayaColors.accent,
      child: moviesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: MayaColors.accent)),
        error: (e, _) => Center(child: _ErrorCard(message: e.toString())),
        data: (movies) => movies.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.movie_creation_outlined, color: MayaColors.textMuted, size: 56),
                    const SizedBox(height: 16),
                    Text('No movies yet.', style: MayaTextStyles.bodyMedium),
                    const SizedBox(height: 8),
                    Text('Tap "Add Movie" to upload your first movie.', style: MayaTextStyles.bodySmall),
                  ],
                ),
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(MayaSpacing.md),
                itemCount: movies.length,
                separatorBuilder: (_, __) => const SizedBox(height: MayaSpacing.sm),
                itemBuilder: (context, i) => _AdminMovieTile(
                  movie: movies[i],
                  onDelete: () async {
                    final confirm = await _showDeleteConfirm(context, movies[i].title);
                    if (confirm == true) {
                      await const MovieRepository().deleteMovie(movies[i].id);
                      onRefresh();
                    }
                  },
                  onEdit: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MovieUploadEditScreen(
                          existingMovie: movies[i],
                          onSaved: onRefresh,
                        ),
                      ),
                    );
                  },
                  onToggleFeature: () async {
                    await const MovieRepository().updateMovie(
                      movies[i].id,
                      isFeatured: !movies[i].isFeatured,
                    );
                    onRefresh();
                  },
                  onToggleActive: () async {
                    await const MovieRepository().updateMovie(
                      movies[i].id,
                      isActive: !movies[i].isActive,
                    );
                    onRefresh();
                  },
                ),
              ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirm(BuildContext context, String title) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Movie?'),
        content: Text('Delete "$title"? This will also remove the video and poster files.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: MayaColors.error)),
          ),
        ],
      ),
    );
  }
}

class _AdminMovieTile extends StatelessWidget {
  final MovieModel movie;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onToggleFeature;
  final VoidCallback onToggleActive;

  const _AdminMovieTile({
    required this.movie,
    required this.onDelete,
    required this.onEdit,
    required this.onToggleFeature,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final posterUrl = const MovieRepository().posterUrl(movie.id);

    return Container(
      decoration: BoxDecoration(
        color: MayaColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(MayaSpacing.cardRadius),
        border: Border.all(
          color: movie.isActive ? MayaColors.border : MayaColors.divider,
        ),
      ),
      child: Row(
        children: [
          // Poster thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(MayaSpacing.cardRadius),
              bottomLeft: Radius.circular(MayaSpacing.cardRadius),
            ),
            child: CachedNetworkImage(
              imageUrl: posterUrl,
              width: 60,
              height: 80,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                width: 60,
                height: 80,
                color: MayaColors.surfaceElevated,
                child: const Icon(Icons.movie_outlined, color: MayaColors.textMuted, size: 20),
              ),
            ),
          ),
          const SizedBox(width: MayaSpacing.md),

          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: MayaSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          movie.title,
                          style: MayaTextStyles.bodyMedium.copyWith(
                            color: movie.isActive ? MayaColors.textPrimary : MayaColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (movie.isFeatured) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: MayaColors.accentSubtle,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text('FEATURED', style: MayaTextStyles.accentLabel.copyWith(fontSize: 9)),
                        ),
                      ],
                      if (!movie.isActive) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: MayaColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text('HIDDEN', style: MayaTextStyles.labelSmall.copyWith(color: MayaColors.textMuted)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (movie.releaseYear != null) '${movie.releaseYear}',
                      if (movie.genres.isNotEmpty) movie.genres.first.name,
                      if (movie.durationFormatted.isNotEmpty) movie.durationFormatted,
                    ].join(' · '),
                    style: MayaTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
          ),

          // Actions
          PopupMenuButton<String>(
            color: MayaColors.surfaceElevated,
            icon: const Icon(Icons.more_vert, color: MayaColors.textMuted, size: 20),
            onSelected: (action) {
              switch (action) {
                case 'edit': onEdit();
                case 'feature': onToggleFeature();
                case 'toggle': onToggleActive();
                case 'delete': onDelete();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  const Icon(Icons.edit_outlined, size: 16, color: MayaColors.textSecondary),
                  const SizedBox(width: 8),
                  Text('Edit', style: MayaTextStyles.bodyMedium),
                ]),
              ),
              PopupMenuItem(
                value: 'feature',
                child: Row(children: [
                  Icon(
                    movie.isFeatured ? Icons.star : Icons.star_border,
                    size: 16,
                    color: MayaColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Text(movie.isFeatured ? 'Unfeature' : 'Feature', style: MayaTextStyles.bodyMedium),
                ]),
              ),
              PopupMenuItem(
                value: 'toggle',
                child: Row(children: [
                  Icon(
                    movie.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 16,
                    color: MayaColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(movie.isActive ? 'Hide' : 'Show', style: MayaTextStyles.bodyMedium),
                ]),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  const Icon(Icons.delete_outline, size: 16, color: MayaColors.error),
                  const SizedBox(width: 8),
                  Text('Delete', style: MayaTextStyles.bodyMedium.copyWith(color: MayaColors.error)),
                ]),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ============================================================================
// Genres Tab
// ============================================================================

class _GenresTab extends ConsumerStatefulWidget {
  final VoidCallback onRefresh;
  const _GenresTab({required this.onRefresh});

  @override
  ConsumerState<_GenresTab> createState() => _GenresTabState();
}

class _GenresTabState extends ConsumerState<_GenresTab> {
  final _genreCtrl = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _genreCtrl.dispose();
    super.dispose();
  }

  Future<void> _addGenre() async {
    final name = _genreCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _adding = true);
    try {
      await apiClient.post('/api/genres', data: {'name': name});
      _genreCtrl.clear();
      widget.onRefresh();
      ref.invalidate(_adminGenresProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: MayaColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _deleteGenre(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Genre?'),
        content: Text('Delete genre "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: MayaColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await apiClient.delete('/api/genres/$id');
      widget.onRefresh();
      ref.invalidate(_adminGenresProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final genresAsync = ref.watch(_adminGenresProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(MayaSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Manage Genres', style: MayaTextStyles.titleLarge),
          const SizedBox(height: MayaSpacing.xl),

          // Add genre
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _genreCtrl,
                  style: MayaTextStyles.bodyLarge.copyWith(color: MayaColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'New genre name',
                    hintText: 'e.g. Western',
                  ),
                  onSubmitted: (_) => _addGenre(),
                ),
              ),
              const SizedBox(width: MayaSpacing.md),
              ElevatedButton(
                onPressed: _adding ? null : _addGenre,
                child: _adding
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: MayaColors.background),
                      )
                    : const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: MayaSpacing.xl),

          genresAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: MayaColors.accent)),
            error: (e, _) => _ErrorCard(message: e.toString()),
            data: (genres) => genres.isEmpty
                ? Text('No genres yet.', style: MayaTextStyles.bodyMedium)
                : Wrap(
                    spacing: MayaSpacing.sm,
                    runSpacing: MayaSpacing.sm,
                    children: genres.map((g) => Chip(
                      label: Text(g.name, style: MayaTextStyles.bodySmall.copyWith(color: MayaColors.textPrimary)),
                      backgroundColor: MayaColors.surfaceElevated,
                      side: const BorderSide(color: MayaColors.border),
                      deleteIcon: const Icon(Icons.close, size: 14, color: MayaColors.textMuted),
                      onDeleted: () => _deleteGenre(g.id, g.name),
                    )).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Shared
// ============================================================================

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MayaSpacing.md),
      decoration: BoxDecoration(
        color: MayaColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(MayaSpacing.cardRadius),
        border: Border.all(color: MayaColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: MayaColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: MayaTextStyles.bodySmall.copyWith(color: MayaColors.error))),
        ],
      ),
    );
  }
}
