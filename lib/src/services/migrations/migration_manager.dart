import 'dart:async';

import 'package:photographers_reference_app/src/services/migrations/migration_task.dart';

class MigrationManager {
  MigrationManager._();

  static final MigrationManager instance = MigrationManager._();

  final StreamController<MigrationProgress> _controller =
      StreamController<MigrationProgress>.broadcast();
  final List<MigrationTask> _tasks = [];

  bool _configured = false;
  bool _running = false;
  int _runId = 0;

  Stream<MigrationProgress> get progressStream => _controller.stream;

  void configure({
    required List<MigrationTask> tasks,
  }) {
    if (_configured) return;
    _tasks
      ..clear()
      ..addAll(tasks);
    _configured = true;
  }

  Future<void> run() async {
    if (_running) return;
    _running = true;
    _runId += 1;

    var ranAny = false;
    var changes = 0;

    for (final task in _tasks) {
      if (!task.enabled) continue;
      final total = await task.getPendingCount();
      if (total <= 0) continue;

      ranAny = true;
      _controller.add(
        MigrationProgress.running(
          title: task.title,
          current: 0,
          total: total,
          runId: _runId,
        ),
      );

      final taskChanges = await task.run(
        total: total,
        onProgress: (current) {
          _controller.add(
            MigrationProgress.running(
              title: task.title,
              current: current,
              total: total,
              runId: _runId,
            ),
          );
        },
      );
      if (taskChanges > 0) {
        changes += taskChanges;
      }
    }

    if (ranAny) {
      _controller.add(
        MigrationProgress.completed(
          changes: changes,
          runId: _runId,
        ),
      );
    } else {
      _controller.add(MigrationProgress.idle());
    }
    _running = false;
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
