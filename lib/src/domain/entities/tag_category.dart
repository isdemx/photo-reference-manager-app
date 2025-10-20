// lib/src/domain/entities/tag_category.dart
import 'package:hive/hive.dart';
import 'package:equatable/equatable.dart';

part 'tag_category.g.dart';

@HiveType(typeId: 200)
class TagCategory extends HiveObject with EquatableMixin {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  DateTime dateCreated;

  @HiveField(3)
  int sortOrder;

  TagCategory({
    required this.id,
    required this.name,
    required this.dateCreated,
    required this.sortOrder,
  });

  @override
  List<Object?> get props => [id, name, dateCreated, sortOrder];

  @override
  String toString() =>
      'TagCategory{id: $id, name: $name, dateCreated: $dateCreated, sortOrder: $sortOrder}';

  factory TagCategory.fromJson(Map<String, dynamic> json) {
    return TagCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      dateCreated: DateTime.parse(json['dateCreated'] as String),
      sortOrder: json['sortOrder'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dateCreated': dateCreated.toIso8601String(),
        'sortOrder': sortOrder,
      };

  TagCategory copyWith({
    String? id,
    String? name,
    DateTime? dateCreated,
    int? sortOrder,
  }) {
    return TagCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      dateCreated: dateCreated ?? this.dateCreated,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
