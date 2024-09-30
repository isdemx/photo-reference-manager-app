import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'tag.g.dart';

@HiveType(typeId: 3)
class Tag extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int colorValue; // Сохраняем цвет как int

  Tag({
    required this.id,
    required this.name,
    required this.colorValue,
  });

  // Геттер для получения объекта Color из colorValue
  Color get color => Color(colorValue);

  // Сеттер для установки colorValue из объекта Color
  set color(Color newColor) => colorValue = newColor.value;
}
