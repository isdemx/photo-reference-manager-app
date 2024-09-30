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

  @HiveField(5)
  int sortOrder;

  Folder({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.photoIds,
    required this.dateCreated,
    required this.sortOrder,
  });
}
