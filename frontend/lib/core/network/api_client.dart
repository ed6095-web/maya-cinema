// MAYA — Dio API Client
// Configured with auth token injection, timeout, and error interceptor.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:maya_app/core/constants/api_constants.dart';
import 'package:maya_app/core/storage/secure_storage.dart';

/// Singleton Dio instance used across all API calls.
final Dio apiClient = _buildDio();

Dio _buildDio() {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ),
  );

  dio.interceptors.addAll([
    _AuthInterceptor(),
    if (kDebugMode) LogInterceptor(requestBody: false, responseBody: false),
  ]);

  return dio;
}

/// Injects the JWT Bearer token from secure storage into every request.
class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await MayaSecureStorage.readToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Let the caller decide how to handle errors — don't swallow them here.
    handler.next(err);
  }
}

/// Helper to extract a user-friendly error message from a Dio exception.
String extractErrorMessage(DioException e) {
  if (e.response?.data is Map) {
    final detail = e.response!.data['detail'];
    if (detail is String) return detail;
    if (detail is List && detail.isNotEmpty) {
      return detail.map((d) => d['msg'] ?? d.toString()).join(', ');
    }
  }
  return switch (e.type) {
    DioExceptionType.connectionTimeout => 'Connection timed out. Check your network.',
    DioExceptionType.receiveTimeout => 'Server took too long to respond.',
    DioExceptionType.connectionError => 'Cannot reach the server. Is the backend running?',
    DioExceptionType.badResponse => 'Server error (${e.response?.statusCode})',
    _ => e.message ?? 'An unexpected error occurred.',
  };
}
