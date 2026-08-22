// MAYA — GoRouter Navigation Configuration
// Handles StatefulShellRoute for persistent tabs & tab-by-tab Android back navigation,
// protected routes, role-based redirects, and deep linking.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maya_app/features/auth/domain/auth_provider.dart';
import 'package:maya_app/features/auth/presentation/login_screen.dart';
import 'package:maya_app/features/auth/presentation/register_screen.dart';
import 'package:maya_app/features/home/presentation/home_screen.dart';
import 'package:maya_app/features/movies/presentation/movie_detail_screen.dart';
import 'package:maya_app/features/player/presentation/player_screen.dart';
import 'package:maya_app/features/search/presentation/search_screen.dart';
import 'package:maya_app/features/link_player/presentation/link_player_screen.dart';
import 'package:maya_app/features/link_player/presentation/external_media_screen.dart';
import 'package:maya_app/features/favorites/presentation/favorites_screen.dart';
import 'package:maya_app/features/history/presentation/history_screen.dart';
import 'package:maya_app/features/profile/presentation/profile_screen.dart';
import 'package:maya_app/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:maya_app/shared/widgets/main_shell.dart';

// ============================================================================
// Route Names
// ============================================================================

abstract class MayaRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/';
  static const String search = '/search';
  static const String linkPlayer = '/link-player';
  static const String favorites = '/favorites';
  static const String history = '/history';
  static const String externalMedia = '/external';
  static const String profile = '/profile';
  static const String movieDetail = '/movies/:id';
  static const String player = '/play';
  static const String moviePlayer = '/movies/:id/play';
  static const String admin = '/admin';

  static String movieDetailPath(int id) => '/movies/$id';
  static String playerPath(int id) => '/movies/$id/play';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorHomeKey = GlobalKey<NavigatorState>(debugLabel: 'shellHome');
final _shellNavigatorSearchKey = GlobalKey<NavigatorState>(debugLabel: 'shellSearch');
final _shellNavigatorLinkPlayerKey = GlobalKey<NavigatorState>(debugLabel: 'shellLinkPlayer');
final _shellNavigatorFavoritesKey = GlobalKey<NavigatorState>(debugLabel: 'shellFavorites');
final _shellNavigatorProfileKey = GlobalKey<NavigatorState>(debugLabel: 'shellProfile');

// ============================================================================
// Router Provider
// ============================================================================

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: MayaRoutes.home,
    debugLogDiagnostics: true,
    redirect: (context, state) => null,
    routes: [
      // ── Public Auth Routes ───────────────────────────────────────────────
      GoRoute(
        path: MayaRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: MayaRoutes.register,
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // ── Main Shell with 5 Persistent Tabs ────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          // Tab 0: Home
          StatefulShellBranch(
            navigatorKey: _shellNavigatorHomeKey,
            routes: [
              GoRoute(
                path: MayaRoutes.home,
                name: 'home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // Tab 1: Search
          StatefulShellBranch(
            navigatorKey: _shellNavigatorSearchKey,
            routes: [
              GoRoute(
                path: MayaRoutes.search,
                name: 'search',
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          // Tab 2: Link Player (Dedicated Feature)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorLinkPlayerKey,
            routes: [
              GoRoute(
                path: MayaRoutes.linkPlayer,
                name: 'link-player-tab',
                builder: (context, state) => const LinkPlayerScreen(),
              ),
            ],
          ),
          // Tab 3: Favorites / My List
          StatefulShellBranch(
            navigatorKey: _shellNavigatorFavoritesKey,
            routes: [
              GoRoute(
                path: MayaRoutes.favorites,
                name: 'favorites',
                builder: (context, state) => const FavoritesScreen(),
              ),
            ],
          ),
          // Tab 4: Profile
          StatefulShellBranch(
            navigatorKey: _shellNavigatorProfileKey,
            routes: [
              GoRoute(
                path: MayaRoutes.profile,
                name: 'profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Sub-Screens (Push over root navigation) ──────────────────────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: MayaRoutes.history,
        name: 'history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: MayaRoutes.externalMedia,
        name: 'external-media',
        builder: (context, state) => const ExternalMediaScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: MayaRoutes.movieDetail,
        name: 'movie-detail',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return MovieDetailScreen(movieId: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: MayaRoutes.moviePlayer,
        name: 'movie-player',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          return PlayerScreen(movieId: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: MayaRoutes.player,
        name: 'direct-player',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return PlayerScreen(
            directUrl: extra?['directUrl'] as String?,
            title: extra?['title'] as String?,
            streamType: extra?['streamType'] as String?,
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: MayaRoutes.admin,
        name: 'admin',
        redirect: (context, state) {
          if (authState is AuthAuthenticated && authState.user.isAdmin) return null;
          return MayaRoutes.home;
        },
        builder: (context, state) => const AdminDashboardScreen(),
      ),
    ],
    errorBuilder: (context, state) => const Scaffold(
      backgroundColor: Color(0xFF050505),
      body: Center(
        child: Text(
          'Page not found',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    ),
  );
});
