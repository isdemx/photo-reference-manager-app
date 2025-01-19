// lib/src/presentation/screens/upload_screen.dart

import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/data/repositories/photo_repository_impl.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/utils/_determine_media_type.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path_package;
import 'package:wakelock_plus/wakelock_plus.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final ImagePicker _picker = ImagePicker();
  List<XFile>? _images;
  bool _isUploading = false;
  bool _isSelecting = false;
  int _uploadedCount = 0;
  bool _stopRequested = false;

  @override
  void initState() {
    super.initState();
    // Вызываем метод _pickImages при старте виджета
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickImages();
    });
  }

  void _pickImages() async {
    if (_isSelecting || _isUploading) return; // Блокируем повторный вызов

    setState(() {
      _isSelecting = true; // Включаем лоадер выбора
    });

    try {
      WakelockPlus.enable();
      final images = await _picker.pickMultipleMedia();
      if (images.isNotEmpty) {
        setState(() {
          _images = images;
          _isSelecting = false; // Выключаем лоадер выбора
        });
        // Вызываем загрузку фотографий
        await _uploadImages();
      } else {
        WakelockPlus.disable();
        setState(() {
          _isSelecting = false; // Выключаем лоадер, если ничего не выбрано
        });
      }
    } catch (e) {
      print('Error picking images: $e');
      setState(() {
        _isSelecting = false; // Выключаем лоадер при ошибке
      });
    }
  }

  Future<Map<String, double>?> _getGeoLocation(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final tags = await readExifFromBytes(bytes);

    if (tags.containsKey('GPS GPSLatitude') &&
        tags.containsKey('GPS GPSLongitude')) {
      final latitude = (tags['GPS GPSLatitude']?.values)?.toList();
      final longitude = (tags['GPS GPSLongitude']?.values)?.toList();

      final latitudeRef = tags['GPS GPSLatitudeRef']?.printable;
      final longitudeRef = tags['GPS GPSLongitudeRef']?.printable;

      if (latitude != null && longitude != null) {
        final lat = _toDecimalDegrees(latitude, latitudeRef);
        final lon = _toDecimalDegrees(longitude, longitudeRef);
        return {'lat': lat, 'lon': lon};
      }
    }
    return null;
  }

  double _toDecimalDegrees(List values, String? ref) {
    double degrees = 0.0, minutes = 0.0, seconds = 0.0;

    // Преобразование значения в double для каждого компонента
    if (values.isNotEmpty) {
      degrees = _toDouble(values[0]);
      minutes = _toDouble(values[1]) / 60;
      seconds = _toDouble(values[2]) / 3600;
    }

    double decimal = degrees + minutes + seconds;

    // Инверсия для южной или западной полушарий
    if (ref == 'S' || ref == 'W') {
      decimal = -decimal;
    }

    return decimal;
  }

  double _toDouble(dynamic value) {
    if (value is Ratio) {
      // Проверка, является ли значение типом Ratio
      return value.numerator /
          value.denominator; // Вычисляем значение как дробь
    } else if (value is int) {
      return value.toDouble();
    } else if (value is double) {
      return value;
    }
    return 0.0; // Значение по умолчанию
  }

  Future<void> _uploadImages() async {
    if (_images != null && _images!.isNotEmpty) {
      setState(() {
        _isUploading = true; // Включаем лоадер загрузки
        _uploadedCount = 0;
        _stopRequested = false;
      });

      final photoRepository =
          RepositoryProvider.of<PhotoRepositoryImpl>(context);

      for (var i = 0; i < _images!.length; i++) {
        if (_stopRequested) break;

        final image = _images![i];

        final mediaType = determineMediaType(image.path);
        // print('IMAGE!!!!!!!!! ${image.}');
        final geoLocation = await _getGeoLocation(image.path);

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
          geoLocation: geoLocation,
          mediaType: mediaType
        );

        try {
          await photoRepository.addPhoto(photo);
          setState(() {
            _uploadedCount++;
          });
        } catch (e) {
          print('Error adding image: $e');
        }
      }

      setState(() {
        _isUploading = false; // Выключаем лоадер загрузки
        _images = null; // Сбрасываем список изображений
        Navigator.pushReplacementNamed(context, '/all_photos');
      });

      context.read<PhotoBloc>().add(LoadPhotos());
    }
  }

  void _stopUpload() {
    setState(() {
      _stopRequested = true;
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable(); // На случай, если Wakelock остался включенным
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Images'),
      ),
      body: Stack(
        children: [
          if (!_isSelecting)
            if (_images == null)
              Center(
                child: ElevatedButton(
                  onPressed: _pickImages,
                  child: const Text('Select Images'),
                ),
              )
            else
              Positioned.fill(
                child: GridView.builder(
                  padding: const EdgeInsets.all(4.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
          if (_isSelecting)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
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
