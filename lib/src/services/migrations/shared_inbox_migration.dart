import 'package:photographers_reference_app/src/data/repositories/photo_repository_impl.dart';
import 'package:photographers_reference_app/src/services/migrations/migration_task.dart';
import 'package:photographers_reference_app/src/services/shared_inbox_import_service.dart';

class SharedInboxMigration implements MigrationTask {
  SharedInboxMigration({
    required this.photoRepository,
    SharedInboxImportService? service,
  }) : _service = service ?? SharedInboxImportService();

  final PhotoRepositoryImpl photoRepository;
  final SharedInboxImportService _service;

  List<Map<String, dynamic>> _manifest = const [];

  @override
  String get id => 'shared_inbox_import';

  @override
  String get title => 'Exporting shared items';

  @override
  bool get enabled => true;

  @override
  Future<int> getPendingCount() async {
    _manifest = await _service.loadManifest();
    return _manifest.length;
  }

  @override
  Future<int> run({
    required int total,
    required void Function(int current) onProgress,
  }) async {
    if (_manifest.isEmpty) return 0;
    return _service.importManifest(
      _manifest,
      photoRepository,
      onProgress: onProgress,
    );
  }
}
