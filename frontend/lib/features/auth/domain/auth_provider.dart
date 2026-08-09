// MAYA — Auth Riverpod Provider & State
// Manages login, logout, and current user across the app.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maya_app/core/storage/secure_storage.dart';
import 'package:maya_app/features/auth/data/auth_repository.dart';
import 'package:maya_app/features/movies/data/models.dart';

// ============================================================================
// State
// ============================================================================

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final UserModel user;
  const AuthAuthenticated(this.user);
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}

// ============================================================================
// Notifier
// ============================================================================

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthInitial());

  final _repo = const AuthRepository();

  /// Called on app start — checks for existing token.
  Future<void> checkAuth() async {
    state = const AuthLoading();
    final hasToken = await MayaSecureStorage.hasToken();
    if (!hasToken) {
      state = const AuthUnauthenticated();
      return;
    }
    try {
      final user = await _repo.getMe();
      state = AuthAuthenticated(user);
    } catch (_) {
      await MayaSecureStorage.deleteToken();
      state = const AuthUnauthenticated();
    }
  }

  Future<void> login(String username, String password) async {
    state = const AuthLoading();
    try {
      final user = await _repo.login(username, password);
      state = AuthAuthenticated(user);
    } catch (e) {
      state = AuthError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthUnauthenticated();
  }

  UserModel? get currentUser =>
      state is AuthAuthenticated ? (state as AuthAuthenticated).user : null;

  bool get isAdmin => currentUser?.isAdmin ?? false;
}

// ============================================================================
// Providers
// ============================================================================

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

/// Convenience provider: returns the current user or null.
final currentUserProvider = Provider<UserModel?>((ref) {
  final auth = ref.watch(authProvider);
  return auth is AuthAuthenticated ? auth.user : null;
});

/// Convenience provider: true if user is authenticated admin.
final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider)?.isAdmin ?? false;
});
