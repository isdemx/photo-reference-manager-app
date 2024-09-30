// lib/src/presentation/screens/upload_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:uuid/uuid.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({Key? key}) : super(key: key);

  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final ImagePicker _picker = ImagePicker();
  List<XFile>? _images;

  void _pickImages() async {
    final images = await _picker.pickMultiImage();
    setState(() {
      _images = images;
    });
  }

  void _uploadImages() {
    if (_images != null && _images!.isNotEmpty) {
      final photoBloc = context.read<PhotoBloc>();

      for (var image in _images!) {
        final photo = Photo(
          id: const Uuid().v4(),
          path: image.path,
          folderIds: [], // Пустой список папок
          tagIds: [], // Пустой список тегов
          comment: '',
          dateAdded: DateTime.now(),
          sortOrder: 0,
          isStoredInApp: true
        );

        photoBloc.add(AddPhoto(photo));
      }

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Photos'),
      ),
      body: _images == null
          ? Center(
              child: ElevatedButton(
                onPressed: _pickImages,
                child: const Text('Select Images'),
              ),
            )
          : Column(
              children: [
                Expanded(
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
                ElevatedButton(
                  onPressed: _uploadImages,
                  child: const Text('Upload'),
                ),
              ],
            ),
    );
  }
}
