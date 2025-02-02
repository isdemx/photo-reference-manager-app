// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collage.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

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
    );
  }

  @override
  void write(BinaryWriter writer, CollageItem obj) {
    writer
      ..writeByte(18)
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
      ..write(obj.zIndex);
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
    );
  }

  @override
  void write(BinaryWriter writer, Collage obj) {
    writer
      ..writeByte(6)
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
      ..write(obj.dateUpdated);
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
