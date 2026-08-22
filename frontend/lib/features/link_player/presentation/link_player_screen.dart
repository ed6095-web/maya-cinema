// MAYA — Dedicated Link Player Screen
// Resolves and plays public/authorized media URLs via MAYA backend resolver.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maya_app/app/router.dart';
import 'package:maya_app/app/theme.dart';
import 'package:maya_app/features/link_player/data/models.dart';
import 'package:maya_app/features/link_player/domain/link_providers.dart';

class LinkPlayerScreen extends ConsumerStatefulWidget {
  const LinkPlayerScreen({super.key});

  @override
  ConsumerState<LinkPlayerScreen> createState() => _LinkPlayerScreenState();
}

class _LinkPlayerScreenState extends ConsumerState<LinkPlayerScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isResolving = false;
  LinkResolveResult? _resolvedResult;
  String? _errorMessage;
  bool _isSaved = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _focusNode.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _urlController.text = data.text!.trim();
        _resolvedResult = null;
        _errorMessage = null;
      });
    }
  }

  Future<void> _handleResolve() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or paste a video URL.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _focusNode.unfocus();
    setState(() {
      _isResolving = true;
      _errorMessage = null;
      _resolvedResult = null;
      _isSaved = false;
    });

    try {
      final repo = ref.read(linkRepositoryProvider);
      final result = await repo.resolveLink(url);

      if (mounted) {
        setState(() {
          _isResolving = false;
          if (result.success) {
            _resolvedResult = result;
          } else {
            _errorMessage = result.error ?? 'Unable to resolve media from this link.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isResolving = false;
          _errorMessage = 'An error occurred while communicating with the resolver service.';
        });
      }
    }
  }

  void _playResolvedMedia(LinkResolveResult media) {
    final streamUrl = media.streamUrl;
    if (streamUrl == null || streamUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No playable stream URL available.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    context.push(
      MayaRoutes.player,
      extra: {
        'directUrl': streamUrl,
        'title': media.title ?? 'External Media',
        'streamType': media.streamType ?? 'direct',
      },
    );
  }

  Future<void> _saveToMaya(LinkResolveResult media) async {
    if (_isSaved) return;

    final success = await ref.read(externalMediaProvider.notifier).save(
          title: media.title ?? 'External Video',
          sourceUrl: media.sourceUrl ?? _urlController.text.trim(),
          thumbnail: media.thumbnail,
          duration: media.duration,
          provider: media.provider,
          streamType: media.streamType,
          mediaType: media.mediaType,
        );

    if (mounted && success) {
      setState(() => _isSaved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Added to MAYA Library!'),
          backgroundColor: Color(0xFFD4AF37),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MayaColors.background,
      appBar: AppBar(
        backgroundColor: MayaColors.background,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD4AF37), width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'MAYA',
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'LINK PLAYER',
              style: TextStyle(
                color: MayaColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Saved Links',
            icon: const Icon(Icons.bookmarks_outlined, color: Colors.white70),
            onPressed: () => context.push(MayaRoutes.externalMedia),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tagline / Header banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: MayaColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MayaColors.border),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.link, color: Color(0xFFD4AF37), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Universal Stream Resolver',
                        style: TextStyle(
                          color: MayaColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Paste any supported direct MP4/HLS link, Google Drive, or video host to stream directly inside MAYA.',
                    style: TextStyle(color: MayaColors.textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // URL Input Section
            const Text(
              'PASTE VIDEO URL',
              style: TextStyle(
                color: MayaColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: MayaColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _focusNode.hasFocus
                      ? const Color(0xFFD4AF37)
                      : MayaColors.border,
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      focusNode: _focusNode,
                      style: const TextStyle(color: MayaColors.textPrimary, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'https://example.com/video.mp4',
                        hintStyle: TextStyle(color: MayaColors.textMuted, fontSize: 13),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: InputBorder.none,
                      ),
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _handleResolve(),
                      onChanged: (_) {
                        if (_errorMessage != null || _resolvedResult != null) {
                          setState(() {
                            _errorMessage = null;
                            _resolvedResult = null;
                          });
                        }
                      },
                    ),
                  ),
                  if (_urlController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: MayaColors.textMuted),
                      onPressed: () {
                        _urlController.clear();
                        setState(() {
                          _resolvedResult = null;
                          _errorMessage = null;
                        });
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: _pasteFromClipboard,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF202020),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.paste, size: 14, color: Colors.white70),
                            SizedBox(width: 4),
                            Text(
                              'Paste',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // PLAY CTA Button
            ElevatedButton(
              onPressed: _isResolving ? null : _handleResolve,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: _isResolving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow_rounded, size: 22),
                        SizedBox(width: 6),
                        Text(
                          'PLAY NOW',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 24),

            // ── RESOLVING STATE ──────────────────────────────────────────────
            if (_isResolving) _buildResolvingState(),

            // ── ERROR STATE ──────────────────────────────────────────────────
            if (_errorMessage != null && !_isResolving) _buildErrorState(),

            // ── SUCCESSFUL RESOLUTION CARD ───────────────────────────────────
            if (_resolvedResult != null && !_isResolving)
              _buildResolvedMediaCard(_resolvedResult!),

            const SizedBox(height: 32),

            // ── SUPPORTED PROVIDERS GRID ─────────────────────────────────────
            _buildSupportedHostsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildResolvingState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: MayaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MayaColors.border),
      ),
      child: Column(
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4)),
              ),
              child: const Icon(
                Icons.remove_red_eye_outlined,
                color: Color(0xFFD4AF37),
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Preparing your video...',
            style: TextStyle(
              color: MayaColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Connecting to media resolver and verifying stream source',
            style: TextStyle(color: MayaColors.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MayaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MayaColors.error.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: MayaColors.error, size: 20),
              SizedBox(width: 8),
              Text(
                'Unable to play this link',
                style: TextStyle(
                  color: MayaColors.error,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _errorMessage ?? 'An error occurred.',
            style: const TextStyle(color: MayaColors.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _handleResolve,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('TRY AGAIN'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _urlController.clear();
                    setState(() {
                      _errorMessage = null;
                      _resolvedResult = null;
                    });
                    _focusNode.requestFocus();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD4AF37),
                    side: const BorderSide(color: Color(0xFFD4AF37)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('PASTE ANOTHER LINK'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResolvedMediaCard(LinkResolveResult media) {
    final streamTypeLabel = (media.streamType ?? 'DIRECT').toUpperCase();
    final providerLabel = media.provider ?? 'Standard Provider';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MayaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.6)),
                ),
                child: Text(
                  streamTypeLabel,
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  providerLabel,
                  style: const TextStyle(color: MayaColors.textSecondary, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            media.title ?? 'External Media',
            style: const TextStyle(
              color: MayaColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            media.sourceUrl ?? _urlController.text,
            style: const TextStyle(color: MayaColors.textMuted, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => _playResolvedMedia(media),
                  icon: const Icon(Icons.play_arrow, size: 20),
                  label: const Text('PLAY NOW', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: _isSaved ? null : () => _saveToMaya(media),
                  icon: Icon(
                    _isSaved ? Icons.check : Icons.bookmark_add_outlined,
                    size: 18,
                    color: _isSaved ? const Color(0xFFD4AF37) : Colors.white70,
                  ),
                  label: Text(
                    _isSaved ? 'SAVED' : 'ADD TO MAYA',
                    style: TextStyle(
                      color: _isSaved ? const Color(0xFFD4AF37) : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _isSaved ? const Color(0xFFD4AF37) : Colors.white24,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSupportedHostsSection() {
    final hosts = [
      {'name': 'Direct MP4 / MKV', 'icon': Icons.movie_outlined, 'desc': 'Native cinema player'},
      {'name': 'HLS (.m3u8)', 'icon': Icons.live_tv_outlined, 'desc': 'Adaptive live stream'},
      {'name': 'Google Drive', 'icon': Icons.cloud_outlined, 'desc': 'Share link streaming'},
      {'name': 'MixDrop / Streamtape', 'icon': Icons.video_collection_outlined, 'desc': 'Embed player'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SUPPORTED SOURCES',
          style: TextStyle(
            color: MayaColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.3,
          ),
          itemCount: hosts.length,
          itemBuilder: (ctx, i) {
            final h = hosts[i];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MayaColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MayaColors.border),
              ),
              child: Row(
                children: [
                  Icon(h['icon'] as IconData, size: 22, color: const Color(0xFFD4AF37)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          h['name'] as String,
                          style: const TextStyle(
                            color: MayaColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          h['desc'] as String,
                          style: const TextStyle(color: MayaColors.textMuted, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
