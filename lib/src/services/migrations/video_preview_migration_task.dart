import 'package:hive/hive.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/services/migrations/migration_task.dart';
import 'package:photographers_reference_app/src/utils/video_preview_migration.dart';

class VideoPreviewMigrationTask implements MigrationTask {
  VideoPreviewMigrationTask({
    required this.photoBox,
    this.enabled = false,
  });

  final Box<Photo> photoBox;

  @override
  final bool enabled;

  @override
  String get id => 'video_preview_migration';

  @override
  String get title => 'Rebuilding video previews';

  @override
  Future<int> getPendingCount() async {
    if (!enabled) return 0;
    var total = 0;
    for (final photo in photoBox.values) {
      if (photo.mediaType == 'video') {
        total++;
      }
    }
    return total;
  }

  @override
  Future<int> run({
    required int total,
    required void Function(int current) onProgress,
  }) async {
    if (!enabled || total <= 0) return 0;
    return VideoPreviewMigration.run(
      photoBox,
      onProgress: (current, _) {
        onProgress(current);
      },
    );
  }
}
