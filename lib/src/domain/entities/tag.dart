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

  Tag({
    required this.id,
    required this.name,
    required this.colorValue,
  });

  // Геттер для получения объекта Color из colorValue
  Color get color => Color(colorValue);

  // Сеттер для установки colorValue из объекта Color
  set color(Color newColor) => colorValue = newColor.value;

  @override
  List<Object?> get props => [id, name, colorValue];

  @override
  String toString() {
    return 'Tag{id: $id, name: $name, colorValue: $colorValue}';
  }
}
