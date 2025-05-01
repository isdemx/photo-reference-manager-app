import 'package:hive/hive.dart';

part 'category.g.dart';

@HiveType(typeId: 0)
class Category extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  List<String> folderIds;

  @HiveField(3)
  int sortOrder;

  @HiveField(4)
  bool? isPrivate;

  @HiveField(5)
  bool? collapsed;

  Category({
    required this.id,
    required this.name,
    required this.folderIds,
    required this.sortOrder,
    this.isPrivate,
    this.collapsed,
  });

  /// Копирование с частичной заменой
  Category copyWith({
    String? id,
    String? name,
    List<String>? folderIds,
    int? sortOrder,
    bool? isPrivate,
    bool? collapsed,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      folderIds: folderIds ?? this.folderIds,
      sortOrder: sortOrder ?? this.sortOrder,
      isPrivate: isPrivate ?? this.isPrivate,
      collapsed: collapsed ?? this.collapsed,
    );
  }

  /// Преобразование в JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'folderIds': folderIds,
        'sortOrder': sortOrder,
        'isPrivate': isPrivate,
        'collapsed': collapsed,
      };

  /// Создание из JSON
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      folderIds: List<String>.from(json['folderIds'] ?? []),
      sortOrder: json['sortOrder'] as int,
      isPrivate: json['isPrivate'] as bool?,
      collapsed: json['collapsed'] as bool?,
    );
  }
}
