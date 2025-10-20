// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_category.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TagCategoryAdapter extends TypeAdapter<TagCategory> {
  @override
  final int typeId = 200;

  @override
  TagCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TagCategory(
      id: fields[0] as String,
      name: fields[1] as String,
      dateCreated: fields[2] as DateTime,
      sortOrder: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, TagCategory obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.dateCreated)
      ..writeByte(3)
      ..write(obj.sortOrder);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TagCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
