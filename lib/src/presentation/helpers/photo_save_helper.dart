import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/data/repositories/photo_repository_impl.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';

class PhotoSaveHelper {
  /// Saves the [bytes] under [fileName] into the app's "photos" directory,
  /// creates a [Photo] entry, stores it in the DB, and returns that [Photo].
  static Future<Photo> savePhoto({
    required String fileName,
    required Uint8List bytes,
    required BuildContext context,
  }) async {
    // 1. Locate app documents directory and ensure a "photos" subdirectory.
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, 'photos'));
    if (!photosDir.existsSync()) {
      photosDir.createSync(recursive: true);
    }

    // 2. Create a path for the output file.
    final outPath = p.join(photosDir.path, fileName);

    // 3. If it doesn't exist, write the raw bytes to that file path.
    final outFile = File(outPath);
    if (!outFile.existsSync()) {
      await outFile.writeAsBytes(bytes);
    }

    // 4. Construct the new [Photo] entity.
    final newPhoto = Photo(
      id: const Uuid().v4(),
      fileName: fileName,
      path: outPath,
      mediaType: 'image',
      dateAdded: DateTime.now(),
      folderIds: [],
      comment: '',
      tagIds: [],
      sortOrder: 0,
    );

    // 5. Insert the [Photo] into your repository/DB.
    final repo = RepositoryProvider.of<PhotoRepositoryImpl>(context);
    await repo.addPhoto(newPhoto);

    // 6. Optionally, refresh your PhotoBloc state.
    context.read<PhotoBloc>().add(LoadPhotos());

    return newPhoto;
  }
}
