// MAYA — Cinema Pro Video Player Screen
// Custom streaming control bar matching premium streaming interfaces.
// Features: Natural Aspect Ratio, Sleek seekbar, Play/Pause, 10s Skip/Rewind,
// Volume toggle, Timestamps, Scrollable Settings Modal, Maximize/Minimize toggle,
// Double-tap seeking, and PopScope back navigation.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maya_app/app/router.dart';
import 'package:maya_app/app/theme.dart';
import 'package:maya_app/core/storage/secure_storage.dart';
import 'package:maya_app/features/movies/data/models.dart';
import 'package:maya_app/features/movies/data/movie_repository.dart';
import 'package:maya_app/features/movies/domain/movie_providers.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';

enum VideoFitMode {
  contain('Original (Fit)', BoxFit.contain, Icons.aspect_ratio),
  cover('Zoom / Fill', BoxFit.cover, Icons.crop_free),
  fill('Stretch', BoxFit.fill, Icons.fit_screen);

  final String label;
  final BoxFit fit;
  final IconData icon;
  const VideoFitMode(this.label, this.fit, this.icon);
}

class PlayerScreen extends ConsumerStatefulWidget {
  final int movieId;
  const PlayerScreen({super.key, required this.movieId});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  VideoPlayerController? _controller;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  Timer? _progressTimer;
  bool _loading = true;
  String? _error;
  MovieModel? _movie;

  // Player configurations
  double _playbackSpeed = 1.0;
  bool _isMuted = false;
  double _savedVolume = 1.0;
  VideoFitMode _fitMode = VideoFitMode.contain; // Natural original aspect ratio by default

  // Double tap seek indicators
  int _seekFeedbackSeconds = 0;
  bool _showSeekFeedback = false;
  Timer? _seekFeedbackTimer;
  bool _isSeekFeedbackForward = true;

  static const Color _playerAccent = Color(0xFF00E5FF); // Vibrant Cyan from reference photo

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _movie = await const MovieRepository().getMovieById(widget.movieId);
      final streamUrl = const MovieRepository().streamUrl(widget.movieId);
      final token = await MayaSecureStorage.readToken();

      final headers = <String, String>{
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      // Check if we have existing progress to resume from
      final existingHistory = ref.read(historyProvider).value?.firstWhere(
            (h) => h.movieId == widget.movieId,
            orElse: () => WatchHistoryModel(
              id: 0,
              movieId: widget.movieId,
              progressSeconds: 0,
              lastWatchedAt: DateTime.now(),
              completed: false,
            ),
          );

      _controller = VideoPlayerController.networkUrl(
        Uri.parse(streamUrl),
        httpHeaders: headers,
      );

      await _controller!.initialize();
      _controller!.addListener(_onPlayerUpdate);

      // Resume from saved position if available
      if (existingHistory != null && existingHistory.progressSeconds > 30) {
        await _controller!.seekTo(Duration(seconds: existingHistory.progressSeconds));
      }

      _controller!.play();

      // Save progress every 10 seconds
      _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) => _saveProgress());

      if (mounted) {
        setState(() => _loading = false);
        _resetHideTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _onPlayerUpdate() {
    if (mounted) setState(() {});
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      final dur = c.value.duration;
      final pos = c.value.position;
      if (dur.inSeconds > 0 && dur.inSeconds - pos.inSeconds < 60) {
        _saveProgress(forceComplete: true);
      }
    }
  }

  Future<void> _saveProgress({bool forceComplete = false}) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final pos = c.value.position.inSeconds;
    final dur = c.value.duration.inSeconds;
    if (pos <= 0) return;

    try {
      await ref.read(historyProvider.notifier).updateProgress(
            widget.movieId,
            forceComplete ? dur : pos,
            dur > 0 ? dur : null,
          );
    } catch (_) {}
  }

  void _resetHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _resetHideTimer();
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(MayaRoutes.movieDetailPath(widget.movieId));
    }
  }

  void _seekRelative(int seconds) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final cur = c.value.position;
    final dur = c.value.duration;
    final target = cur + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > dur ? dur : target);
    c.seekTo(clamped);
    _saveProgress();
    _resetHideTimer();

    // Trigger visual feedback
    setState(() {
      _isSeekFeedbackForward = seconds > 0;
      _seekFeedbackSeconds = seconds.abs();
      _showSeekFeedback = true;
    });
    _seekFeedbackTimer?.cancel();
    _seekFeedbackTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showSeekFeedback = false);
    });
  }

  void _toggleMute() {
    final c = _controller;
    if (c == null) return;
    setState(() {
      if (_isMuted) {
        c.setVolume(_savedVolume > 0 ? _savedVolume : 1.0);
        _isMuted = false;
      } else {
        _savedVolume = c.value.volume;
        c.setVolume(0.0);
        _isMuted = true;
      }
    });
    _resetHideTimer();
  }

  void _setSpeed(double speed) {
    _controller?.setPlaybackSpeed(speed);
    setState(() => _playbackSpeed = speed);
    _resetHideTimer();
  }

  // Maximize / Minimize toggle (Switches between Natural Fit and Fullscreen Zoom)
  void _toggleMaximizeMinimize() {
    setState(() {
      if (_fitMode == VideoFitMode.contain) {
        _fitMode = VideoFitMode.cover;
      } else {
        _fitMode = VideoFitMode.contain;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_fitMode == VideoFitMode.cover ? 'Zoomed to Full Screen' : 'Original Aspect Ratio'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
    _resetHideTimer();
  }

  void _toggleFitMode() {
    setState(() {
      final nextIndex = (_fitMode.index + 1) % VideoFitMode.values.length;
      _fitMode = VideoFitMode.values[nextIndex];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Aspect Ratio: ${_fitMode.label}'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
    _resetHideTimer();
  }

  void _openSettingsModal() {
    _resetHideTimer();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final maxH = MediaQuery.of(ctx).size.height * 0.85;
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.settings, color: _playerAccent, size: 20),
                      const SizedBox(width: 10),
                      const Text(
                        'Player Settings',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 16),

                  // 1. Playback Speed
                  const Text(
                    'PLAYBACK SPEED',
                    style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) {
                        final isSel = _playbackSpeed == s;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              '${s}x',
                              style: TextStyle(
                                color: isSel ? Colors.black : Colors.white,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            selected: isSel,
                            selectedColor: _playerAccent,
                            backgroundColor: const Color(0xFF282828),
                            onSelected: (_) {
                              _setSpeed(s);
                              setSheetState(() {});
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Video Aspect Ratio / Fit
                  const Text(
                    'VIDEO ASPECT RATIO',
                    style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: VideoFitMode.values.map((mode) {
                        final isSel = _fitMode == mode;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            avatar: Icon(mode.icon, size: 16, color: isSel ? Colors.black : Colors.white70),
                            label: Text(
                              mode.label,
                              style: TextStyle(
                                color: isSel ? Colors.black : Colors.white,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            selected: isSel,
                            selectedColor: _playerAccent,
                            backgroundColor: const Color(0xFF282828),
                            onSelected: (_) {
                              setState(() => _fitMode = mode);
                              setSheetState(() {});
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Audio & Subtitles
                  const Text(
                    'AUDIO & SUBTITLES',
                    style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF222222),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      children: [
                        ListTile(
                          dense: true,
                          leading: Icon(Icons.check, color: _playerAccent, size: 18),
                          title: Text('Original Audio (Stereo / 5.1)', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ),
                        Divider(color: Colors.white12, height: 1),
                        ListTile(
                          dense: true,
                          leading: Icon(Icons.closed_caption_off, color: Colors.white54, size: 18),
                          title: Text('Subtitles Off', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openSubtitlesModal() {
    _resetHideTimer();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.closed_caption, color: _playerAccent, size: 22),
                const SizedBox(width: 10),
                const Text('Audio & Subtitles', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(color: Colors.white24),
            const ListTile(
              leading: Icon(Icons.check, color: _playerAccent),
              title: Text('Original Audio (Stereo / 5.1)', style: TextStyle(color: Colors.white)),
              dense: true,
            ),
            const ListTile(
              leading: Icon(Icons.closed_caption_off, color: Colors.white54),
              title: Text('Subtitles Off', style: TextStyle(color: Colors.white70)),
              dense: true,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _hideControlsTimer?.cancel();
    _progressTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    _controller?.removeListener(_onPlayerUpdate);
    _saveProgress();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _playerAccent),
            SizedBox(height: 16),
            Text('Loading stream...', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: MayaColors.error, size: 52),
              const SizedBox(height: 16),
              const Text(
                'Could not play this video',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: MayaColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _handleBack,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Go Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MayaColors.surfaceElevated,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final c = _controller!;
    final position = c.value.position;
    final duration = c.value.duration;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final isBuffering = c.value.isBuffering;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Video Layer (Natural Aspect Ratio Preservation) ───────────────
        GestureDetector(
          onTap: _toggleControls,
          onDoubleTapDown: (details) {
            final screenWidth = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx < screenWidth / 2) {
              _seekRelative(-10);
            } else {
              _seekRelative(10);
            }
          },
          child: Container(
            color: Colors.black,
            child: _buildVideoView(c),
          ),
        ),

        // ── Buffering indicator ──────────────────────────────────────────
        if (isBuffering)
          const Center(
            child: CircularProgressIndicator(color: _playerAccent, strokeWidth: 3),
          ),

        // ── Double Tap Ripple Feedback ───────────────────────────────────
        if (_showSeekFeedback)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: _playerAccent.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isSeekFeedbackForward ? Icons.forward_10 : Icons.replay_10,
                    color: _playerAccent,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_isSeekFeedbackForward ? '+' : '-'}${_seekFeedbackSeconds}s',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

        // ── Controls Overlay ─────────────────────────────────────────────
        AnimatedOpacity(
          opacity: _showControls ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !_showControls,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xCC000000),
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xF0000000),
                  ],
                  stops: [0.0, 0.25, 0.70, 1.0],
                ),
              ),
              child: Column(
                children: [
                  // ── Top Header (Clean: Back, Title, Close) ──────────────
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: _handleBack,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _movie?.title ?? 'MAYA Cinema',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_movie?.genreNames.isNotEmpty ?? false)
                                  Text(
                                    _movie!.genreNames,
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: _handleBack,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // ── Bottom Control Bar (matching reference photo) ───────
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Edge-to-Edge Seek Bar with Cyan Accent
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3.5,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                              activeTrackColor: _playerAccent,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: _playerAccent,
                            ),
                            child: Slider(
                              value: progress,
                              onChanged: (v) {
                                final seekMs = (v * duration.inMilliseconds).toInt();
                                c.seekTo(Duration(milliseconds: seekMs));
                                _saveProgress();
                                _resetHideTimer();
                              },
                            ),
                          ),

                          const SizedBox(height: 2),

                          // 2. Control Row: Left Group & Right Group
                          Row(
                            children: [
                              // ── LEFT GROUP ──────────────────────────────
                              // Play / Pause
                              _PlayerIconButton(
                                icon: c.value.isPlaying ? Icons.pause : Icons.play_arrow,
                                color: _playerAccent,
                                size: 24,
                                onTap: () {
                                  c.value.isPlaying ? c.pause() : c.play();
                                  _resetHideTimer();
                                },
                              ),

                              const SizedBox(width: 14),

                              // Rewind 10s
                              _PlayerIconButton(
                                icon: Icons.replay_10,
                                color: _playerAccent,
                                size: 22,
                                onTap: () => _seekRelative(-10),
                              ),

                              const SizedBox(width: 14),

                              // Forward 10s
                              _PlayerIconButton(
                                icon: Icons.forward_10,
                                color: _playerAccent,
                                size: 22,
                                onTap: () => _seekRelative(10),
                              ),

                              const SizedBox(width: 14),

                              // Volume / Mute
                              _PlayerIconButton(
                                icon: _isMuted ? Icons.volume_off : Icons.volume_up,
                                color: _playerAccent,
                                size: 22,
                                onTap: _toggleMute,
                              ),

                              const SizedBox(width: 14),

                              // Digital Timestamp: 00:18 / 57:01
                              Text(
                                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                style: const TextStyle(
                                  color: _playerAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                  fontFamily: 'monospace',
                                ),
                              ),

                              const Spacer(),

                              // ── RIGHT GROUP ─────────────────────────────
                              // Download / Offline Status
                              _PlayerIconButton(
                                icon: Icons.file_download_outlined,
                                color: _playerAccent,
                                size: 22,
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Movie available for direct offline playback.'),
                                      duration: Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(width: 16),

                              // CC / Subtitles
                              _PlayerIconButton(
                                icon: Icons.closed_caption_outlined,
                                color: _playerAccent,
                                size: 22,
                                onTap: _openSubtitlesModal,
                              ),

                              const SizedBox(width: 16),

                              // Settings (Speed, Aspect Ratio)
                              _PlayerIconButton(
                                icon: Icons.settings_outlined,
                                color: _playerAccent,
                                size: 21,
                                onTap: _openSettingsModal,
                              ),

                              const SizedBox(width: 16),

                              // Aspect Ratio Mode Switcher
                              _PlayerIconButton(
                                icon: _fitMode.icon,
                                color: _playerAccent,
                                size: 21,
                                onTap: _toggleFitMode,
                              ),

                              const SizedBox(width: 16),

                              // Maximize / Minimize toggle
                              _PlayerIconButton(
                                icon: _fitMode == VideoFitMode.contain ? Icons.fullscreen : Icons.fullscreen_exit,
                                color: _playerAccent,
                                size: 24,
                                onTap: _toggleMaximizeMinimize,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Build video with strict aspect ratio preservation
  Widget _buildVideoView(VideoPlayerController c) {
    if (!c.value.isInitialized) {
      return const SizedBox.shrink();
    }

    if (_fitMode == VideoFitMode.contain) {
      // Natural original proportions (never stretched)
      return Center(
        child: AspectRatio(
          aspectRatio: c.value.aspectRatio,
          child: VideoPlayer(c),
        ),
      );
    } else if (_fitMode == VideoFitMode.cover) {
      // Zoomed to fill screen
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: c.value.size.width,
            height: c.value.size.height,
            child: VideoPlayer(c),
          ),
        ),
      );
    } else {
      // Stretch to fill
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: c.value.size.width,
            height: c.value.size.height,
            child: VideoPlayer(c),
          ),
        ),
      );
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '${h.toString().padLeft(2, '0')}:$m:$s';
    return '$m:$s';
  }
}

class _PlayerIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _PlayerIconButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: color, size: size),
        ),
      ),
    );
  }
}
