import 'package:path/path.dart' as path_package;

String determineMediaType(String path) {
  final extension = path_package.extension(path).toLowerCase();
  if (['.jpg', '.jpeg', '.png', '.gif'].contains(extension)) {
    return 'image';
  } else if (['.mp4', '.mov', '.avi', '.mkv'].contains(extension)) {
    return 'video';
  }
  return 'unknown';
}