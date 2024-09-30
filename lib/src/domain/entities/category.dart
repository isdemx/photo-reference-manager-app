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

  Category({
    required this.id,
    required this.name,
    required this.folderIds,
    required this.sortOrder,
  });
}
