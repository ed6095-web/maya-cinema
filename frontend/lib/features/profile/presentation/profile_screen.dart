// MAYA — Profile Screen
// Includes: Watching stats, Movie Request feature (eashandarsh77@gmail.com),
// Permanent Admin Access portal with Admin PIN/Password unlock, and Account actions.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maya_app/app/router.dart';
import 'package:maya_app/app/theme.dart';
import 'package:maya_app/core/network/api_client.dart';
import 'package:maya_app/features/auth/domain/auth_provider.dart';
import 'package:maya_app/features/movies/domain/movie_providers.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final favCount = ref.watch(favoritesProvider).value?.length ?? 0;
    final historyEntries = ref.watch(historyProvider).value ?? [];
    final watchedCount = historyEntries.length;
    final completedCount = historyEntries.where((h) => h.completed).length;
    final totalSeconds = historyEntries.fold<int>(0, (sum, h) => sum + h.progressSeconds);
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
                    width: 86,
                    height: 86,
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
                          fontSize: 34,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: MayaSpacing.md),
                Text(user.username, style: MayaTextStyles.titleLarge),
                const SizedBox(height: 4),
                Text(user.email, style: MayaTextStyles.bodyMedium),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: user.isAdmin ? MayaColors.accentSubtle : MayaColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: user.isAdmin ? MayaColors.accentDim : MayaColors.border),
                  ),
                  child: Text(
                    user.isAdmin ? 'ADMINISTRATOR' : 'MEMBER',
                    style: MayaTextStyles.accentLabel.copyWith(
                      color: user.isAdmin ? MayaColors.accent : MayaColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: MayaSpacing.xl),

          // ── Watching stats ─────────────────────────────────────────────
          Text('Your Stats', style: MayaTextStyles.titleSmall),
          const SizedBox(height: MayaSpacing.md),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.movie_outlined,
                  value: '$watchedCount',
                  label: 'Started',
                ),
              ),
              const SizedBox(width: MayaSpacing.sm),
              Expanded(
                child: _StatTile(
                  icon: Icons.check_circle_outline,
                  value: '$completedCount',
                  label: 'Completed',
                ),
              ),
              const SizedBox(width: MayaSpacing.sm),
              Expanded(
                child: _StatTile(
                  icon: Icons.bookmark_outline,
                  value: '$favCount',
                  label: 'My List',
                ),
              ),
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

          // ── Features & Requests ─────────────────────────────────────────
          Text('Features & Requests', style: MayaTextStyles.titleSmall),
          const SizedBox(height: MayaSpacing.sm),

          _ActionTile(
            icon: Icons.add_to_photos_outlined,
            label: 'Request a Movie',
            subtitle: 'Ask for movies to be added to MAYA',
            accent: true,
            onTap: () => _openRequestMovieSheet(context, user.username),
          ),

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

          const SizedBox(height: MayaSpacing.md),
          const Divider(color: MayaColors.border),
          const SizedBox(height: MayaSpacing.sm),

          // ── Admin Management ────────────────────────────────────────────
          Text('Admin Portal', style: MayaTextStyles.titleSmall),
          const SizedBox(height: MayaSpacing.sm),

          if (user.isAdmin) ...[
            _ActionTile(
              icon: Icons.dashboard_outlined,
              label: 'Admin Dashboard',
              subtitle: 'Upload movies, manage genres & users',
              onTap: () => context.push(MayaRoutes.admin),
              accent: true,
            ),
          ] else ...[
            _ActionTile(
              icon: Icons.admin_panel_settings_outlined,
              label: 'Unlock Admin Dashboard',
              subtitle: 'Enter Admin Password to manage movies',
              onTap: () => _openUnlockAdminDialog(context, ref),
              accent: true,
            ),
          ],

          const SizedBox(height: MayaSpacing.md),
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
              'MAYA · Personal Cinema · v1.0',
              style: MayaTextStyles.labelSmall,
            ),
          ),
          const SizedBox(height: MayaSpacing.lg),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Request a Movie Dialog
  // ──────────────────────────────────────────────────────────────────────────
  void _openRequestMovieSheet(BuildContext context, String username) {
    final titleCtrl = TextEditingController();
    final yearCtrl = TextEditingController();
    final aboutCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.movie_creation_outlined, color: MayaColors.accent, size: 24),
                    const SizedBox(width: 10),
                    Text('Request a Movie', style: MayaTextStyles.titleMedium),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: MayaColors.textMuted, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Text(
                  'Your request will be sent to eashandarsh77@gmail.com',
                  style: MayaTextStyles.bodySmall.copyWith(color: MayaColors.accentDim),
                ),
                const Divider(color: MayaColors.border, height: 24),

                // Movie Name
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Movie Name *',
                    hintText: 'e.g. Interstellar, Inception',
                    prefixIcon: Icon(Icons.movie, size: 18, color: MayaColors.accent),
                  ),
                ),
                const SizedBox(height: 14),

                // Year
                TextField(
                  controller: yearCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Release Year (Optional)',
                    hintText: 'e.g. 2024',
                    prefixIcon: Icon(Icons.calendar_today, size: 18, color: MayaColors.accent),
                  ),
                ),
                const SizedBox(height: 14),

                // About / Notes
                TextField(
                  controller: aboutCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'About / Notes / Links',
                    hintText: 'e.g. Hindi dubbed, 4K quality, IMDb link...',
                    prefixIcon: Icon(Icons.description, size: 18, color: MayaColors.accent),
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.email_outlined, size: 18),
                        label: const Text('Send Email'),
                        onPressed: () async {
                          final title = titleCtrl.text.trim();
                          final year = yearCtrl.text.trim();
                          final about = aboutCtrl.text.trim();
                          if (title.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a movie title')),
                            );
                            return;
                          }
                          final subject = Uri.encodeComponent('[MAYA Movie Request] $title ($year)');
                          final body = Uri.encodeComponent(
                            'Movie Title: $title\nRelease Year: $year\nAbout/Notes: $about\nRequested by: $username',
                          );
                          final uri = Uri.parse('mailto:eashandarsh77@gmail.com?subject=$subject&body=$body');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                            if (ctx.mounted) Navigator.pop(ctx);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.send, size: 18),
                        label: Text(isSubmitting ? 'Sending...' : 'Submit'),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final title = titleCtrl.text.trim();
                                if (title.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter a movie title')),
                                  );
                                  return;
                                }
                                setModalState(() => isSubmitting = true);
                                try {
                                  await apiClient.post('/api/movies/request', data: {
                                    'title': title,
                                    'year': yearCtrl.text.trim(),
                                    'about': aboutCtrl.text.trim(),
                                  });
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Request for "$title" sent to eashandarsh77@gmail.com!'),
                                        backgroundColor: MayaColors.accent,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSubmitting = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error submitting request: $e')),
                                    );
                                  }
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Unlock Admin Dialog
  // ──────────────────────────────────────────────────────────────────────────
  void _openUnlockAdminDialog(BuildContext context, WidgetRef ref) {
    final keyCtrl = TextEditingController();
    bool isUnlocking = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF181818),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.lock_open, color: MayaColors.accent, size: 22),
              SizedBox(width: 10),
              Text('Admin Verification', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter Admin Password to gain full admin permissions and open the dashboard:',
                style: TextStyle(color: MayaColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: keyCtrl,
                obscureText: true,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Admin Password',
                  hintText: 'e.g. changeme123',
                  prefixIcon: Icon(Icons.key, color: MayaColors.accent, size: 18),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: MayaColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: isUnlocking
                  ? null
                  : () async {
                      final key = keyCtrl.text.trim();
                      if (key.isEmpty) return;
                      setDialogState(() => isUnlocking = true);

                      try {
                        await apiClient.post('/api/auth/unlock-admin', data: {'admin_key': key});
                        // Refresh auth profile
                        await ref.read(authProvider.notifier).refreshProfile();
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Admin access unlocked successfully!'),
                              backgroundColor: MayaColors.accent,
                            ),
                          );
                          context.push(MayaRoutes.admin);
                        }
                      } catch (e) {
                        setDialogState(() => isUnlocking = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Invalid Admin Password. Please try again.'),
                              backgroundColor: MayaColors.error,
                            ),
                          );
                        }
                      }
                    },
              child: isUnlocking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('Unlock'),
            ),
          ],
        ),
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
