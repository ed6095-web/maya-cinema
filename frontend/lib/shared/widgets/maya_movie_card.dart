// MAYA — Shared Widgets: MayaMovieCard
// Includes Hero transition on poster for smooth navigation to detail screen.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maya_app/app/router.dart';
import 'package:maya_app/app/theme.dart';
import 'package:maya_app/features/movies/data/models.dart';
import 'package:maya_app/features/movies/data/movie_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MayaMovieCard extends StatefulWidget {
  final MovieModel movie;
  final double? progressPercent;

  const MayaMovieCard({super.key, required this.movie, this.progressPercent});

  @override
  State<MayaMovieCard> createState() => _MayaMovieCardState();
}

class _MayaMovieCardState extends State<MayaMovieCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final posterUrl = const MovieRepository().posterUrl(widget.movie.id);
    // Hero tag is movie-specific so each card can transition independently
    final heroTag = 'movie-poster-${widget.movie.id}';

    return GestureDetector(
      onTap: () => context.go(MayaRoutes.movieDetailPath(widget.movie.id)),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedScale(
          scale: _hovered ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: Hero(
            tag: heroTag,
            flightShuttleBuilder: _flightShuttleBuilder,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(MayaSpacing.cardRadius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Poster ────────────────────────────────────────────
                  CachedNetworkImage(
                    imageUrl: posterUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: MayaColors.surfaceSecondary,
                      child: const Center(
                        child: Icon(Icons.movie_outlined,
                            color: MayaColors.textMuted, size: 32),
                      ),
                    ),
                    errorWidget: (_, __, ___) => _PosterPlaceholder(title: widget.movie.title),
                  ),

                  // ── Bottom gradient ───────────────────────────────────
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 110,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xEE000000)],
                        ),
                      ),
                    ),
                  ),

                  // ── Title & metadata ──────────────────────────────────
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.movie.title,
                            style: MayaTextStyles.titleSmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.movie.releaseYear != null ||
                              widget.movie.genres.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              [
                                if (widget.movie.releaseYear != null)
                                  '${widget.movie.releaseYear}',
                                if (widget.movie.genres.isNotEmpty)
                                  widget.movie.genres.first.name,
                              ].join(' · '),
                              style: MayaTextStyles.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          // Progress bar (Continue Watching)
                          if (widget.progressPercent != null) ...[
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: widget.progressPercent,
                                backgroundColor: MayaColors.surfaceElevated,
                                valueColor:
                                    const AlwaysStoppedAnimation(MayaColors.accent),
                                minHeight: 3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // ── Featured badge ────────────────────────────────────
                  if (widget.movie.isFeatured)
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: MayaColors.accent,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'FEATURED',
                          style: MayaTextStyles.labelSmall.copyWith(
                            color: MayaColors.background,
                            fontSize: 9,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),

                  // ── Hover play overlay ────────────────────────────────
                  AnimatedOpacity(
                    opacity: _hovered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 160),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                      ),
                      child: const Center(
                        child: Icon(Icons.play_circle_filled,
                            color: MayaColors.accent, size: 40),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Custom shuttle builder — keeps rounded corners during the Hero animation
  Widget _flightShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(
            direction == HeroFlightDirection.push
                ? (1 - animation.value) * MayaSpacing.cardRadius
                : animation.value * MayaSpacing.cardRadius,
          ),
          child: child,
        );
      },
      child: fromHeroContext.widget,
    );
  }
}

class _PosterPlaceholder extends StatelessWidget {
  final String title;
  const _PosterPlaceholder({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MayaColors.surfaceSecondary,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Center(
            child: Icon(Icons.movie_outlined, color: MayaColors.textMuted, size: 32),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: const Color(0xCC000000),
              child: Text(
                title,
                style: MayaTextStyles.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
