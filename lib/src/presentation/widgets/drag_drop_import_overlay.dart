import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/backup.service.dart';

import 'package:photographers_reference_app/src/presentation/theme/app_theme.dart';
import 'package:photographers_reference_app/src/services/drag_drop_import_service.dart';
import 'package:photographers_reference_app/src/utils/platform_utils.dart';

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
    final content = Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: _dragOver ? Colors.white10 : null,
          ),
          child: widget.child,
        ),
        const _StatusPopoverLayer(),
      ],
    );

    if (!_isDesktop()) {
      return content;
    }

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
        children: [content],
      ),
    );
  }

  bool _isDesktop() {
    return isDesktopPlatform;
  }
}

class _StatusPopoverLayer extends StatefulWidget {
  const _StatusPopoverLayer();

  @override
  State<_StatusPopoverLayer> createState() => _StatusPopoverLayerState();
}

class _StatusPopoverLayerState extends State<_StatusPopoverLayer> {
  double _backupTop = 12;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top + 12;
    return Stack(
      children: [
        Positioned(
          top: topInset,
          right: 12,
          child: const _ImportStatusPopover(),
        ),
        Positioned(
          top: (_backupTop < topInset ? topInset : _backupTop),
          right: 12,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragUpdate: (details) {
              final screenHeight = MediaQuery.sizeOf(context).height;
              setState(() {
                _backupTop = (_backupTop + details.delta.dy).clamp(
                  topInset,
                  screenHeight - 120,
                );
              });
            },
            child: const _BackupStatusPopover(),
          ),
        ),
      ],
    );
  }
}

class _BackupStatusPopover extends StatelessWidget {
  const _BackupStatusPopover();

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    return ValueListenableBuilder<BackupProgressState?>(
      valueListenable: BackupService.progressNotifier,
      builder: (context, status, _) {
        if (status == null || !status.visible) {
          return const SizedBox.shrink();
        }

        final progressValue = (status.progress / 100).clamp(0.0, 1.0);
        final progressText = status.progress > 0
            ? '${status.progress.toStringAsFixed(0)}%'
            : 'Preparing';
        final countText = status.totalMediaFiles > 0
            ? '${status.copiedMediaFiles}/${status.totalMediaFiles}'
            : '0/0';

        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Material(
            color: colors.surface.withValues(alpha: 0.96),
            elevation: 8,
            shadowColor: Colors.black26,
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
                          'Backup',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (status.isActive)
                        InkWell(
                          onTap: BackupService.cancelCurrent,
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text(
                              status.canceling ? '...' : 'Cancel',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.subtle,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          status.phaseLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.subtle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        progressText,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.subtle.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      value: status.isFinal
                          ? 1.0
                          : progressValue == 0
                              ? null
                              : progressValue,
                      backgroundColor: colors.border.withValues(alpha: 0.45),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colors.text.withValues(alpha: 0.82),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Media $countText',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.subtle,
                        ),
                      ),
                      Text(
                        _formatEta(status.eta),
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.subtle.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  if ((status.currentItemName ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      status.currentItemName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.subtle.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatEta(Duration? eta) {
    if (eta == null) return 'Estimating…';
    if (eta.inSeconds <= 0) return 'Ready';
    if (eta.inSeconds < 60) return '~${eta.inSeconds}s';
    final minutes = eta.inMinutes;
    final seconds = eta.inSeconds % 60;
    return '~${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }
}

class _ImportStatusPopover extends StatelessWidget {
  const _ImportStatusPopover();

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
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
        final countText =
            status.total > 0 ? '$displayCompleted/${status.total}' : '';

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: status.visible ? 1.0 : 0.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Material(
              color: colors.surface.withValues(alpha: 0.96),
              elevation: 8,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (status.isActive)
                          InkWell(
                            onTap: service.cancel,
                            borderRadius: BorderRadius.circular(999),
                            child: Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: colors.subtle,
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
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.subtle,
                          ),
                        ),
                        if (countText.isNotEmpty)
                          Text(
                            countText,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.subtle.withValues(alpha: 0.8),
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
                        backgroundColor: colors.border.withValues(alpha: 0.45),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colors.text.withValues(alpha: 0.82),
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
