import 'dart:io';

import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';
import 'package:photographers_reference_app/src/utils/photo_share_helper.dart';
import 'package:uuid/uuid.dart';

import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/data/repositories/photo_repository_impl.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';

class VideoGeneratorWidget extends StatefulWidget {
  final List<Photo> photos;

  const VideoGeneratorWidget({Key? key, required this.photos})
      : super(key: key);

  @override
  State<VideoGeneratorWidget> createState() => _VideoGeneratorWidgetState();
}

class _VideoGeneratorWidgetState extends State<VideoGeneratorWidget> {
  /// Слайдер от 1 до 10 (числа целые).
  /// После преобразования получаем время кадра [1/60 .. 1.0].
  int sliderValue = 2; // по умолчанию = 1 => 1/60 s
  bool isShuffle = false; // для чекбокса "Make Shuffle"
  bool isGenerating = false;
  String? generatedVideoPath;

  @override
  Widget build(BuildContext context) {
    print(
        'build => isGenerating=$isGenerating, generatedVideoPath=$generatedVideoPath');
    return Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  children: [
                    const Text(
                      'Select duration per photo:',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      min: 2,
                      max: 10,
                      divisions: 9,
                      label: '$sliderValue',
                      value: sliderValue.toDouble(),
                      onChanged: (double val) {
                        setState(() {
                          sliderValue = val.toInt();
                        });
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Slider: $sliderValue => ${_mapSliderToDuration().toStringAsFixed(3)} sec/photo',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: isShuffle,
                              onChanged: (bool? value) {
                                setState(() {
                                  isShuffle = value ?? false;
                                });
                              },
                            ),
                            const Text('Shuffle'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: isGenerating ? null : generateVideo,
                      child: const Text('Generate Video'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
        if (isGenerating)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  /// Преобразуем значение слайдера (1..10) в диапазон (1/60 .. 1.0).
  double _mapSliderToDuration() {
    // fraction = [0..1]
    final fraction = (sliderValue - 1) / 9.0;
    final minDur = 1.0 / 60.0; // ~0.0167
    final maxDur = 1.0; // 1 second
    return minDur + fraction * (maxDur - minDur);
  }

  Future<void> generateVideo() async {
    setState(() {
      isGenerating = true;
      generatedVideoPath = null;
    });

    try {
      final double durationPerPhoto = _mapSliderToDuration();
      print(
          '=== generateVideo START => each photo duration=$durationPerPhoto seconds ===');

      // 1) Готовим выходной путь
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(appDir.path, 'photos'));
      if (!photosDir.existsSync()) {
        photosDir.createSync(recursive: true);
      }

      final outputName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final finalOutputPath = p.join(photosDir.path, outputName);

      // 2) Временная папка
      final tempDir = await getTemporaryDirectory();
      final videoDir = Directory(p.join(tempDir.path, 'video_images'));
      if (videoDir.existsSync()) {
        for (var f in videoDir.listSync()) {
          f.deleteSync();
        }
      } else {
        videoDir.createSync(recursive: true);
      }

      // 3) Список команд (с shuffle, если включён)
      if (isShuffle) {
        widget.photos.shuffle();
      }

      final List<String> inputSegments = [];
      for (int i = 0; i < widget.photos.length; i++) {
        final photo = widget.photos[i];
        final originalPath = PhotoPathHelper().getFullPath(photo.fileName);
        final originalFile = File(originalPath);

        if (!originalFile.existsSync()) {
          throw Exception('File not found: $originalPath');
        }

        final ext = p.extension(originalPath);
        final copiedName = 'img_$i$ext';
        final copiedPath = p.join(videoDir.path, copiedName);

        await originalFile.copy(copiedPath);

        inputSegments.add('-loop 1 -t $durationPerPhoto -i "$copiedPath"');
      }

      // 4) Формируем filter_complex
      final scaleBlocks = List.generate(widget.photos.length, (i) {
        return '[${i}:v]'
            'scale=800:800:force_original_aspect_ratio=decrease,'
            'pad=800:800:(ow-iw)/2:(oh-ih)/2,'
            'setsar=1[v$i];';
      }).join('');

      final concatInputs =
          List.generate(widget.photos.length, (i) => '[v$i]').join('');
      final filterComplex = '$scaleBlocks'
          '$concatInputs'
          'concat=n=${widget.photos.length}:v=1:a=0';

      // 5) Составляем FFmpeg команду
      final command = '${inputSegments.join(' ')} '
          '-filter_complex "$filterComplex" '
          '-c:v libx264 '
          '-f mp4 '
          '-y "$finalOutputPath"';

      print('FFmpeg command:\n$command');

      // 6) Запускаем
      await FFmpegKit.execute(command).then((session) async {
        final returnCode = await session.getReturnCode();

        if (ReturnCode.isSuccess(returnCode)) {
          print('FFmpeg SUCCESS => $finalOutputPath');

          // Добавляем в БД
          final repo = RepositoryProvider.of<PhotoRepositoryImpl>(context);
          final newVideo = Photo(
            id: const Uuid().v4(),
            path: finalOutputPath,
            fileName: outputName,
            folderIds: [],
            tagIds: [],
            comment: '',
            dateAdded: DateTime.now(),
            sortOrder: 0,
            isStoredInApp: true,
            geoLocation: null,
            mediaType: 'video',
          );
          await repo.addPhoto(newVideo);

          // Обновляем список в UI через Bloc (опционально)
          context.read<PhotoBloc>().add(LoadPhotos());

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Video generated & saved successfully!')),
          );

          setState(() {
            generatedVideoPath = finalOutputPath;
          });
          Navigator.pop(context);
        } else {
          // Выводим логи ffmpeg
          final logs = await session.getLogs();
          for (var line in logs) {
            print('FFmpeg Log => ${line.getMessage()}');
          }
          throw Exception('FFmpeg failed with code: $returnCode');
        }
      });
    } catch (e, st) {
      print('generateVideo() error: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        isGenerating = false;
      });
      print('=== generateVideo() END ===');
    }
  }
}
