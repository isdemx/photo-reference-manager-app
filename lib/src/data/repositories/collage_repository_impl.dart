import 'package:hive/hive.dart';
import 'package:photographers_reference_app/src/domain/entities/collage.dart';
import 'package:photographers_reference_app/src/domain/repositories/collage_repository.dart';

class CollageRepositoryImpl implements CollageRepository {
  final Box<Collage> collageBox;

  CollageRepositoryImpl(this.collageBox);

  @override
  Future<void> addCollage(Collage collage) async {
    // Используем collage.id как ключ
    await collageBox.put(collage.id, collage);
  }

  @override
  Future<void> updateCollage(Collage collage) async {
    await collageBox.put(collage.id, collage);
  }

  @override
  Future<void> deleteCollage(String collageId) async {
    await collageBox.delete(collageId);
  }

  @override
  Future<Collage?> getCollage(String collageId) async {
    return collageBox.get(collageId);
  }

  @override
  Future<List<Collage>> getAllCollages() async {
    return collageBox.values.toList();
  }
}
