import 'package:hive/hive.dart';

part 'photo_info.g.dart';

@HiveType(typeId: 11)
class PhotoInfo extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String path;

  @HiveField(2)
  int width;

  @HiveField(3)
  int height;

  @HiveField(4)
  String thumbPath;

  PhotoInfo({
    required this.id,
    required this.path,
    required this.width,
    required this.height,
    required this.thumbPath,
  });

  double get ratio => height == 0 ? 1.0 : width / height;

  PhotoInfo copyWith({
    String? id,
    String? path,
    int? width,
    int? height,
    String? thumbPath,
  }) {
    return PhotoInfo(
      id: id ?? this.id,
      path: path ?? this.path,
      width: width ?? this.width,
      height: height ?? this.height,
      thumbPath: thumbPath ?? this.thumbPath,
    );
  }
}
