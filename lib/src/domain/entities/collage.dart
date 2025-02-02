import 'package:hive/hive.dart';
part 'collage.g.dart'; // <-- для генерации адаптера

@HiveType(typeId: 101) // <-- используйте свой уникальный ID
class CollageItem extends HiveObject {
  @HiveField(0)
  String fileName; // имя файла, который содержит фото

  @HiveField(1)
  double offsetX;

  @HiveField(2)
  double offsetY;

  @HiveField(3)
  double scale;

  @HiveField(4)
  double rotation;

  @HiveField(5)
  double baseWidth;

  @HiveField(6)
  double baseHeight;

  @HiveField(7)
  double internalOffsetX;

  @HiveField(8)
  double internalOffsetY;

  @HiveField(9)
  double brightness;

  @HiveField(10)
  double saturation;

  @HiveField(11)
  double temp;

  @HiveField(12)
  double hue;

  @HiveField(13)
  double cropRectLeft;

  @HiveField(14)
  double cropRectTop;

  @HiveField(15)
  double cropRectRight;

  @HiveField(16)
  double cropRectBottom;

  @HiveField(17)
  int zIndex;

  CollageItem({
    required this.fileName,
    required this.offsetX,
    required this.offsetY,
    required this.scale,
    required this.rotation,
    required this.baseWidth,
    required this.baseHeight,
    required this.internalOffsetX,
    required this.internalOffsetY,
    required this.brightness,
    required this.saturation,
    required this.temp,
    required this.hue,
    required this.cropRectLeft,
    required this.cropRectTop,
    required this.cropRectRight,
    required this.cropRectBottom,
    required this.zIndex,
  });
}

@HiveType(typeId: 100) // <-- используйте свой уникальный ID
class Collage extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  /// Сохраняем цвет фона (Color.value)
  @HiveField(2)
  int backgroundColorValue;

  /// Список элементов-«фото» (CollageItem)
  @HiveField(3)
  List<CollageItem> items;

  @HiveField(4) // <-- добавляем новое поле
  DateTime? dateCreated;

  @HiveField(5) // <-- добавляем новое поле
  DateTime? dateUpdated;

  Collage({
    required this.id,
    required this.title,
    required this.backgroundColorValue,
    required this.items,
    required this.dateCreated, // <-- добавили
    required this.dateUpdated, // <-- добавили
  });
}
