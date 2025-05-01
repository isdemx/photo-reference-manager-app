import 'package:hive/hive.dart';

part 'folder.g.dart';

@HiveType(typeId: 1)
class Folder extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String categoryId;

  @HiveField(3)
  List<String> photoIds;

  @HiveField(4)
  DateTime dateCreated;

  @HiveField(6)
  String? avatarPath;

  @HiveField(5)
  int sortOrder;

  @HiveField(7)
  bool? isPrivate;

  Folder({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.photoIds,
    required this.dateCreated,
    required this.sortOrder,
    this.avatarPath,
    this.isPrivate,
  });

  /// Создание копии с изменениями
  Folder copyWith({
    String? id,
    String? name,
    String? categoryId,
    List<String>? photoIds,
    DateTime? dateCreated,
    int? sortOrder,
    String? avatarPath,
    bool? isPrivate,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      photoIds: photoIds ?? this.photoIds,
      dateCreated: dateCreated ?? this.dateCreated,
      sortOrder: sortOrder ?? this.sortOrder,
      avatarPath: avatarPath ?? this.avatarPath,
      isPrivate: isPrivate ?? this.isPrivate,
    );
  }

  /// Экспорт в JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'categoryId': categoryId,
        'photoIds': photoIds,
        'dateCreated': dateCreated.toIso8601String(),
        'sortOrder': sortOrder,
        'avatarPath': avatarPath,
        'isPrivate': isPrivate,
      };

  /// Импорт из JSON
  factory Folder.fromJson(Map<String, dynamic> json) {
    return Folder(
      id: json['id'] as String,
      name: json['name'] as String,
      categoryId: json['categoryId'] as String,
      photoIds: List<String>.from(json['photoIds'] ?? []),
      dateCreated: DateTime.parse(json['dateCreated'] as String),
      sortOrder: json['sortOrder'] as int,
      avatarPath: json['avatarPath'] as String?,
      isPrivate: json['isPrivate'] as bool?,
    );
  }
}
