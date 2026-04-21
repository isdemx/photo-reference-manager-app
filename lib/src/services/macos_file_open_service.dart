import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MacOSFileOpenService {
  MacOSFileOpenService._();

  static const MethodChannel _channel = MethodChannel('refma/macos_open_files');

  static Future<Map<String, dynamic>> loadInitialRoutePayload() async {
    if (!_isSupportedPlatform) return const <String, dynamic>{};

    final files = await _getPendingOpenFiles();
    final supportedFiles = _supportedPaths(files);
    debugPrint(
      '[RefmaOpenFiles][dart] loadInitialRoutePayload raw=$files supported=$supportedFiles',
    );
    if (supportedFiles.isEmpty) return const <String, dynamic>{};

    return <String, dynamic>{
      'route': '/lite_viewer',
      'filePath': supportedFiles.first,
    };
  }

  static Future<void> startListening({
    required ValueChanged<List<String>> onFilesOpened,
  }) async {
    if (!_isSupportedPlatform) return;
    debugPrint('[RefmaOpenFiles][dart] startListening setMethodCallHandler');

    _channel.setMethodCallHandler((call) async {
      debugPrint(
        '[RefmaOpenFiles][dart] channel call method=${call.method} args=${call.arguments}',
      );
      if (call.method != 'openFiles') {
        return;
      }

      final rawFiles = call.arguments;
      final files = _normalizeFiles(rawFiles);
      final supportedFiles = _supportedPaths(files);
      if (supportedFiles.isNotEmpty) {
        debugPrint(
          '[RefmaOpenFiles][dart] openFiles supported=$supportedFiles',
        );
        onFilesOpened(supportedFiles);
      }
    });
  }

  static Future<List<String>> _getPendingOpenFiles() async {
    try {
      final raw =
          await _channel.invokeMethod<List<dynamic>>('getPendingOpenFiles');
      debugPrint('[RefmaOpenFiles][dart] getPendingOpenFiles raw=$raw');
      return _normalizeFiles(raw);
    } on MissingPluginException {
      debugPrint(
          '[RefmaOpenFiles][dart] getPendingOpenFiles MissingPluginException');
      return const <String>[];
    } on PlatformException {
      debugPrint(
          '[RefmaOpenFiles][dart] getPendingOpenFiles PlatformException');
      return const <String>[];
    }
  }

  static Future<String?> requestFolderAccess(String folderPath) async {
    if (!_isSupportedPlatform) return null;
    try {
      final selectedPath = await _channel.invokeMethod<String>(
        'requestFolderAccess',
        folderPath,
      );
      debugPrint(
        '[RefmaOpenFiles][dart] requestFolderAccess folder=$folderPath selected=$selectedPath',
      );
      return selectedPath;
    } on MissingPluginException {
      debugPrint(
        '[RefmaOpenFiles][dart] requestFolderAccess MissingPluginException',
      );
      return null;
    } on PlatformException catch (error) {
      debugPrint(
        '[RefmaOpenFiles][dart] requestFolderAccess PlatformException $error',
      );
      return null;
    }
  }

  static List<String> _normalizeFiles(dynamic rawFiles) {
    if (rawFiles is! List) return const <String>[];

    return rawFiles
        .whereType<String>()
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toList(growable: false);
  }

  static List<String> _supportedPaths(List<String> files) {
    return files.where(_isSupportedMediaPath).toList(growable: false);
  }

  static bool _isSupportedMediaPath(String path) {
    final lower = path.toLowerCase();
    const supportedExtensions = <String>[
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.heic',
      '.heif',
      '.webp',
      '.tiff',
      '.tif',
      '.bmp',
      '.mp4',
      '.mov',
      '.avi',
      '.mkv',
      '.m4v',
      '.webm',
      '.wmv',
      '.vmv',
    ];

    return supportedExtensions.any(lower.endsWith);
  }

  static bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    return Platform.isMacOS;
  }
}
