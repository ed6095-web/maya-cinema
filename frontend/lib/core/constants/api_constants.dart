// MAYA — API Constants
// Dynamically routes to localhost on Web/Desktop and your Wi-Fi LAN IP on physical phones.

import 'package:flutter/foundation.dart';

class ApiConstants {
  ApiConstants._();

  // -------------------------------------------------------------------------
  // Base URLs:
  // Your computer's current Wi-Fi IP address is: 10.77.125.112
  // -------------------------------------------------------------------------
  static const String hostIp = '10.77.125.112';

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    // Physical mobile device / Android APK connects via host PC Wi-Fi IP
    return 'http://$hostIp:8000';
  }

  // -------------------------------------------------------------------------
  // Auth
  // -------------------------------------------------------------------------
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String me = '/api/auth/me';

  // -------------------------------------------------------------------------
  // Movies
  // -------------------------------------------------------------------------
  static const String movies = '/api/movies';
  static String movieById(int id) => '/api/movies/$id';
  static String movieStream(int id) => '/api/movies/$id/stream';
  static String moviePoster(int id) => '/api/movies/$id/poster';

  // -------------------------------------------------------------------------
  // Favorites
  // -------------------------------------------------------------------------
  static const String favorites = '/api/favorites';
  static String favoriteById(int movieId) => '/api/favorites/$movieId';

  // -------------------------------------------------------------------------
  // History
  // -------------------------------------------------------------------------
  static const String history = '/api/history';
  static String historyProgress(int movieId) => '/api/history/$movieId/progress';
  static String historyById(int movieId) => '/api/history/$movieId';

  // -------------------------------------------------------------------------
  // Genres
  // -------------------------------------------------------------------------
  static const String genres = '/api/genres';
  static String genreById(int id) => '/api/genres/$id';

  // -------------------------------------------------------------------------
  // Admin
  // -------------------------------------------------------------------------
  static const String adminStats = '/api/admin/stats';
  static const String adminUsers = '/api/admin/users';
  static String adminToggleUser(int userId) => '/api/admin/users/$userId/toggle-active';

  // -------------------------------------------------------------------------
  // Health
  // -------------------------------------------------------------------------
  static const String health = '/api/health';

  // -------------------------------------------------------------------------
  // Misc
  // -------------------------------------------------------------------------
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(minutes: 10);
}
