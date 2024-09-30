// lib/src/domain/repositories/photo_repository.dart

import 'package:photographers_reference_app/src/domain/entities/photo.dart';

abstract class PhotoRepository {
  Future<void> addPhoto(Photo photo);
  Future<List<Photo>> getPhotos();
  Future<void> deletePhoto(String id);
  Future<void> updatePhoto(Photo photo);
}
