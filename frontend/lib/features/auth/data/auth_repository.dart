// MAYA — Auth Repository
// All authentication API calls in one place.

import 'package:dio/dio.dart';
import 'package:maya_app/core/constants/api_constants.dart';
import 'package:maya_app/core/network/api_client.dart';
import 'package:maya_app/core/storage/secure_storage.dart';
import 'package:maya_app/features/movies/data/models.dart';

class AuthRepository {
  const AuthRepository();

  /// Login with username + password.
  /// Saves the JWT token on success, returns the user profile.
  Future<UserModel> login(String username, String password) async {
    try {
      final response = await apiClient.post(
        ApiConstants.login,
        data: {'username': username, 'password': password},
      );
      final token = response.data['access_token'] as String;
      await MayaSecureStorage.saveToken(token);

      // Fetch full user profile
      return await getMe();
    } on DioException catch (e) {
      throw Exception(extractErrorMessage(e));
    }
  }

  /// Fetch the current authenticated user's profile.
  Future<UserModel> getMe() async {
    try {
      final response = await apiClient.get(ApiConstants.me);
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(extractErrorMessage(e));
    }
  }

  /// Register a new user account.
  Future<UserModel> register(String username, String email, String password) async {
    try {
      final response = await apiClient.post(
        ApiConstants.register,
        data: {'username': username, 'email': email, 'password': password},
      );
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(extractErrorMessage(e));
    }
  }

  /// Logout — deletes the stored token.
  Future<void> logout() async {
    await MayaSecureStorage.deleteToken();
  }
}
