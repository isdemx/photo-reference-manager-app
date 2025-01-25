import 'dart:io';

import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/data/repositories/photo_repository_impl.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';

class VideoGeneratorWidget extends StatefulWidget {
  final List<Photo> photos;

  const VideoGeneratorWidget({Key? key, required this.photos})
      : super(key: key);

  @override
  State<VideoGeneratorWidget> createState() => _VideoGeneratorWidgetState();
}

class _VideoGeneratorWidgetState extends State<VideoGeneratorWidget> {
  int sliderValue = 2; 
  bool isShuffle = false;
  bool isGenerating = false;
  String? generatedVideoPath;

  @override
  Widget build(BuildContext context) {
    print('build => isGenerating=$isGenerating, generatedVideoPath=$generatedVideoPath');
    return Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  children: [
                    const Text('This feature will create a slide show video', style: TextStyle(fontSize: 20)),
                    const Text('Select slide show speed:', style: TextStyle(fontSize: 16)), 
                    const SizedBox(height: 8),
                    Slider(
                      min: 2,
                      max: 10,
                      divisions: 8,
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
                          'Each photo will last ${_mapSliderToDuration().toStringAsFixed(3)} sec',
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

  double _mapSliderToDuration() {
    final fraction = (sliderValue - 1) / 9.0;
    final minDur = 1.0 / 60.0;
    final maxDur = 1.0;
    return minDur + fraction * (maxDur - minDur);
  }

  Future<void> generateVideo() async {
    setState(() {
      isGenerating = true;
      generatedVideoPath = null;
    });

    try {
      final durationPerPhoto = _mapSliderToDuration();
      final frameRate = 1.0 / durationPerPhoto;
      print('=== generateVideo START => each photo=$durationPerPhoto s => fr=$frameRate ===');

      // Папка для итогового файла
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(appDir.path, 'photos'));
      if (!photosDir.existsSync()) {
        photosDir.createSync(recursive: true);
      }

      final outputName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final finalOutputPath = p.join(photosDir.path, outputName);

      // Временная папка
      final tempDir = await getTemporaryDirectory();
      final videoDir = Directory(p.join(tempDir.path, 'video_images'));
      if (videoDir.existsSync()) {
        for (var f in videoDir.listSync()) {
          f.deleteSync();
        }
      } else {
        videoDir.createSync(recursive: true);
      }

      // Копируем фото
      final photos = [...widget.photos];
      if (isShuffle) {
        photos.shuffle();
      }

      for (int i = 0; i < photos.length; i++) {
        final originalPath = PhotoPathHelper().getFullPath(photos[i].fileName);
        final originalFile = File(originalPath);
        if (!originalFile.existsSync()) {
          throw Exception('File not found: $originalPath');
        }

        // Переименовываем всё в .jpg, начиная с 1
        final newName = 'img_${i+1}.jpg';
        final copiedPath = p.join(videoDir.path, newName);

        // Просто копируем, несмотря на реальный формат
        // (FFmpeg обычно умеет распознавать PNG/JPEG и т.д. по сигнатуре.)
        await originalFile.copy(copiedPath);
      }

      // Команда ffmpeg с pattern_type
      final command = [
        '-framerate $frameRate',
        '-pattern_type sequence',
        '-start_number 1',
        '-i "${videoDir.path}/img_%d.jpg"',
        '-vf "scale=800:800:force_original_aspect_ratio=decrease,'
            'pad=800:800:(ow-iw)/2:(oh-ih)/2,setsar=1"',
        '-pix_fmt yuv420p',
        '-c:v libx264',
        '-y "$finalOutputPath"',
      ].join(' ');

      print('FFmpeg command => $command');

      await FFmpegKit.execute(command).then((session) async {
        final returnCode = await session.getReturnCode();

        if (ReturnCode.isSuccess(returnCode)) {
          print('FFmpeg SUCCESS => $finalOutputPath');

          // Сохраняем в БД
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

          // Обновляем Bloc
          context.read<PhotoBloc>().add(LoadPhotos());

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video generated & saved successfully!')),
          );

          setState(() {
            generatedVideoPath = finalOutputPath;
          });
          Navigator.pop(context);

        } else {
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
