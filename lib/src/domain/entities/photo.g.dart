// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PhotoAdapter extends TypeAdapter<Photo> {
  @override
  final int typeId = 2;

  @override
  Photo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Photo(
      id: fields[0] as String,
      path: fields[1] as String,
      fileName: fields[8] as String,
      folderIds: (fields[2] as List).cast<String>(),
      tagIds: (fields[3] as List).cast<String>(),
      comment: fields[4] as String,
      dateAdded: fields[5] as DateTime,
      sortOrder: fields[6] as int,
      mediaType: fields[10] as String,
      videoPreview: fields[11] as String?,
      videoDuration: fields[12] as String?,
      isStoredInApp: fields[7] as bool,
      geoLocation: (fields[9] as Map?)?.cast<String, double>(),
    );
  }

  @override
  void write(BinaryWriter writer, Photo obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.path)
      ..writeByte(2)
      ..write(obj.folderIds)
      ..writeByte(3)
      ..write(obj.tagIds)
      ..writeByte(4)
      ..write(obj.comment)
      ..writeByte(5)
      ..write(obj.dateAdded)
      ..writeByte(6)
      ..write(obj.sortOrder)
      ..writeByte(7)
      ..write(obj.isStoredInApp)
      ..writeByte(8)
      ..write(obj.fileName)
      ..writeByte(9)
      ..write(obj.geoLocation)
      ..writeByte(10)
      ..write(obj.mediaType)
      ..writeByte(11)
      ..write(obj.videoPreview)
      ..writeByte(12)
      ..write(obj.videoDuration);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
