import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'user_settings.g.dart';

@HiveType(typeId: 4)
class UserSettings extends HiveObject {
  @HiveField(0)
  List<String> preferredFolders;

  @HiveField(1)
  Map<String, Color> tagColors;

  UserSettings({
    required this.preferredFolders,
    required this.tagColors,
  });
}
