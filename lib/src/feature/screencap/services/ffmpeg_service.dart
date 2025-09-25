import 'dart:io';
import 'dart:ui';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

class FfmpegService {
  Future<File> cropAndCompress(
    String inputPath, {
    required Rect cropRect,
    required String displayId,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final outDir = Directory(p.join(docs.path, 'videos'));
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    final outPath = p.join(
      outDir.path,
      'rec_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );

    final crop =
        'crop=${cropRect.width.toInt()}:${cropRect.height.toInt()}:${cropRect.left.toInt()}:${cropRect.top.toInt()}';

    final cmd = [
      '-y',
      '-i',
      inputPath,
      '-vf',
      crop,
      '-c:v',
      'libx264',
      '-preset',
      'veryfast',
      '-crf',
      '22',
      '-c:a',
      'aac',
      '-b:a',
      '128k',
      outPath
    ].join(' ');

    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) {
      final log = await session.getOutput();
      throw 'FFmpeg failed: $rc\n$log';
    }
    return File(outPath);
  }
}
