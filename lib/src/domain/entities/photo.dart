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

  @HiveField(9)
  final Map<String, double>? geoLocation; // Новое поле для геолокации

  @HiveField(10)
  String mediaType; // Убрано final

  @HiveField(11)
  String? videoPreview;

  @HiveField(12)
  String? videoDuration;

  Photo({
    required this.id,
    required this.path,
    required this.fileName,
    required this.folderIds,
    required this.tagIds,
    required this.comment,
    required this.dateAdded,
    required this.sortOrder,
    required this.mediaType,
    this.videoPreview,
    this.videoDuration,
    this.isStoredInApp = false,
    this.geoLocation,
  });

  @override
  String toString() {
    return 'Photo{id: $id, fileName: "$fileName", geoLocation: $geoLocation, isStoredInApp: $isStoredInApp, tagIds: $tagIds, folderIds: $folderIds}';
  }

  bool get isImage => mediaType == 'image';
  bool get isVideo => mediaType == 'video';

  /// Метод copyWith для создания нового объекта с изменёнными полями
  Photo copyWith({
    String? id,
    String? path,
    String? fileName,
    List<String>? folderIds,
    List<String>? tagIds,
    String? comment,
    DateTime? dateAdded,
    int? sortOrder,
    String? mediaType,
    String? videoPreview,
    String? videoDuration,
    bool? isStoredInApp,
    Map<String, double>? geoLocation,
  }) {
    return Photo(
      id: id ?? this.id,
      path: path ?? this.path,
      fileName: fileName ?? this.fileName,
      folderIds: folderIds ?? this.folderIds,
      tagIds: tagIds ?? this.tagIds,
      comment: comment ?? this.comment,
      dateAdded: dateAdded ?? this.dateAdded,
      sortOrder: sortOrder ?? this.sortOrder,
      mediaType: mediaType ?? this.mediaType,
      videoPreview: videoPreview ?? this.videoPreview,
      videoDuration: videoDuration ?? this.videoDuration,
      isStoredInApp: isStoredInApp ?? this.isStoredInApp,
      geoLocation: geoLocation ?? this.geoLocation,
    );
  }
}
