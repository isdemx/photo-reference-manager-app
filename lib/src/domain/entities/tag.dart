import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

part 'tag.g.dart';

@HiveType(typeId: 3)
class Tag extends HiveObject with EquatableMixin {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int colorValue;

  @HiveField(3)
  String? tagCategoryId;

  Tag({
    required this.id,
    required this.name,
    required this.colorValue,
    this.tagCategoryId,
  });

  Color get color => Color(colorValue);
  set color(Color newColor) => colorValue = newColor.value;

  @override
  List<Object?> get props => [id, name, colorValue, tagCategoryId];

  @override
  String toString() {
    return 'Tag{id: $id, name: $name, colorValue: $colorValue, tagCategoryId: $tagCategoryId}';
  }

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'] as String,
      name: json['name'] as String,
      colorValue: json['colorValue'] as int,
      tagCategoryId: json['tagCategoryId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'colorValue': colorValue,
      'tagCategoryId': tagCategoryId,
    };
  }

  Tag copyWith({
    String? id,
    String? name,
    int? colorValue,
    String? tagCategoryId,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      tagCategoryId: tagCategoryId ?? this.tagCategoryId,
    );
  }
}
