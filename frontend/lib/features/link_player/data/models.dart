// MAYA — Link Player & External Media Models

class LinkResolveResult {
  final bool success;
  final String? title;
  final String? thumbnail;
  final int? duration;
  final String? mediaType;
  final String? streamType; // 'direct' | 'hls' | 'dash' | 'embed'
  final String? streamUrl;
  final String? provider;
  final String? sourceUrl;
  final DateTime? expiresAt;
  final String? error;
  final String? errorCode;

  const LinkResolveResult({
    required this.success,
    this.title,
    this.thumbnail,
    this.duration,
    this.mediaType,
    this.streamType,
    this.streamUrl,
    this.provider,
    this.sourceUrl,
    this.expiresAt,
    this.error,
    this.errorCode,
  });

  factory LinkResolveResult.fromJson(Map<String, dynamic> json) {
    return LinkResolveResult(
      success: json['success'] as bool? ?? false,
      title: json['title'] as String?,
      thumbnail: json['thumbnail'] as String?,
      duration: json['duration'] as int?,
      mediaType: json['media_type'] as String?,
      streamType: json['stream_type'] as String?,
      streamUrl: json['stream_url'] as String?,
      provider: json['provider'] as String?,
      sourceUrl: json['source_url'] as String?,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      error: json['error'] as String?,
      errorCode: json['error_code'] as String?,
    );
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isEmbed => streamType == 'embed';
}

class ExternalMediaModel {
  final int id;
  final String title;
  final String? thumbnail;
  final int? duration;
  final String sourceUrl;
  final String? provider;
  final String? streamType;
  final String? mediaType;
  final DateTime createdAt;

  const ExternalMediaModel({
    required this.id,
    required this.title,
    this.thumbnail,
    this.duration,
    required this.sourceUrl,
    this.provider,
    this.streamType,
    this.mediaType,
    required this.createdAt,
  });

  factory ExternalMediaModel.fromJson(Map<String, dynamic> json) {
    return ExternalMediaModel(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'External Media',
      thumbnail: json['thumbnail'] as String?,
      duration: json['duration'] as int?,
      sourceUrl: json['source_url'] as String? ?? '',
      provider: json['provider'] as String?,
      streamType: json['stream_type'] as String?,
      mediaType: json['media_type'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
