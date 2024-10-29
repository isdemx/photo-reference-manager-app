// lib/src/presentation/screens/upload_screen.dart

import 'package:exif/exif.dart';
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

  Future<Map<String, double>?> _getGeoLocation(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final tags = await readExifFromBytes(bytes);

    if (tags.containsKey('GPS GPSLatitude') &&
        tags.containsKey('GPS GPSLongitude')) {
      final latitude =
          (tags['GPS GPSLatitude']?.values as IfdValues?)?.toList();
      final longitude =
          (tags['GPS GPSLongitude']?.values as IfdValues?)?.toList();

      final latitudeRef = tags['GPS GPSLatitudeRef']?.printable;
      final longitudeRef = tags['GPS GPSLongitudeRef']?.printable;

      if (latitude != null && longitude != null) {
        print('latitude $latitude');
        print('longitude $longitude');
        final lat = _toDecimalDegrees(latitude, latitudeRef);
        final lon = _toDecimalDegrees(longitude, longitudeRef);

        print('add locatrion: lat: $lat, lon: $lon');

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

    print('decimal $decimal');

    return decimal;
  }

  double _toDouble(dynamic value) {
    print('_toDouble $value, type: ${value.runtimeType}'); // Для отладки типа

    if (value is Ratio) {
      // Проверка, является ли значение типом Ratio
      return value.numerator /
          value.denominator; // Вычисляем значение как дробь
    } else if (value is int) {
      return value.toDouble();
    } else if (value is double) {
      return value;
    }

    print('Unhandled value type: ${value.runtimeType}');
    return 0.0; // Значение по умолчанию
  }

  Future<void> _uploadImages() async {
    if (_images != null && _images!.isNotEmpty) {
      setState(() {
        _isUploading = true;
        _uploadedCount = 0;
        _stopRequested = false;
      });

      WakelockPlus.enable(); // Включаем Wakelock

      final photoRepository =
          RepositoryProvider.of<PhotoRepositoryImpl>(context);

      for (var i = 0; i < _images!.length; i++) {
        if (_stopRequested) break;

        final image = _images![i];
        final geoLocation =
            await _getGeoLocation(image.path); // Получаем геолокацию

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
          geoLocation: geoLocation, // Сохраняем геолокацию, если доступна
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

      WakelockPlus.disable(); // Отключаем Wakelock

      setState(() {
        _isUploading = false;
        if (_stopRequested) {
          _images = _images!.sublist(0, _uploadedCount);
        } else {
          _images = null;
        }
      });

      context.read<PhotoBloc>().add(LoadPhotos());

      if (!_stopRequested) {
        setState(() {
          _isUploading = true; // Включаем лоадер для удаления
        });

        context.read<PhotoBloc>().add(ClearTemporaryFiles());

        setState(() {
          _isUploading = false;
        });

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
    WakelockPlus.disable(); // На случай, если Wakelock остался включенным
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
