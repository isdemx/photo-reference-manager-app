// lib/src/domain/entities/photo.dart

import 'package:hive/hive.dart';

part 'photo.g.dart';

@HiveType(typeId: 2)
class Photo extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String path;

  @HiveField(2)
  final List<String> folderIds; // Список идентификаторов папок

  @HiveField(3)
  final List<String> tagIds; // Список идентификаторов тегов

  @HiveField(4)
  final String comment;

  @HiveField(5)
  final DateTime dateAdded;

  @HiveField(6)
  final int sortOrder;

  @HiveField(7)
  bool isStoredInApp; // Новое поле

  @HiveField(8)
  String fileName; // Храните только имя файла

  Photo({
    required this.id,
    required this.path,
    required this.fileName,
    required this.folderIds,
    required this.tagIds,
    required this.comment,
    required this.dateAdded,
    required this.sortOrder,
    this.isStoredInApp = false,
  });

  @override
  String toString() {
    return 'Photo{id: $id, fileName: "$fileName", isStoredInApp: $isStoredInApp, tagIds: $tagIds, folderIds: $folderIds}';
  }
}
