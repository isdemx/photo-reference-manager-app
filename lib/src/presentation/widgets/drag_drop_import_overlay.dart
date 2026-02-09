import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:photographers_reference_app/src/services/drag_drop_import_service.dart';

class DragDropImportOverlay extends StatefulWidget {
  final Widget child;

  const DragDropImportOverlay({
    super.key,
    required this.child,
  });

  @override
  State<DragDropImportOverlay> createState() => _DragDropImportOverlayState();
}

class _DragDropImportOverlayState extends State<DragDropImportOverlay> {
  bool _dragOver = false;

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop()) return widget.child;

    final importService = context.read<DragDropImportService>();

    return DropTarget(
      onDragDone: (details) {
        importService.importFiles(
          files: details.files,
          context: context,
        );
      },
      onDragEntered: (_) => setState(() => _dragOver = true),
      onDragExited: (_) => setState(() => _dragOver = false),
      child: Stack(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: _dragOver ? Colors.white10 : null,
            ),
            child: widget.child,
          ),
          const Positioned(
            top: 12,
            right: 12,
            child: _ImportStatusPopover(),
          ),
        ],
      ),
    );
  }

  bool _isDesktop() {
    if (kIsWeb) return false;
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }
}

class _ImportStatusPopover extends StatelessWidget {
  const _ImportStatusPopover();

  @override
  Widget build(BuildContext context) {
    final service = context.read<DragDropImportService>();
    return StreamBuilder<ImportStatus>(
      stream: service.statusStream,
      builder: (context, snapshot) {
        final status = snapshot.data;
        if (status == null || !status.visible) {
          return const SizedBox.shrink();
        }

        final label = _stageLabel(status.stage);
        final current = status.currentName ?? '';
        final displayCompleted = status.isActive
            ? (status.completed + 1).clamp(1, status.total)
            : status.completed;
        final countText = status.total > 0
            ? '$displayCompleted/${status.total}'
            : '';

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: status.visible ? 1.0 : 0.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Material(
              color: Colors.black.withOpacity(0.82),
              elevation: 8,
              shadowColor: Colors.black54,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            current.isEmpty ? 'Import' : current,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (status.isActive)
                          InkWell(
                            onTap: service.cancel,
                            borderRadius: BorderRadius.circular(999),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                        if (countText.isNotEmpty)
                          Text(
                            countText,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white54,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        value: status.isFinal ? 1.0 : status.progress,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _stageLabel(ImportStage stage) {
    switch (stage) {
      case ImportStage.loading:
        return 'Loading';
      case ImportStage.converting:
        return 'Converting';
      case ImportStage.done:
        return 'Done';
      case ImportStage.canceled:
        return 'Canceled';
      case ImportStage.error:
        return 'Error';
      case ImportStage.idle:
        return '';
    }
  }
}
