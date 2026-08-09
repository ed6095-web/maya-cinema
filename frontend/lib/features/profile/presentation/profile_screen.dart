// MAYA — Profile Screen (Phase 5 — full stats + actions)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maya_app/app/router.dart';
import 'package:maya_app/app/theme.dart';
import 'package:maya_app/features/auth/domain/auth_provider.dart';
import 'package:maya_app/features/movies/domain/movie_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final favCount = ref.watch(favoritesProvider).value?.length ?? 0;
    final historyEntries = ref.watch(historyProvider).value ?? [];
    final watchedCount = historyEntries.length;
    final completedCount = historyEntries.where((h) => h.completed).length;
    final totalSeconds = historyEntries.fold<int>(
      0, (sum, h) => sum + h.progressSeconds);
    final totalHours = totalSeconds ~/ 3600;
    final totalMinutes = (totalSeconds % 3600) ~/ 60;

    if (user == null) return const Scaffold(backgroundColor: MayaColors.background);

    final initials = user.username.isNotEmpty ? user.username[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: MayaColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: MayaColors.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(MayaSpacing.lg),
        children: [

          // ── Avatar + Identity ──────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Hero(
                  tag: 'profile-avatar',
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MayaColors.accentSubtle,
                      border: Border.all(color: MayaColors.accentDim, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: MayaTextStyles.displayLarge.copyWith(
                          color: MayaColors.accent,
                          fontSize: 36,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: MayaSpacing.md),
                Text(user.username, style: MayaTextStyles.titleLarge),
                const SizedBox(height: 4),
                Text(user.email, style: MayaTextStyles.bodyMedium),
                if (user.isAdmin) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: MayaColors.accentSubtle,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: MayaColors.accentDim),
                    ),
                    child: Text('ADMINISTRATOR', style: MayaTextStyles.accentLabel),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: MayaSpacing.xl),

          // ── Watching stats ─────────────────────────────────────────────
          Text('Your Stats', style: MayaTextStyles.titleSmall),
          const SizedBox(height: MayaSpacing.md),
          Row(
            children: [
              Expanded(child: _StatTile(
                icon: Icons.movie_outlined,
                value: '$watchedCount',
                label: 'Movies Started',
              )),
              const SizedBox(width: MayaSpacing.sm),
              Expanded(child: _StatTile(
                icon: Icons.check_circle_outline,
                value: '$completedCount',
                label: 'Completed',
              )),
              const SizedBox(width: MayaSpacing.sm),
              Expanded(child: _StatTile(
                icon: Icons.bookmark_outline,
                value: '$favCount',
                label: 'In My List',
              )),
            ],
          ),
          const SizedBox(height: MayaSpacing.sm),
          Container(
            padding: const EdgeInsets.all(MayaSpacing.md),
            decoration: BoxDecoration(
              color: MayaColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(MayaSpacing.cardRadius),
              border: Border.all(color: MayaColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_outlined, color: MayaColors.accent, size: 20),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      totalHours > 0
                          ? '${totalHours}h ${totalMinutes}m watched'
                          : '${totalMinutes}m watched',
                      style: MayaTextStyles.bodyMedium.copyWith(
                        color: MayaColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text('Total viewing time', style: MayaTextStyles.bodySmall),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: MayaSpacing.xl),
          const Divider(color: MayaColors.border),
          const SizedBox(height: MayaSpacing.sm),

          // ── Quick actions ──────────────────────────────────────────────
          Text('Library', style: MayaTextStyles.titleSmall),
          const SizedBox(height: MayaSpacing.sm),
          _ActionTile(
            icon: Icons.bookmark_outline,
            label: 'My List',
            subtitle: '$favCount saved movie${favCount == 1 ? '' : 's'}',
            onTap: () => context.go(MayaRoutes.favorites),
          ),
          _ActionTile(
            icon: Icons.history,
            label: 'Watch History',
            subtitle: '$watchedCount movie${watchedCount == 1 ? '' : 's'} watched',
            onTap: () => context.go(MayaRoutes.history),
          ),
          if (user.isAdmin) ...[
            const SizedBox(height: MayaSpacing.sm),
            const Divider(color: MayaColors.border),
            const SizedBox(height: MayaSpacing.sm),
            Text('Admin', style: MayaTextStyles.titleSmall),
            const SizedBox(height: MayaSpacing.sm),
            _ActionTile(
              icon: Icons.dashboard_outlined,
              label: 'Admin Dashboard',
              subtitle: 'Manage movies, users and genres',
              onTap: () => context.go(MayaRoutes.admin),
              accent: true,
            ),
          ],

          const SizedBox(height: MayaSpacing.sm),
          const Divider(color: MayaColors.border),
          const SizedBox(height: MayaSpacing.sm),

          // ── Account ────────────────────────────────────────────────────
          Text('Account', style: MayaTextStyles.titleSmall),
          const SizedBox(height: MayaSpacing.sm),
          _ActionTile(
            icon: Icons.logout,
            label: 'Sign Out',
            subtitle: 'Signed in as ${user.username}',
            onTap: () => ref.read(authProvider.notifier).logout(),
            isDestructive: true,
          ),
          const SizedBox(height: MayaSpacing.xxl),

          // Footer
          Center(
            child: Text(
              'MAYA · Private Media Platform · v1.0',
              style: MayaTextStyles.labelSmall,
            ),
          ),
          const SizedBox(height: MayaSpacing.lg),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Helper widgets
// ──────────────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatTile({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: MayaSpacing.md, horizontal: MayaSpacing.sm),
      decoration: BoxDecoration(
        color: MayaColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(MayaSpacing.cardRadius),
        border: Border.all(color: MayaColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: MayaColors.accent, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: MayaTextStyles.titleLarge.copyWith(color: MayaColors.accent, fontSize: 20)),
          const SizedBox(height: 2),
          Text(label,
              style: MayaTextStyles.labelSmall,
              textAlign: TextAlign.center,
              maxLines: 2),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool accent;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? MayaColors.error
        : accent
            ? MayaColors.accent
            : MayaColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MayaSpacing.cardRadius),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(
            horizontal: MayaSpacing.md, vertical: MayaSpacing.sm + 2),
        decoration: BoxDecoration(
          color: MayaColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(MayaSpacing.cardRadius),
          border: Border.all(
            color: isDestructive
                ? MayaColors.error.withOpacity(0.25)
                : accent
                    ? MayaColors.accentDim
                    : MayaColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: MayaSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: MayaTextStyles.bodyMedium.copyWith(
                          color: isDestructive || accent
                              ? color
                              : MayaColors.textPrimary,
                          fontWeight: FontWeight.w500)),
                  Text(subtitle, style: MayaTextStyles.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: MayaColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
