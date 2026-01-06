// lib/src/domain/entities/photo.dart

import 'package:hive/hive.dart';

part 'photo.g.dart';

@HiveType(typeId: 2)
class Photo extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String path;

  @HiveField(2)
  final List<String> folderIds;

  @HiveField(3)
  final List<String> tagIds;

  @HiveField(4)
  final String? comment;

  @HiveField(5)
  final DateTime dateAdded;

  @HiveField(6)
  final int sortOrder;

  @HiveField(7)
  bool isStoredInApp;

  @HiveField(8)
  String fileName;

  @HiveField(9)
  final Map<String, double>? geoLocation;

  @HiveField(10)
  String mediaType;

  @HiveField(11)
  String? videoPreview;

  @HiveField(12)
  String? videoDuration;

  @HiveField(13)
  double? videoWidth;

  @HiveField(14)
  double? videoHeight;

  Photo({
    required this.id,
    required this.path,
    required this.fileName,
    required this.folderIds,
    required this.tagIds,
    this.comment,
    required this.dateAdded,
    required this.sortOrder,
    required this.mediaType,
    this.videoPreview,
    this.videoDuration,
    this.videoWidth,
    this.videoHeight,
    this.isStoredInApp = false,
    this.geoLocation,
  });

  @override
  String toString() {
    return 'Photo{id: $id, fileName: "$fileName", geoLocation: $geoLocation, isStoredInApp: $isStoredInApp, tagIds: $tagIds, folderIds: $folderIds}';
  }

  bool get isImage => mediaType == 'image';
  bool get isVideo => mediaType == 'video';

  Photo copyWith({
    String? id,
    String? path,
    String? fileName,
    List<String>? folderIds,
    List<String>? tagIds,
    String? comment,
    DateTime? dateAdded,
    int? sortOrder,
    String? mediaType,
    String? videoPreview,
    String? videoDuration,
    double? videoWidth,
    double? videoHeight,
    bool? isStoredInApp,
    Map<String, double>? geoLocation,
  }) {
    return Photo(
      id: id ?? this.id,
      path: path ?? this.path,
      fileName: fileName ?? this.fileName,
      folderIds: folderIds ?? this.folderIds,
      tagIds: tagIds ?? this.tagIds,
      comment: comment ?? this.comment,
      dateAdded: dateAdded ?? this.dateAdded,
      sortOrder: sortOrder ?? this.sortOrder,
      mediaType: mediaType ?? this.mediaType,
      videoPreview: videoPreview ?? this.videoPreview,
      videoDuration: videoDuration ?? this.videoDuration,
      videoWidth: videoWidth ?? this.videoWidth,
      videoHeight: videoHeight ?? this.videoHeight,
      isStoredInApp: isStoredInApp ?? this.isStoredInApp,
      geoLocation: geoLocation ?? this.geoLocation,
    );
  }

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['id'],
      path: json['path'],
      fileName: json['fileName'],
      folderIds: List<String>.from(json['folderIds'] ?? []),
      tagIds: List<String>.from(json['tagIds'] ?? []),
      comment: json['comment'] as String?,
      dateAdded: DateTime.parse(json['dateAdded']),
      sortOrder: json['sortOrder'],
      mediaType: json['mediaType'],
      videoPreview: json['videoPreview'],
      videoDuration: json['videoDuration'],
      videoWidth: (json['videoWidth'] as num?)?.toDouble(),
      videoHeight: (json['videoHeight'] as num?)?.toDouble(),
      isStoredInApp: json['isStoredInApp'] ?? false,
      geoLocation: json['geoLocation'] != null
          ? Map<String, double>.from(json['geoLocation'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'path': path,
      'fileName': fileName,
      'folderIds': folderIds,
      'tagIds': tagIds,
      'comment': comment,
      'dateAdded': dateAdded.toIso8601String(),
      'sortOrder': sortOrder,
      'mediaType': mediaType,
      'videoPreview': videoPreview,
      'videoDuration': videoDuration,
      'videoWidth': videoWidth,
      'videoHeight': videoHeight,
      'isStoredInApp': isStoredInApp,
      'geoLocation': geoLocation,
    };
  }
}
