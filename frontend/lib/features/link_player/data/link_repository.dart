// MAYA — Link Player Repository
import 'package:dio/dio.dart';
import 'package:maya_app/core/constants/api_constants.dart';
import 'package:maya_app/core/network/api_client.dart';
import 'package:maya_app/features/link_player/data/models.dart';

class LinkRepository {
  const LinkRepository();

  /// Resolve a public/authorized video URL via MAYA backend link resolver.
  Future<LinkResolveResult> resolveLink(String url) async {
    try {
      final response = await apiClient.post(
        ApiConstants.resolveLink,
        data: {'url': url.trim()},
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return LinkResolveResult.fromJson(response.data as Map<String, dynamic>);
      }
      return const LinkResolveResult(
        success: false,
        error: 'Unexpected server response.',
        errorCode: 'SERVER_ERROR',
      );
    } on DioException catch (e) {
      if (e.response?.data is Map<String, dynamic>) {
        final data = e.response!.data as Map<String, dynamic>;
        return LinkResolveResult(
          success: false,
          error: data['detail']?.toString() ?? data['error']?.toString() ?? e.message,
          errorCode: data['error_code']?.toString() ?? 'NETWORK_ERROR',
        );
      }
      return const LinkResolveResult(
        success: false,
        error: 'Network connection failed. Please verify backend is running.',
        errorCode: 'NETWORK_ERROR',
      );
    } catch (e) {
      return LinkResolveResult(
        success: false,
        error: e.toString(),
        errorCode: 'UNKNOWN_ERROR',
      );
    }
  }

  /// Save an external media link to MAYA ("Add to MAYA")
  Future<ExternalMediaModel?> saveExternalMedia({
    required String title,
    required String sourceUrl,
    String? thumbnail,
    int? duration,
    String? provider,
    String? streamType,
    String? mediaType,
  }) async {
    try {
      final response = await apiClient.post(
        ApiConstants.externalMedia,
        data: {
          'title': title,
          'source_url': sourceUrl,
          'thumbnail': thumbnail,
          'duration': duration,
          'provider': provider,
          'stream_type': streamType,
          'media_type': mediaType,
        },
      );
      if (response.statusCode == 201 && response.data is Map<String, dynamic>) {
        return ExternalMediaModel.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  /// List saved external media
  Future<List<ExternalMediaModel>> getExternalMedia() async {
    try {
      final response = await apiClient.get(ApiConstants.externalMedia);
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((item) => ExternalMediaModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Delete saved external media
  Future<bool> deleteExternalMedia(int id) async {
    try {
      final response = await apiClient.delete(ApiConstants.externalMediaById(id));
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
