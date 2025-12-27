import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/data/repositories/photo_repository_impl.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/services/migrations/migration_manager.dart';
import 'package:photographers_reference_app/src/services/migrations/migration_task.dart';
import 'package:photographers_reference_app/src/services/migrations/shared_inbox_migration.dart';
import 'package:photographers_reference_app/src/services/migrations/video_preview_migration_task.dart';

class MigrationOverlayHost extends StatefulWidget {
  const MigrationOverlayHost({super.key, required this.child});

  final Widget child;

  @override
  State<MigrationOverlayHost> createState() => _MigrationOverlayHostState();
}

class _MigrationOverlayHostState extends State<MigrationOverlayHost>
    with WidgetsBindingObserver {
  MigrationProgress _progress = MigrationProgress.idle();
  StreamSubscription<MigrationProgress>? _subscription;
  bool _configured = false;
  bool _started = false;
  int _lastHandledRunId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _configureAndRun();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      MigrationManager.instance.run();
    }
  }

  void _configureAndRun() {
    if (_configured) return;
    _configured = true;

    final photoRepository = RepositoryProvider.of<PhotoRepositoryImpl>(context);
    final manager = MigrationManager.instance;

    manager.configure(tasks: [
      SharedInboxMigration(photoRepository: photoRepository),
      VideoPreviewMigrationTask(
        photoBox: photoRepository.photoBox,
        enabled: false,
      ),
    ]);

    _subscription = manager.progressStream.listen((progress) {
      if (!mounted) return;
      setState(() {
        _progress = progress;
      });
      if (progress.phase == MigrationPhase.completed &&
          progress.runId != _lastHandledRunId) {
        _lastHandledRunId = progress.runId;
        if (progress.changes > 0) {
          context.read<PhotoBloc>().add(LoadPhotos());
        }
      }
    });

    if (!_started) {
      _started = true;
      manager.run();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_progress.phase == MigrationPhase.running)
          _MigrationOverlay(progress: _progress),
      ],
    );
  }
}

class _MigrationOverlay extends StatelessWidget {
  const _MigrationOverlay({required this.progress});

  final MigrationProgress progress;

  @override
  Widget build(BuildContext context) {
    final total = progress.total;
    final current = progress.current.clamp(0, total);

    return Positioned.fill(
      child: AbsorbPointer(
        absorbing: true,
        child: Container(
          color: Colors.black.withOpacity(0.6),
          alignment: Alignment.center,
          child: Container(
            width: 300,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 22, 22, 22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  progress.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$current/$total',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: null,
                  minHeight: 6,
                  backgroundColor: Colors.white10,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFF236BA6)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
