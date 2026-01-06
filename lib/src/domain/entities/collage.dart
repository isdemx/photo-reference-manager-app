import 'package:hive/hive.dart';
part 'collage.g.dart';

@HiveType(typeId: 101)
class CollageItem extends HiveObject {
  @HiveField(0)
  String fileName;

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

  @HiveField(18)
  double? videoStartFrac; // 0..1

  @HiveField(19)
  double? videoEndFrac; // 0..1

  @HiveField(20)
  double? videoSpeed; // 0.1..4.0

  @HiveField(21)
  double contrast;

  @HiveField(22)
  double opacity;

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
    this.videoStartFrac,
    this.videoEndFrac,
    this.videoSpeed,
    this.contrast = 1.0,
    this.opacity = 1.0,
  });

  factory CollageItem.fromJson(Map<String, dynamic> json) => CollageItem(
        fileName: json['fileName'],
        offsetX: json['offsetX'],
        offsetY: json['offsetY'],
        scale: json['scale'],
        rotation: json['rotation'],
        baseWidth: json['baseWidth'],
        baseHeight: json['baseHeight'],
        internalOffsetX: json['internalOffsetX'],
        internalOffsetY: json['internalOffsetY'],
        brightness: json['brightness'],
        saturation: json['saturation'],
        temp: json['temp'],
        hue: json['hue'],
        cropRectLeft: json['cropRectLeft'],
        cropRectTop: json['cropRectTop'],
        cropRectRight: json['cropRectRight'],
        cropRectBottom: json['cropRectBottom'],
        zIndex: json['zIndex'],
        videoStartFrac: (json.containsKey('videoStartFrac'))
            ? (json['videoStartFrac'] as num?)?.toDouble()
            : null,
        videoEndFrac: (json.containsKey('videoEndFrac'))
            ? (json['videoEndFrac'] as num?)?.toDouble()
            : null,
        videoSpeed: (json.containsKey('videoSpeed'))
            ? (json['videoSpeed'] as num?)?.toDouble()
            : null,
        contrast: (json['contrast'] as num?)?.toDouble() ?? 1.0,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      );

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'offsetX': offsetX,
        'offsetY': offsetY,
        'scale': scale,
        'rotation': rotation,
        'baseWidth': baseWidth,
        'baseHeight': baseHeight,
        'internalOffsetX': internalOffsetX,
        'internalOffsetY': internalOffsetY,
        'brightness': brightness,
        'saturation': saturation,
        'temp': temp,
        'hue': hue,
        'cropRectLeft': cropRectLeft,
        'cropRectTop': cropRectTop,
        'cropRectRight': cropRectRight,
        'cropRectBottom': cropRectBottom,
        'zIndex': zIndex,
        'videoStartFrac': videoStartFrac, // <-- new
        'videoEndFrac': videoEndFrac, // <-- new
        'videoSpeed': videoSpeed, // <-- new
        'contrast': contrast,
        'opacity': opacity,
      };
}

@HiveType(typeId: 100)
class Collage extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  int backgroundColorValue;

  @HiveField(3)
  List<CollageItem> items;

  @HiveField(4)
  DateTime? dateCreated;

  @HiveField(5)
  DateTime? dateUpdated;

  @HiveField(6)
  String? previewPath;

  @HiveField(7)
  bool? isPrivate;

  @HiveField(8)
  double? canvasOffsetX;

  @HiveField(9)
  double? canvasOffsetY;

  @HiveField(10)
  double? canvasScale;

  Collage(
      {required this.id,
      required this.title,
      required this.backgroundColorValue,
      required this.items,
      required this.dateCreated,
      required this.dateUpdated,
      this.previewPath,
      this.isPrivate,
      this.canvasOffsetX,
      this.canvasOffsetY,
      this.canvasScale});

  factory Collage.fromJson(Map<String, dynamic> json) => Collage(
        id: json['id'],
        title: json['title'],
        backgroundColorValue: json['backgroundColorValue'],
        items: (json['items'] as List<dynamic>)
            .map((e) => CollageItem.fromJson(e))
            .toList(),
        dateCreated: json['dateCreated'] != null
            ? DateTime.parse(json['dateCreated'])
            : null,
        dateUpdated: json['dateUpdated'] != null
            ? DateTime.parse(json['dateUpdated'])
            : null,
        previewPath: json['previewPath'],
        isPrivate: json['isPrivate'] as bool?,
        canvasOffsetX: (json['canvasOffsetX'] as num?)?.toDouble(),
        canvasOffsetY: (json['canvasOffsetY'] as num?)?.toDouble(),
        canvasScale: (json['canvasScale'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'backgroundColorValue': backgroundColorValue,
        'items': items.map((e) => e.toJson()).toList(),
        'dateCreated': dateCreated?.toIso8601String(),
        'dateUpdated': dateUpdated?.toIso8601String(),
        'previewPath': previewPath,
        'isPrivate': isPrivate,
        'canvasOffsetX': canvasOffsetX,
        'canvasOffsetY': canvasOffsetY,
        'canvasScale': canvasScale,
      };
}
