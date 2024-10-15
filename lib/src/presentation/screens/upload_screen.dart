// lib/src/presentation/screens/upload_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/data/repositories/photo_repository_impl.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path_package;
import 'package:wakelock_plus/wakelock_plus.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({Key? key}) : super(key: key);

  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final ImagePicker _picker = ImagePicker();
  List<XFile>? _images;
  bool _isUploading = false;
  int _uploadedCount = 0;
  bool _stopRequested = false;

  void _pickImages() async {
    final images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _images = images;
      });
    }
  }

  Future<void> _uploadImages() async {
    if (_images != null && _images!.isNotEmpty) {
      setState(() {
        _isUploading = true;
        _uploadedCount = 0;
        _stopRequested = false;
      });

      // Включаем Wakelock
      WakelockPlus.enable();

      final photoRepository =
          RepositoryProvider.of<PhotoRepositoryImpl>(context);
      // List<Photo> addedPhotos = [];

      for (var i = 0; i < _images!.length; i++) {
        if (_stopRequested) {
          break;
        }

        final image = _images![i];

        final photo = Photo(
          id: const Uuid().v4(),
          path: image.path,
          folderIds: [],
          tagIds: [],
          comment: '',
          dateAdded: DateTime.now(),
          sortOrder: 0,
          fileName: path_package.basename(image.path),
          isStoredInApp: true,
        );

        try {
          // Добавляем фото в репозиторий (асинхронно)
          await photoRepository.addPhoto(photo);

          // Добавляем фото в список добавленных
          // addedPhotos.add(photo);

          setState(() {
            _uploadedCount++;
          });

          // vibrate();
        } catch (e) {
          // Обработка ошибок при добавлении фото
          print('Error adding image: $e');
        }
      }

      // Отключаем Wakelock
      WakelockPlus.disable();

      setState(() {
        _isUploading = false;
        if (_stopRequested) {
          // Удаляем оставшиеся изображения из списка
          _images = _images!.sublist(0, _uploadedCount);
        } else {
          _images = null;
        }
      });

      // Обновляем состояние PhotoBloc
      context.read<PhotoBloc>().add(LoadPhotos());

      if (!_stopRequested) {
        // context.read<PhotoBloc>().add(PhotosAdded(addedPhotos));

        // Показ лоадера на время удаления временных файлов
        setState(() {
          _isUploading = true; // Включаем лоадер для удаления
        });

        print('Bef creal');

        context.read<PhotoBloc>().add(ClearTemporaryFiles());

        print('Aft creal');

        // Скрываем лоадер после удаления временных файлов
        setState(() {
          _isUploading = false;
        });

        // Navigator.pop(context);
        Navigator.pushNamed(context, '/all_photos');
      }
    }
  }

  void _stopUpload() {
    setState(() {
      _stopRequested = true;
    });
  }

  @override
  void dispose() {
    // На случай, если Wakelock остался включенным
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Images'),
      ),
      body: _images == null
          ? Center(
              child: ElevatedButton(
                onPressed: _pickImages,
                child: const Text('Select Images'),
              ),
            )
          : Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(4.0),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 4.0,
                          crossAxisSpacing: 4.0,
                        ),
                        itemCount: _images!.length,
                        itemBuilder: (context, index) {
                          final image = _images![index];
                          return Image.file(
                            File(image.path),
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 50.0),
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _uploadImages,
                        child: const Text('Upload'),
                      ),
                    ),
                  ],
                ),
                if (_isUploading)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 20),
                          Text(
                            'Uploading $_uploadedCount of ${_images!.length}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Keep application opened until it loads.',
                            style: TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _stopUpload,
                            child: const Text('Stop'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
