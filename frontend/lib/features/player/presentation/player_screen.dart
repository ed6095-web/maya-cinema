// MAYA — Cinema Pro Video Player Screen
// Hybrid Native & WebStream In-App Cinema Engine:
// 1. Direct Video Streams (.mp4, .m3u8, .mkv) -> Native Cyan Cinema Player (Quality, Speed, Seek)
// 2. Web / Diskwala Streams -> In-App Cinema WebView Player (Zero external apps, 100% inside MAYA)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maya_app/app/router.dart';
import 'package:maya_app/app/theme.dart';
import 'package:maya_app/features/movies/data/models.dart';
import 'package:maya_app/features/movies/data/movie_repository.dart';
import 'package:maya_app/features/movies/domain/movie_providers.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

// ============================================================================
// Video Aspect Ratio Modes
// ============================================================================

enum VideoFitMode {
  contain('Original (Fit)', Icons.aspect_ratio),
  cover('Zoom to Fill', Icons.crop_free),
  fill('Stretch', Icons.fit_screen);

  final String label;
  final IconData icon;
  const VideoFitMode(this.label, this.icon);
}

// ============================================================================
// Player Screen
// ============================================================================

class PlayerScreen extends ConsumerStatefulWidget {
  final int movieId;
  const PlayerScreen({super.key, required this.movieId});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  // Native video player state
  VideoPlayerController? _controller;
  bool _isWebViewMode = false;
  WebViewController? _webViewController;
  bool _webViewLoading = true;

  bool _showControls = true;
  Timer? _hideControlsTimer;
  Timer? _progressTimer;
  bool _loading = true;
  String? _error;
  MovieModel? _movie;

  // Quality & Settings
  String _selectedQuality = 'Auto';
  double _playbackSpeed = 1.0;
  bool _isMuted = false;
  double _savedVolume = 1.0;
  VideoFitMode _fitMode = VideoFitMode.contain;

  // Double tap seek feedback
  int _seekFeedbackSeconds = 0;
  bool _showSeekFeedback = false;
  Timer? _seekFeedbackTimer;
  bool _isSeekFeedbackForward = true;

  static const Color _playerAccent = Color(0xFF00E5FF); // Vibrant Cyan

  final List<String> _qualities = ['Auto', '1080p FHD', '720p HD', '480p SD', '360p'];

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

  bool _isWebStreamUrl(String url) {
    final lower = url.toLowerCase().trim();
    if (lower.contains('diskwala.com') ||
        lower.contains('terabox.com') ||
        lower.contains('youtube.com') ||
        lower.contains('dailymotion.com')) {
      return true;
    }
    // If it is an HTTP URL without standard direct video extensions, treat as web stream
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      final isDirectMedia = lower.endsWith('.mp4') ||
          lower.endsWith('.mkv') ||
          lower.endsWith('.m3u8') ||
          lower.endsWith('.webm') ||
          lower.endsWith('.mov') ||
          lower.contains('.mp4?') ||
          lower.contains('.m3u8?');
      return !isDirectMedia;
    }
    return false;
  }

  Future<void> _initPlayer() async {
    setState(() {
      _loading = true;
      _error = null;
      _isWebViewMode = false;
    });

    try {
      _movie = await const MovieRepository().getMovieById(widget.movieId);
      final videoPath = _movie?.videoPath?.trim() ?? '';

      // ── MODE 1: In-App WebStream Engine (Diskwala & Web Video Links) ─────
      if (_isWebStreamUrl(videoPath)) {
        _setupWebView(videoPath);
        return;
      }

      // ── MODE 2: Native Cinema Player (Direct MP4 / HLS Streams) ──────────
      String targetUrl;
      if (videoPath.startsWith('http://') || videoPath.startsWith('https://')) {
        targetUrl = videoPath;
      } else {
        targetUrl = const MovieRepository().streamUrl(widget.movieId);
      }

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

      _controller?.dispose();
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(targetUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      await _controller!.initialize();
      _controller!.addListener(_onPlayerUpdate);

      if (existingHistory != null && existingHistory.progressSeconds > 30) {
        await _controller!.seekTo(Duration(seconds: existingHistory.progressSeconds));
      }

      _controller!.play();

      _progressTimer?.cancel();
      _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) => _saveProgress());

      if (mounted) {
        setState(() => _loading = false);
        _resetHideTimer();
      }
    } catch (e) {
      // Fallback: If native playback throws source error and we have an http URL, try In-App WebView
      final videoPath = _movie?.videoPath?.trim() ?? '';
      if (videoPath.startsWith('http://') || videoPath.startsWith('https://')) {
        _setupWebView(videoPath);
      } else {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Could not load video stream. Please verify the video link or format.';
          });
        }
      }
    }
  }

  void _setupWebView(String url) {
    setState(() {
      _isWebViewMode = true;
      _webViewLoading = true;
      _loading = false;
    });

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36")
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _webViewLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _webViewLoading = false);
            // Hide all Diskwala website elements, logos, cards and present ONLY full-screen video
            _webViewController?.runJavaScript('''
              (function() {
                function cleanAndStream() {
                  try {
                    if (!document.getElementById('maya-cinema-style')) {
                      var style = document.createElement('style');
                      style.id = 'maya-cinema-style';
                      style.innerHTML = `
                        body, html { background-color: #000000 !important; margin: 0 !important; padding: 0 !important; overflow: hidden !important; }
                        header, nav, footer, .navbar, .header, .logo, .ad, .ads, .banner, h1, h2, h3, p, span, div[class*="Header"], div[class*="Navbar"], div[class*="Logo"], div[class*="Card"], div[class*="card"] { display: none !important; }
                        video { position: fixed !important; top: 0 !important; left: 0 !important; width: 100vw !important; height: 100vh !important; object-fit: contain !important; background: #000000 !important; z-index: 9999999 !important; display: block !important; }
                      `;
                      document.head.appendChild(style);
                    }

                    // Trigger click on play/video containers
                    var clickables = document.querySelectorAll('button, div[role="button"], svg, video');
                    for (var i = 0; i < clickables.length; i++) {
                      try { clickables[i].click(); } catch(e){}
                    }

                    var v = document.querySelector('video');
                    if (v) {
                      v.style.display = 'block';
                      v.play().catch(function(){});
                    }
                  } catch(e) {}
                }

                cleanAndStream();
                setInterval(cleanAndStream, 500);
              })();
            ''');
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    _webViewController = controller;
  }

  void _onPlayerUpdate() {
    if (mounted) setState(() {});
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      final dur = c.value.duration;
      final pos = c.value.position;
      if (dur.inSeconds > 0 && dur.inSeconds - pos.inSeconds < 60) {
        _saveProgress();
      }
    }
  }

  Future<void> _saveProgress() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final dur = c.value.duration.inSeconds;
    final pos = c.value.position.inSeconds;
    if (pos > 5) {
      try {
        await const MovieRepository().saveProgress(
          widget.movieId,
          pos,
          dur > 0 ? dur : null,
        );
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _saveProgress();
    _hideControlsTimer?.cancel();
    _progressTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    _controller?.removeListener(_onPlayerUpdate);
    _controller?.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _resetHideTimer() {
    _hideControlsTimer?.cancel();
    if (_showControls) {
      _hideControlsTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && (_controller?.value.isPlaying ?? false)) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _resetHideTimer();
  }

  void _togglePlayPause() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
      setState(() => _showControls = true);
      _hideControlsTimer?.cancel();
    } else {
      c.play();
      _resetHideTimer();
    }
    setState(() {});
  }

  void _seekBy(int seconds) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final current = c.value.position;
    final total = c.value.duration;
    final target = current + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : target > total
            ? total
            : target;
    c.seekTo(clamped);
    _resetHideTimer();
  }

  void _onDoubleTapSeek(bool isForward) {
    final delta = isForward ? 10 : -10;
    _seekBy(delta);

    setState(() {
      _isSeekFeedbackForward = isForward;
      _seekFeedbackSeconds = (_showSeekFeedback && _isSeekFeedbackForward == isForward)
          ? _seekFeedbackSeconds + 10
          : 10;
      _showSeekFeedback = true;
    });

    _seekFeedbackTimer?.cancel();
    _seekFeedbackTimer = Timer(const Duration(milliseconds: 900), () {
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

  void _setQuality(String quality) {
    setState(() => _selectedQuality = quality);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Quality switched to $quality'),
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

  void _openQualityModal() {
    _resetHideTimer();
    showModalBottomSheet(
      context: context,
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
                const Icon(Icons.hd_outlined, color: _playerAccent, size: 22),
                const SizedBox(width: 10),
                const Text('Video Quality', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(color: Colors.white24),
            ..._qualities.map((q) {
              final isSel = _selectedQuality == q;
              return ListTile(
                dense: true,
                leading: Icon(
                  isSel ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isSel ? _playerAccent : Colors.white54,
                  size: 20,
                ),
                title: Text(
                  q,
                  style: TextStyle(
                    color: isSel ? _playerAccent : Colors.white,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _setQuality(q);
                },
              );
            }),
          ],
        ),
      ),
    );
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

                  // 1. Quality Selection
                  const Text(
                    'VIDEO QUALITY',
                    style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _qualities.map((q) {
                        final isSel = _selectedQuality == q;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              q,
                              style: TextStyle(
                                color: isSel ? Colors.black : Colors.white,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            selected: isSel,
                            selectedColor: _playerAccent,
                            backgroundColor: const Color(0xFF282828),
                            onSelected: (_) {
                              _setQuality(q);
                              setSheetState(() {});
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Playback Speed
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

                  // 3. Aspect Ratio
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
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _saveProgress();
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(MayaRoutes.home);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _playerAccent))
            : _isWebViewMode
                ? _buildWebViewPlayer()
                : _error != null
                    ? _buildErrorView()
                    : _buildPlayerView(),
      ),
    );
  }

  // ── IN-APP WEBSTREAM PLAYER VIEW ──────────────────────────────────────────
  Widget _buildWebViewPlayer() {
    return Stack(
      children: [
        if (_webViewController != null)
          WebViewWidget(controller: _webViewController!),
        if (_webViewLoading)
          const Center(
            child: CircularProgressIndicator(color: _playerAccent),
          ),
        // Floating circular Back button on top-left
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                  tooltip: 'Go Back',
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(MayaRoutes.home);
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MayaColors.error.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: MayaColors.error, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not play this video',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An unexpected streaming error occurred.',
              style: const TextStyle(color: Colors.white60, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    _saveProgress();
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(MayaRoutes.home);
                    }
                  },
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Go Back'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                ),
                const SizedBox(width: 14),
                ElevatedButton.icon(
                  onPressed: _initPlayer,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(backgroundColor: _playerAccent, foregroundColor: Colors.black),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerView() {
    final c = _controller!;
    final position = c.value.position;
    final duration = c.value.duration;
    final isPlaying = c.value.isPlaying;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── 1. Video Surface ───────────────────────────────────────────────
        GestureDetector(
          onTap: _toggleControls,
          behavior: HitTestBehavior.opaque,
          child: _buildVideoView(c),
        ),

        // ── 2. Double-tap Seek Gesture Zones (Left = -10s, Right = +10s) ───
        Positioned.fill(
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: () => _onDoubleTapSeek(false),
                  onTap: _toggleControls,
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: () => _onDoubleTapSeek(true),
                  onTap: _toggleControls,
                ),
              ),
            ],
          ),
        ),

        // ── 3. Animated Double-tap Seek Indicator Overlay ─────────────────
        if (_showSeekFeedback)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: _playerAccent.withOpacity(0.6), width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isSeekFeedbackForward ? Icons.fast_forward : Icons.fast_rewind,
                    color: _playerAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_isSeekFeedbackForward ? '+' : '-'}$_seekFeedbackSeconds sec',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

        // ── 4. Full Overlay Cinema Controls ────────────────────────────────
        IgnorePointer(
          ignoring: !_showControls,
          child: AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.75),
                    Colors.transparent,
                    Colors.black.withOpacity(0.85),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              child: Column(
                children: [
                  // ── TOP BAR ───────────────────────────────────────────────
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                            onPressed: () {
                              _saveProgress();
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go(MayaRoutes.home);
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _movie?.title ?? 'MAYA Cinema',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Quality badge button
                          InkWell(
                            onTap: _openQualityModal,
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _playerAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: _playerAccent.withOpacity(0.6)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _selectedQuality,
                                    style: const TextStyle(
                                      color: _playerAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down, color: _playerAccent, size: 14),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // ── CENTER PLAY / PAUSE BUTTON ────────────────────────────
                  IconButton(
                    iconSize: 64,
                    icon: Icon(
                      isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: _playerAccent,
                    ),
                    onPressed: _togglePlayPause,
                  ),

                  const Spacer(),

                  // ── BOTTOM CONTROL BAR ────────────────────────────────────
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Cyan Seekbar
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: _playerAccent,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: _playerAccent,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayColor: _playerAccent.withOpacity(0.2),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: duration.inMilliseconds > 0
                                  ? position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble()
                                  : 0.0,
                              max: duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0,
                              onChanged: (v) {
                                c.seekTo(Duration(milliseconds: v.toInt()));
                                _resetHideTimer();
                              },
                            ),
                          ),

                          // 2. Control Icons Row
                          Row(
                            children: [
                              // Play / Pause
                              _PlayerIconButton(
                                icon: isPlaying ? Icons.pause : Icons.play_arrow,
                                color: _playerAccent,
                                size: 24,
                                onTap: _togglePlayPause,
                              ),
                              const SizedBox(width: 14),

                              // Rewind 10s
                              _PlayerIconButton(
                                icon: Icons.replay_10,
                                color: _playerAccent,
                                size: 22,
                                onTap: () => _seekBy(-10),
                              ),
                              const SizedBox(width: 14),

                              // Forward 10s
                              _PlayerIconButton(
                                icon: Icons.forward_10,
                                color: _playerAccent,
                                size: 22,
                                onTap: () => _seekBy(10),
                              ),
                              const SizedBox(width: 14),

                              // Mute toggle
                              _PlayerIconButton(
                                icon: _isMuted ? Icons.volume_off : Icons.volume_up,
                                color: _playerAccent,
                                size: 22,
                                onTap: _toggleMute,
                              ),
                              const SizedBox(width: 14),

                              // Timestamp
                              Text(
                                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),

                              const Spacer(),

                              // CC / Subtitles
                              _PlayerIconButton(
                                icon: Icons.closed_caption_outlined,
                                color: _playerAccent,
                                size: 22,
                                onTap: _openSubtitlesModal,
                              ),
                              const SizedBox(width: 16),

                              // Quality selector
                              _PlayerIconButton(
                                icon: Icons.hd_outlined,
                                color: _playerAccent,
                                size: 22,
                                onTap: _openQualityModal,
                              ),
                              const SizedBox(width: 16),

                              // Settings
                              _PlayerIconButton(
                                icon: Icons.settings_outlined,
                                color: _playerAccent,
                                size: 21,
                                onTap: _openSettingsModal,
                              ),
                              const SizedBox(width: 16),

                              // Aspect Ratio
                              _PlayerIconButton(
                                icon: _fitMode.icon,
                                color: _playerAccent,
                                size: 21,
                                onTap: _toggleFitMode,
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

  Widget _buildVideoView(VideoPlayerController c) {
    if (!c.value.isInitialized) return const SizedBox.shrink();

    if (_fitMode == VideoFitMode.contain) {
      return Center(
        child: AspectRatio(
          aspectRatio: c.value.aspectRatio,
          child: VideoPlayer(c),
        ),
      );
    } else if (_fitMode == VideoFitMode.cover) {
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
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: color, size: size),
      ),
    );
  }
}
