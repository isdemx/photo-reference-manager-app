import 'dart:io';

import 'package:path/path.dart' as p;

String mediaFileNameWithSuffix(String originalFileName, String suffix) {
  final originalBase = p.basenameWithoutExtension(originalFileName).trim();
  final ext = p.extension(originalFileName);
  final base = _safeFileNamePart(originalBase.isEmpty ? 'media' : originalBase);
  final safeSuffix = _safeFileNamePart(suffix);

  if (safeSuffix.isEmpty) {
    return '$base$ext';
  }

  return '${base}_$safeSuffix$ext';
}

String mediaFileNameWithId(String originalFileName, String id) {
  final shortId = id.replaceAll('-', '');
  final suffix = shortId.length > 12 ? shortId.substring(0, 12) : shortId;
  return mediaFileNameWithSuffix(originalFileName, suffix);
}

String uniqueFileNameInDirectory(Directory directory, String desiredFileName) {
  final base = p.basenameWithoutExtension(desiredFileName).trim();
  final ext = p.extension(desiredFileName);
  final safeBase = _safeFileNamePart(base.isEmpty ? 'media' : base);

  var candidate = '$safeBase$ext';
  var index = 2;

  while (File(p.join(directory.path, candidate)).existsSync()) {
    candidate = '${safeBase}_$index$ext';
    index++;
  }

  return candidate;
}

String _safeFileNamePart(String value) {
  return value
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
