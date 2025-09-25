// lib/src/feature/screencap/record_block.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:photographers_reference_app/src/feature/screencap/overlay_picker.dart';
import 'package:photographers_reference_app/src/feature/screencap/services/screen_capture_service.dart';
import 'package:photographers_reference_app/src/presentation/helpers/photo_save_helper.dart';

class RecordBlock extends StatefulWidget {
  const RecordBlock({super.key});
  @override
  State<RecordBlock> createState() => _RecordBlockState();
}

class _RecordBlockState extends State<RecordBlock> {
  final _screen = ScreenCaptureService();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Скриншот области',
          icon: const Icon(Icons.photo_camera_outlined),
          onPressed: () async {
            if (_busy) return;
            _busy = true;
            try {
              debugPrint('[RecordBlock] request overlay…');
              await OverlayPicker.show(
                context,
                onShot: (rectPx, displayId) async {
                  debugPrint('[RecordBlock] onShot rectPx=$rectPx displayId=$displayId');
                  try {
                    final bytes = await _screen.captureExactRegionPx(pxRect: rectPx);

                    final fileName = 'shot_${DateTime.now().millisecondsSinceEpoch}.png';
                    debugPrint('[RecordBlock] saving $fileName, bytes=${bytes.length}');
                    await PhotoSaveHelper.savePhoto(
                      fileName: fileName,
                      bytes: bytes,
                      context: context,
                      mediaType: 'image',
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Скриншот сохранён')),
                      );
                    }
                  } catch (e, st) {
                    debugPrint('[RecordBlock] shot failed: $e\n$st');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Не удалось сделать скриншот: $e')),
                      );
                    }
                  }
                },
                onRecord: (rectPx, displayId) async {
                  debugPrint('[RecordBlock] onRecord (ignored for now) rectPx=$rectPx displayId=$displayId');
                },
              );
            } finally {
              _busy = false;
            }
          },
        ),
      ],
    );
  }
}
