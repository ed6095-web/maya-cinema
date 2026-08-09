// MAYA — Profile Screen
// Complete experience for both Guests and Admin (ed6095):
// - Editable Guest Name (stored in SharedPreferences)
// - Watch Stats (Started, Completed, My List, Duration)
// - Request a Movie feature (eashandarsh77@gmail.com)
// - Admin Portal Verification Dialog (empty username & password fields for total privacy)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maya_app/app/router.dart';
import 'package:maya_app/app/theme.dart';
import 'package:maya_app/features/auth/domain/auth_provider.dart';
import 'package:maya_app/features/movies/domain/movie_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _guestName = 'Guest Cinephile';

  @override
  void initState() {
    super.initState();
    _loadGuestName();
  }

  Future<void> _loadGuestName() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('guest_name');
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() => _guestName = saved);
    }
  }

  Future<void> _saveGuestName(String newName) async {
    if (newName.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('guest_name', newName.trim());
    if (mounted) setState(() => _guestName = newName.trim());
  }

  void _openEditNameDialog() {
    final ctrl = TextEditingController(text: _guestName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Display Name', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Your Name',
            hintText: 'e.g. Alex, Rahul',
            prefixIcon: Icon(Icons.person_outline, color: MayaColors.accent),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: MayaColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _saveGuestName(ctrl.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final favCount = ref.watch(favoritesProvider).value?.length ?? 0;
    final historyEntries = ref.watch(historyProvider).value ?? [];
    final watchedCount = historyEntries.length;
    final completedCount = historyEntries.where((h) => h.completed).length;
    final totalSeconds = historyEntries.fold<int>(0, (sum, h) => sum + h.progressSeconds);
    final totalHours = totalSeconds ~/ 3600;
    final totalMinutes = (totalSeconds % 3600) ~/ 60;

    final displayName = user != null ? user.username : _guestName;
    final displayEmail = user != null ? user.email : 'Guest Access · No login required';
    final isAdmin = user?.isAdmin ?? false;
    final initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'G';

    return Scaffold(
      backgroundColor: MayaColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: MayaColors.surface,
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: MayaColors.accent),
              tooltip: 'Admin Dashboard',
              onPressed: () => context.push(MayaRoutes.admin),
            )
          else
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined, color: MayaColors.accent),
              tooltip: 'Admin Portal',
              onPressed: () => _openAdminLoginDialog(context),
            ),
        ],
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(displayName, style: MayaTextStyles.titleLarge),
                    if (user == null) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: _openEditNameDialog,
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.edit_outlined, color: MayaColors.accent, size: 16),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(displayEmail, style: MayaTextStyles.bodyMedium.copyWith(color: MayaColors.textSecondary)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAdmin ? MayaColors.accentSubtle : MayaColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isAdmin ? MayaColors.accentDim : MayaColors.border),
                  ),
                  child: Text(
                    isAdmin ? 'ADMINISTRATOR' : (user != null ? 'MEMBER' : 'GUEST PASS'),
                    style: MayaTextStyles.accentLabel.copyWith(
                      color: isAdmin ? MayaColors.accent : MayaColors.textMuted,
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
            onTap: () => _openRequestMovieSheet(context, displayName),
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

          if (isAdmin) ...[
            _ActionTile(
              icon: Icons.dashboard_outlined,
              label: 'Admin Dashboard',
              subtitle: 'Upload movies, manage genres & library',
              onTap: () => context.push(MayaRoutes.admin),
              accent: true,
            ),
          ] else ...[
            _ActionTile(
              icon: Icons.admin_panel_settings_outlined,
              label: 'Unlock Admin Dashboard',
              subtitle: 'Log in with Owner Admin credentials to upload movies',
              onTap: () => _openAdminLoginDialog(context),
              accent: true,
            ),
          ],

          if (user != null) ...[
            const SizedBox(height: MayaSpacing.md),
            const Divider(color: MayaColors.border),
            const SizedBox(height: MayaSpacing.sm),

            // ── Account ───────────────────────────────────────────────────
            Text('Account', style: MayaTextStyles.titleSmall),
            const SizedBox(height: MayaSpacing.sm),
            _ActionTile(
              icon: Icons.logout,
              label: 'Sign Out Admin',
              subtitle: 'Switch back to guest access',
              onTap: () => ref.read(authProvider.notifier).logout(),
              isDestructive: true,
            ),
          ],

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
  // Request Movie Bottom Sheet
  // ──────────────────────────────────────────────────────────────────────────
  void _openRequestMovieSheet(BuildContext context, String requesterName) {
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
                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final name = titleCtrl.text.trim();
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a movie name'),
                                  backgroundColor: MayaColors.error,
                                ),
                              );
                              return;
                            }

                            setModalState(() => isSubmitting = true);

                            final year = yearCtrl.text.trim();
                            final about = aboutCtrl.text.trim();

                            final subject = Uri.encodeComponent('Movie Request: $name (${year.isNotEmpty ? year : "N/A"})');
                            final body = Uri.encodeComponent(
                              'Hello MAYA Admin,\n\n'
                              'I would like to request the following movie to be added to MAYA Cinema:\n\n'
                              '🎬 Movie Name: $name\n'
                              '📅 Release Year: ${year.isNotEmpty ? year : "Not specified"}\n'
                              '📝 Notes / Details: ${about.isNotEmpty ? about : "None"}\n'
                              '👤 Requested By: $requesterName\n\n'
                              'Thank you!',
                            );

                            final mailtoUri = Uri.parse('mailto:eashandarsh77@gmail.com?subject=$subject&body=$body');

                            try {
                              if (await canLaunchUrl(mailtoUri)) {
                                await launchUrl(mailtoUri);
                              }
                            } catch (_) {}

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Request prepared! Thank you for helping improve MAYA.'),
                                  backgroundColor: MayaColors.accent,
                                ),
                              );
                            }
                          },
                    child: isSubmitting
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send, size: 18),
                              SizedBox(width: 8),
                              Text('Send Request'),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Admin Login Dialog (Empty inputs for total privacy)
  // ──────────────────────────────────────────────────────────────────────────
  void _openAdminLoginDialog(BuildContext context) {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF181818),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.admin_panel_settings, color: MayaColors.accent, size: 24),
              SizedBox(width: 10),
              Text('Owner Admin Portal', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter Owner Admin credentials to upload and manage movies:',
                style: TextStyle(color: MayaColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: userCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Username or Email',
                  prefixIcon: Icon(Icons.person, color: MayaColors.accent, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock, color: MayaColors.accent, size: 18),
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
              onPressed: isLoading
                  ? null
                  : () async {
                      final u = userCtrl.text.trim();
                      final p = passCtrl.text.trim();
                      if (u.isEmpty || p.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter your username and password'),
                            backgroundColor: MayaColors.error,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isLoading = true);
                      try {
                        await ref.read(authProvider.notifier).login(u, p);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Admin access granted!'),
                              backgroundColor: MayaColors.accent,
                            ),
                          );
                          context.push(MayaRoutes.admin);
                        }
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Login failed: $e'),
                              backgroundColor: MayaColors.error,
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('Open Dashboard'),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDestructive
                    ? MayaColors.error.withOpacity(0.12)
                    : accent
                        ? MayaColors.accentSubtle
                        : MayaColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDestructive
                      ? MayaColors.error.withOpacity(0.4)
                      : accent
                          ? MayaColors.accentDim
                          : MayaColors.border,
                ),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: MayaSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: MayaTextStyles.bodyMedium.copyWith(
                      color: isDestructive ? MayaColors.error : MayaColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
