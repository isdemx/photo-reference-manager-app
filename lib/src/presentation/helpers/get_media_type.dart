import 'package:path/path.dart' as p;

String getMediaType(String path) {
  final ext = p.extension(path).toLowerCase();
  if (['.jpg', '.jpeg', '.png', '.heic', '.webp'].contains(ext)) {
    return 'image';
  }
  if ([
    '.mp4',
    '.mov',
    '.avi',
    '.mkv',
    '.webm',
    '.m4v',
    '.wmv',
    '.vmv',
  ].contains(ext)) {
    return 'video';
  }
  return 'image';
}
