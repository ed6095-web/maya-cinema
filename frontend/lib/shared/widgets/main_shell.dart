// MAYA — Main Navigation Shell
// Wraps all primary tabs (Home, Search, Link Player, My List, Profile) with persistent
// bottom navigation on mobile and sidebar on desktop.
// Includes full tab-by-tab Android Back navigation history.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maya_app/app/router.dart';
import 'package:maya_app/app/theme.dart';
import 'package:maya_app/features/auth/domain/auth_provider.dart';

class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final List<int> _tabHistory = [0];

  void _onTabSelected(int index) {
    if (widget.navigationShell.currentIndex == index) {
      widget.navigationShell.goBranch(index, initialLocation: true);
      return;
    }

    setState(() {
      _tabHistory.remove(index);
      _tabHistory.add(index);
    });

    widget.navigationShell.goBranch(index, initialLocation: false);
  }

  void _handleBackPress() {
    if (_tabHistory.length > 1) {
      setState(() {
        _tabHistory.removeLast();
      });
      final previousTab = _tabHistory.last;
      widget.navigationShell.goBranch(previousTab, initialLocation: false);
    } else if (widget.navigationShell.currentIndex != 0) {
      setState(() {
        _tabHistory.clear();
        _tabHistory.add(0);
      });
      widget.navigationShell.goBranch(0, initialLocation: false);
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.isAdmin ?? false;
    final isWide = MediaQuery.of(context).size.width > 700;
    final currentIndex = widget.navigationShell.currentIndex;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: MayaColors.background,
        body: Row(
          children: [
            if (isWide)
              _MayaSidebar(
                isAdmin: isAdmin,
                currentIndex: currentIndex,
                onSelectTab: _onTabSelected,
              ),
            Expanded(child: widget.navigationShell),
          ],
        ),
        bottomNavigationBar: isWide
            ? null
            : Container(
                decoration: const BoxDecoration(
                  color: MayaColors.surface,
                  border: Border(top: BorderSide(color: MayaColors.border)),
                ),
                child: NavigationBar(
                  selectedIndex: currentIndex.clamp(0, 4),
                  onDestinationSelected: (i) => _onTabSelected(i),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.search),
                      label: 'Search',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.link_outlined),
                      selectedIcon: Icon(Icons.link, color: Color(0xFFD4AF37)),
                      label: 'Link Player',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.bookmark_border),
                      selectedIcon: Icon(Icons.bookmark),
                      label: 'My List',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ============================================================================
// Desktop Sidebar
// ============================================================================

class _MayaSidebar extends ConsumerWidget {
  final bool isAdmin;
  final int currentIndex;
  final ValueChanged<int> onSelectTab;

  const _MayaSidebar({
    required this.isAdmin,
    required this.currentIndex,
    required this.onSelectTab,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 220,
      color: MayaColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
            child: Row(
              children: [
                Image.asset('assets/images/maya_logo.jpg', width: 30, height: 30),
                const SizedBox(width: 10),
                Text(
                  'MAYA',
                  style: MayaTextStyles.logoText.copyWith(
                    fontSize: 16,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: MayaColors.border),
          const SizedBox(height: MayaSpacing.sm),

          _SidebarItem(
            icon: Icons.home_outlined,
            label: 'Home',
            isActive: currentIndex == 0,
            onTap: () => onSelectTab(0),
          ),
          _SidebarItem(
            icon: Icons.search,
            label: 'Search',
            isActive: currentIndex == 1,
            onTap: () => onSelectTab(1),
          ),
          _SidebarItem(
            icon: Icons.link,
            label: 'Link Player',
            isActive: currentIndex == 2,
            onTap: () => onSelectTab(2),
          ),
          _SidebarItem(
            icon: Icons.bookmark_border,
            label: 'My List',
            isActive: currentIndex == 3,
            onTap: () => onSelectTab(3),
          ),
          _SidebarItem(
            icon: Icons.person_outline,
            label: 'Profile',
            isActive: currentIndex == 4,
            onTap: () => onSelectTab(4),
          ),

          if (isAdmin) ...[
            const SizedBox(height: MayaSpacing.md),
            const Divider(color: MayaColors.border),
            const SizedBox(height: MayaSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text('ADMIN', style: MayaTextStyles.accentLabel),
            ),
            _SidebarItem(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              isActive: false,
              onTap: () => context.push(MayaRoutes.admin),
            ),
          ],

          const Spacer(),
          const Divider(color: MayaColors.border),
          _SidebarItem(
            icon: Icons.logout,
            label: 'Sign Out',
            isActive: false,
            onTap: () => ref.read(authProvider.notifier).logout(),
          ),
          const SizedBox(height: MayaSpacing.md),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? MayaColors.accentSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? MayaColors.accent : MayaColors.textMuted,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: MayaTextStyles.bodyMedium.copyWith(
                color: isActive ? MayaColors.accent : MayaColors.textSecondary,
                fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
