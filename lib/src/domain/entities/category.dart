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

  @HiveField(4) // Новое поле
  bool? isPrivate;

  @HiveField(5) // Новое поле
  bool? collapsed;

  Category({
    required this.id,
    required this.name,
    required this.folderIds,
    required this.sortOrder,
    this.isPrivate, // Новое поле
    this.collapsed, // Новое поле
  });

  // Метод copyWith
  Category copyWith({
    String? id,
    String? name,
    List<String>? folderIds,
    int? sortOrder,
    bool? isPrivate,  // Новое поле
    bool? collapsed,  // Новое поле
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      folderIds: folderIds ?? this.folderIds,
      sortOrder: sortOrder ?? this.sortOrder,
      isPrivate: isPrivate ?? this.isPrivate,  // Новое поле
      collapsed: collapsed ?? this.collapsed,  // Новое поле
    );
  }
}
