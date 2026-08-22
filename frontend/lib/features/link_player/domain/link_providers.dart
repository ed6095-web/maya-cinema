// MAYA — Link Player Providers
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maya_app/features/link_player/data/link_repository.dart';
import 'package:maya_app/features/link_player/data/models.dart';

final linkRepositoryProvider = Provider<LinkRepository>((ref) {
  return const LinkRepository();
});

// External media list provider
final externalMediaProvider =
    AsyncNotifierProvider<ExternalMediaNotifier, List<ExternalMediaModel>>(
  ExternalMediaNotifier.new,
);

class ExternalMediaNotifier extends AsyncNotifier<List<ExternalMediaModel>> {
  @override
  Future<List<ExternalMediaModel>> build() async {
    return ref.read(linkRepositoryProvider).getExternalMedia();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(linkRepositoryProvider).getExternalMedia(),
    );
  }

  Future<bool> save({
    required String title,
    required String sourceUrl,
    String? thumbnail,
    int? duration,
    String? provider,
    String? streamType,
    String? mediaType,
  }) async {
    final item = await ref.read(linkRepositoryProvider).saveExternalMedia(
          title: title,
          sourceUrl: sourceUrl,
          thumbnail: thumbnail,
          duration: duration,
          provider: provider,
          streamType: streamType,
          mediaType: mediaType,
        );
    if (item != null) {
      await refresh();
      return true;
    }
    return false;
  }

  Future<bool> delete(int id) async {
    final success = await ref.read(linkRepositoryProvider).deleteExternalMedia(id);
    if (success) {
      await refresh();
    }
    return success;
  }
}
