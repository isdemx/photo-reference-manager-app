import 'package:photographers_reference_app/src/domain/entities/collage.dart';

/// Описываем CRUD для коллажей
abstract class CollageRepository {
  Future<void> addCollage(Collage collage);
  Future<void> updateCollage(Collage collage);
  Future<void> deleteCollage(String collageId);

  Future<Collage?> getCollage(String collageId);
  Future<List<Collage>> getAllCollages();
}
