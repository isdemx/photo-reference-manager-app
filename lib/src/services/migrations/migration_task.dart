enum MigrationPhase {
  idle,
  running,
  completed,
}

class MigrationProgress {
  final String title;
  final int current;
  final int total;
  final MigrationPhase phase;
  final int changes;
  final int runId;

  const MigrationProgress._({
    required this.title,
    required this.current,
    required this.total,
    required this.phase,
    required this.changes,
    required this.runId,
  });

  factory MigrationProgress.idle() {
    return const MigrationProgress._(
      title: '',
      current: 0,
      total: 0,
      phase: MigrationPhase.idle,
      changes: 0,
      runId: 0,
    );
  }

  factory MigrationProgress.running({
    required String title,
    required int current,
    required int total,
    required int runId,
  }) {
    return MigrationProgress._(
      title: title,
      current: current,
      total: total,
      phase: MigrationPhase.running,
      changes: 0,
      runId: runId,
    );
  }

  factory MigrationProgress.completed({
    required int changes,
    required int runId,
  }) {
    return MigrationProgress._(
      title: '',
      current: 0,
      total: 0,
      phase: MigrationPhase.completed,
      changes: changes,
      runId: runId,
    );
  }

  double get ratio {
    if (total <= 0) return 0;
    return current / total;
  }
}

abstract class MigrationTask {
  String get id;
  String get title;
  bool get enabled => true;

  Future<int> getPendingCount();

  Future<int> run({
    required int total,
    required void Function(int current) onProgress,
  });
}
