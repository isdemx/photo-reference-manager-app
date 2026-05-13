// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collage.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CollageDrawingStrokeAdapter extends TypeAdapter<CollageDrawingStroke> {
  @override
  final int typeId = 103;

  @override
  CollageDrawingStroke read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CollageDrawingStroke(
      id: fields[0] as String,
      pointValues: (fields[1] as List).cast<double>(),
      colorValue: fields[2] as int,
      width: (fields[3] as num).toDouble(),
      opacity: (fields[4] as num?)?.toDouble() ?? 1.0,
      isEraser: fields[5] as bool? ?? false,
      zIndex: fields[6] as int? ?? 0,
      tool: fields[7] as int? ?? CollageDrawingStroke.toolPencil,
    );
  }

  @override
  void write(BinaryWriter writer, CollageDrawingStroke obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.pointValues)
      ..writeByte(2)
      ..write(obj.colorValue)
      ..writeByte(3)
      ..write(obj.width)
      ..writeByte(4)
      ..write(obj.opacity)
      ..writeByte(5)
      ..write(obj.isEraser)
      ..writeByte(6)
      ..write(obj.zIndex)
      ..writeByte(7)
      ..write(obj.tool);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollageDrawingStrokeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CollageTextItemAdapter extends TypeAdapter<CollageTextItem> {
  @override
  final int typeId = 104;

  @override
  CollageTextItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CollageTextItem(
      id: fields[0] as String,
      text: fields[1] as String? ?? '',
      offsetX: (fields[2] as num).toDouble(),
      offsetY: (fields[3] as num).toDouble(),
      width: (fields[4] as num?)?.toDouble() ?? 280.0,
      fontSize: (fields[5] as num?)?.toDouble() ?? 32.0,
      colorValue: fields[6] as int? ?? 0xFFFFFFFF,
      opacity: (fields[7] as num?)?.toDouble() ?? 1.0,
      fontFamily: fields[8] as String? ?? 'system',
      bold: fields[9] as bool? ?? false,
      italic: fields[10] as bool? ?? false,
      textAlign: fields[11] as int? ?? CollageTextItem.alignCenter,
      zIndex: fields[12] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, CollageTextItem obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.offsetX)
      ..writeByte(3)
      ..write(obj.offsetY)
      ..writeByte(4)
      ..write(obj.width)
      ..writeByte(5)
      ..write(obj.fontSize)
      ..writeByte(6)
      ..write(obj.colorValue)
      ..writeByte(7)
      ..write(obj.opacity)
      ..writeByte(8)
      ..write(obj.fontFamily)
      ..writeByte(9)
      ..write(obj.bold)
      ..writeByte(10)
      ..write(obj.italic)
      ..writeByte(11)
      ..write(obj.textAlign)
      ..writeByte(12)
      ..write(obj.zIndex);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollageTextItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CollageItemAdapter extends TypeAdapter<CollageItem> {
  @override
  final int typeId = 101;

  @override
  CollageItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CollageItem(
      fileName: fields[0] as String,
      offsetX: fields[1] as double,
      offsetY: fields[2] as double,
      scale: fields[3] as double,
      rotation: fields[4] as double,
      baseWidth: fields[5] as double,
      baseHeight: fields[6] as double,
      internalOffsetX: fields[7] as double,
      internalOffsetY: fields[8] as double,
      brightness: fields[9] as double,
      saturation: fields[10] as double,
      temp: fields[11] as double,
      hue: fields[12] as double,
      cropRectLeft: fields[13] as double,
      cropRectTop: fields[14] as double,
      cropRectRight: fields[15] as double,
      cropRectBottom: fields[16] as double,
      zIndex: fields[17] as int,
      videoStartFrac: fields[18] as double?,
      videoEndFrac: fields[19] as double?,
      videoSpeed: fields[20] as double?,
      contrast: (fields[21] as num?)?.toDouble() ?? 1.0,
      opacity: (fields[22] as num?)?.toDouble() ?? 1.0,
      flipX: fields[23] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, CollageItem obj) {
    writer
      ..writeByte(24)
      ..writeByte(0)
      ..write(obj.fileName)
      ..writeByte(1)
      ..write(obj.offsetX)
      ..writeByte(2)
      ..write(obj.offsetY)
      ..writeByte(3)
      ..write(obj.scale)
      ..writeByte(4)
      ..write(obj.rotation)
      ..writeByte(5)
      ..write(obj.baseWidth)
      ..writeByte(6)
      ..write(obj.baseHeight)
      ..writeByte(7)
      ..write(obj.internalOffsetX)
      ..writeByte(8)
      ..write(obj.internalOffsetY)
      ..writeByte(9)
      ..write(obj.brightness)
      ..writeByte(10)
      ..write(obj.saturation)
      ..writeByte(11)
      ..write(obj.temp)
      ..writeByte(12)
      ..write(obj.hue)
      ..writeByte(13)
      ..write(obj.cropRectLeft)
      ..writeByte(14)
      ..write(obj.cropRectTop)
      ..writeByte(15)
      ..write(obj.cropRectRight)
      ..writeByte(16)
      ..write(obj.cropRectBottom)
      ..writeByte(17)
      ..write(obj.zIndex)
      ..writeByte(18)
      ..write(obj.videoStartFrac)
      ..writeByte(19)
      ..write(obj.videoEndFrac)
      ..writeByte(20)
      ..write(obj.videoSpeed)
      ..writeByte(21)
      ..write(obj.contrast)
      ..writeByte(22)
      ..write(obj.opacity)
      ..writeByte(23)
      ..write(obj.flipX);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollageItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CollageAdapter extends TypeAdapter<Collage> {
  @override
  final int typeId = 100;

  @override
  Collage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Collage(
      id: fields[0] as String,
      title: fields[1] as String,
      backgroundColorValue: fields[2] as int,
      items: (fields[3] as List).cast<CollageItem>(),
      dateCreated: fields[4] as DateTime?,
      dateUpdated: fields[5] as DateTime?,
      previewPath: fields[6] as String?,
      isPrivate: fields[7] as bool?,
      canvasOffsetX: fields[8] as double?,
      canvasOffsetY: fields[9] as double?,
      canvasScale: fields[10] as double?,
      viewZones: (fields[11] as List?)?.cast<CollageViewZoneEntry>(),
      drawingStrokes: (fields[12] as List?)?.cast<CollageDrawingStroke>(),
      textItems: (fields[13] as List?)?.cast<CollageTextItem>(),
    );
  }

  @override
  void write(BinaryWriter writer, Collage obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.backgroundColorValue)
      ..writeByte(3)
      ..write(obj.items)
      ..writeByte(4)
      ..write(obj.dateCreated)
      ..writeByte(5)
      ..write(obj.dateUpdated)
      ..writeByte(6)
      ..write(obj.previewPath)
      ..writeByte(7)
      ..write(obj.isPrivate)
      ..writeByte(8)
      ..write(obj.canvasOffsetX)
      ..writeByte(9)
      ..write(obj.canvasOffsetY)
      ..writeByte(10)
      ..write(obj.canvasScale)
      ..writeByte(11)
      ..write(obj.viewZones)
      ..writeByte(12)
      ..write(obj.drawingStrokes)
      ..writeByte(13)
      ..write(obj.textItems);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CollageViewZoneEntryAdapter extends TypeAdapter<CollageViewZoneEntry> {
  @override
  final int typeId = 102;

  @override
  CollageViewZoneEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CollageViewZoneEntry(
      index: fields[0] as int,
      translationX: fields[1] as double,
      translationY: fields[2] as double,
      scale: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, CollageViewZoneEntry obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.index)
      ..writeByte(1)
      ..write(obj.translationX)
      ..writeByte(2)
      ..write(obj.translationY)
      ..writeByte(3)
      ..write(obj.scale);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollageViewZoneEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
