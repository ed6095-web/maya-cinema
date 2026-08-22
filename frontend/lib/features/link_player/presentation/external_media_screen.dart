// MAYA — Saved External Media Library Screen

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maya_app/app/router.dart';
import 'package:maya_app/app/theme.dart';
import 'package:maya_app/features/link_player/data/models.dart';
import 'package:maya_app/features/link_player/domain/link_providers.dart';
import 'package:maya_app/shared/widgets/maya_empty_state.dart';
import 'package:maya_app/shared/widgets/maya_error_retry.dart';
import 'package:maya_app/shared/widgets/maya_loading.dart';

class ExternalMediaScreen extends ConsumerWidget {
  const ExternalMediaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(externalMediaProvider);

    return Scaffold(
      backgroundColor: MayaColors.background,
      appBar: AppBar(
        backgroundColor: MayaColors.background,
        title: const Text(
          'Saved External Media',
          style: TextStyle(
            color: MayaColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Add Link',
            icon: const Icon(Icons.add_link, color: Color(0xFFD4AF37)),
            onPressed: () => context.push(MayaRoutes.linkPlayer),
          ),
        ],
      ),
      body: mediaAsync.when(
        loading: () => const MayaLoading(message: 'Loading saved media...'),
        error: (err, _) => MayaErrorRetry(
          error: err,
          customMessage: 'Failed to load external media.',
          onRetry: () => ref.read(externalMediaProvider.notifier).refresh(),
        ),
        data: (items) {
          if (items.isEmpty) {
            return MayaEmptyState(
              icon: Icons.link_off,
              title: 'No External Media Saved',
              message: 'Paste a video URL in the Link Player and select "Add to MAYA" to save it here.',
              actionLabel: 'Open Link Player',
              onAction: () => context.push(MayaRoutes.linkPlayer),
            );
          }

          return RefreshIndicator(
            color: const Color(0xFFD4AF37),
            backgroundColor: MayaColors.surface,
            onRefresh: () => ref.read(externalMediaProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final item = items[i];
                return _buildMediaTile(context, ref, item);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMediaTile(BuildContext context, WidgetRef ref, ExternalMediaModel item) {
    final streamType = (item.streamType ?? 'DIRECT').toUpperCase();
    final provider = item.provider ?? 'External';

    return Container(
      decoration: BoxDecoration(
        color: MayaColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MayaColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37).withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
          ),
          child: const Icon(Icons.play_circle_outline, color: Color(0xFFD4AF37), size: 26),
        ),
        title: Text(
          item.title,
          style: const TextStyle(
            color: MayaColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  streamType,
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  provider,
                  style: const TextStyle(color: MayaColors.textMuted, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow, color: Color(0xFFD4AF37)),
              tooltip: 'Play',
              onPressed: () {
                context.push(
                  MayaRoutes.player,
                  extra: {
                    'directUrl': item.sourceUrl,
                    'title': item.title,
                    'streamType': item.streamType ?? 'direct',
                  },
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: MayaColors.textMuted, size: 20),
              tooltip: 'Delete',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: MayaColors.surface,
                    title: const Text('Delete Link', style: TextStyle(color: Colors.white)),
                    content: Text(
                      'Remove "${item.title}" from saved media?',
                      style: const TextStyle(color: MayaColors.textSecondary),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete', style: TextStyle(color: MayaColors.error)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  ref.read(externalMediaProvider.notifier).delete(item.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
