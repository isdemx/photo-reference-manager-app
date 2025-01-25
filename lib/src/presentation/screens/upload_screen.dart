import 'dart:io' show Platform;
import 'package:exif/exif.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
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
    // Автоматически вызываем выбор файлов после сборки экрана
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickImages();
    });
  }

  Future<void> _pickImages() async {
    if (_isSelecting || _isUploading) return;

    setState(() => _isSelecting = true);
    WakelockPlus.enable();

    List<XFile> selectedFiles = [];

    try {
      // Если мы на iOS/Android, используем image_picker
      if ((Platform.isIOS || Platform.isAndroid) && !kIsWeb) {
        final media = await _picker.pickMultipleMedia();
        if (media.isNotEmpty) {
          selectedFiles = media;
        }
      }
      // Если мы на macOS — используем file_picker
      else if (Platform.isMacOS) {
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          // Можно оставить только изображения, либо расширить для видео
          type: FileType.custom,
          allowedExtensions: [
            'jpg', 'jpeg', 'png', 'gif', 'heic', 'heif', // фото
            'mp4', 'mov', 'avi', 'mkv', 'webm' // видео
          ],
        );
        if (result != null && result.files.isNotEmpty) {
          selectedFiles = result.files
              .where((f) => f.path != null)
              .map((f) => XFile(f.path!))
              .toList();
        }
      } else {
        // На всякий случай fallback
        final media = await _picker.pickMultipleMedia();
        if (media.isNotEmpty) {
          selectedFiles = media;
        }
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    } finally {
      WakelockPlus.disable();
      setState(() => _isSelecting = false);
    }

    if (selectedFiles.isNotEmpty) {
      setState(() => _images = selectedFiles);
      await _uploadImages();
    }
  }

  Future<void> _uploadImages() async {
    if (_images == null || _images!.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadedCount = 0;
      _stopRequested = false;
    });

    final photoRepository = RepositoryProvider.of<PhotoRepositoryImpl>(context);

    for (var i = 0; i < _images!.length; i++) {
      if (_stopRequested) break;
      final image = _images![i];

      // Определяем тип файла: фото или видео
      final mediaType = determineMediaType(image.path);

      // Считываем геолокацию только если это фотография
      Map<String, double>? geoLocation;
      if (mediaType == 'image') {
        geoLocation = await _getGeoLocation(image.path);
      }

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
          mediaType: mediaType);

      try {
        await photoRepository.addPhoto(photo);
        setState(() => _uploadedCount++);
      } catch (e) {
        debugPrint('Error adding image: $e');
      }
    }

    setState(() {
      _isUploading = false;
      _images = null;
      Navigator.pushReplacementNamed(context, '/all_photos');
    });

    context.read<PhotoBloc>().add(LoadPhotos());
  }

  /// Попытка достать GPS из EXIF (только если это изображение)
  Future<Map<String, double>?> _getGeoLocation(String imagePath) async {
    try {
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
    } catch (e) {
      debugPrint('EXIF parsing error: $e');
    }
    return null;
  }

  double _toDecimalDegrees(List values, String? ref) {
    double degrees = 0.0, minutes = 0.0, seconds = 0.0;

    if (values.isNotEmpty) {
      degrees = _toDouble(values[0]);
      minutes = _toDouble(values[1]) / 60;
      seconds = _toDouble(values[2]) / 3600;
    }
    double decimal = degrees + minutes + seconds;

    // Для S/W меняем знак
    if (ref == 'S' || ref == 'W') {
      decimal = -decimal;
    }
    return decimal;
  }

  double _toDouble(dynamic value) {
    if (value is Ratio) {
      return value.numerator / value.denominator;
    } else if (value is int) {
      return value.toDouble();
    } else if (value is double) {
      return value;
    }
    return 0.0;
  }

  void _stopUpload() {
    setState(() => _stopRequested = true);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
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
          // Если не идёт процесс выбора (нет лоадера выбора)
          if (!_isSelecting)
            // Если ничего не выбрано
            if (_images == null)
              Center(
                child: ElevatedButton(
                  onPressed: _pickImages,
                  child: const Text('Select Images / Videos'),
                ),
              )
            else
              // Отображаем сетку выбранных файлов
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
                    return MouseRegion(
                      // исправляет возможные проблемы с курсором на macOS
                      cursor: SystemMouseCursors.basic,
                      child: Image.file(
                        File(image.path),
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
              ),

          // Лоадер при выборе
          if (_isSelecting)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),

          // Лоадер при загрузке
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
                      'Keep application opened until it completes.',
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
