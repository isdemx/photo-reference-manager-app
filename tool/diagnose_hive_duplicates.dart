import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:photographers_reference_app/src/domain/entities/category.dart';
import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/domain/entities/tag_category.dart';

void main(List<String> args) async {
  final options = _parseArgs(args);
  if (options == null) {
    _printUsage();
    exit(64);
  }

  final hiveDir = Directory(options.hiveDir);
  if (!hiveDir.existsSync()) {
    stderr.writeln('Hive dir not found: ${hiveDir.path}');
    exit(66);
  }

  Hive.init(hiveDir.path);
  _safeRegisterAdapters();

  final categoryBox = await Hive.openBox<Category>('categories');
  final folderBox = await Hive.openBox<Folder>('folders');
  final tagBox = await Hive.openBox<TagLite>('tags');
  final tagCategoryBox = await Hive.openBox<TagCategory>('tag_categories');

  try {
    _reportCategories(categoryBox, options);
    stdout.writeln('');
    _reportFolders(folderBox, options);
    stdout.writeln('');
    _reportTags(tagBox, tagCategoryBox, options);
  } finally {
    await Hive.close();
  }
}

class _Options {
  final String hiveDir;
  final bool caseInsensitive;
  final int limit;

  const _Options({
    required this.hiveDir,
    required this.caseInsensitive,
    required this.limit,
  });
}

_Options? _parseArgs(List<String> args) {
  String? hiveDir;
  var caseInsensitive = true;
  var limit = 50;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--hive-dir' && i + 1 < args.length) {
      hiveDir = args[++i];
    } else if (arg == '--case-sensitive') {
      caseInsensitive = false;
    } else if (arg == '--limit' && i + 1 < args.length) {
      limit = int.tryParse(args[++i]) ?? limit;
    } else if (arg == '--help' || arg == '-h') {
      return null;
    }
  }

  if (hiveDir == null || hiveDir.isEmpty) {
    return null;
  }

  return _Options(
    hiveDir: hiveDir,
    caseInsensitive: caseInsensitive,
    limit: limit,
  );
}

void _printUsage() {
  stdout.writeln('Usage:');
  stdout.writeln(
      '  dart run tool/diagnose_hive_duplicates.dart --hive-dir <path> [--limit 50] [--case-sensitive]');
}

void _safeRegisterAdapters() {
  _registerIfNeeded<Category>(0, CategoryAdapter());
  _registerIfNeeded<Folder>(1, FolderAdapter());
  _registerIfNeeded<TagLite>(3, TagLiteAdapter());
  _registerIfNeeded<TagCategory>(200, TagCategoryAdapter());
}

void _registerIfNeeded<T>(int typeId, TypeAdapter<T> adapter) {
  if (!Hive.isAdapterRegistered(typeId)) {
    Hive.registerAdapter<T>(adapter);
  }
}

String _normalizeName(String input, {required bool caseInsensitive}) {
  final trimmed = input.trim().replaceAll(RegExp(r'\s+'), ' ');
  return caseInsensitive ? trimmed.toLowerCase() : trimmed;
}

void _reportFolders(Box<Folder> folderBox, _Options options) {
  final folders = folderBox.values.toList();
  stdout.writeln('[Folders] total: ${folders.length}');

  final byName = <String, List<Folder>>{};
  final byNameAndCategory = <String, List<Folder>>{};

  for (final folder in folders) {
    final nameKey = _normalizeName(folder.name,
        caseInsensitive: options.caseInsensitive);
    byName.putIfAbsent(nameKey, () => []).add(folder);

    final compositeKey = '$nameKey::${folder.categoryId}';
    byNameAndCategory.putIfAbsent(compositeKey, () => []).add(folder);
  }

  final dupByName = byName.entries.where((e) => e.value.length > 1).toList();
  final dupByNameAndCategory =
      byNameAndCategory.entries.where((e) => e.value.length > 1).toList();

  stdout.writeln('[Folders] duplicates by name: ${dupByName.length}');
  _printFolderGroups(dupByName, options.limit);

  stdout.writeln('[Folders] duplicates by name+category: ${dupByNameAndCategory.length}');
  _printFolderGroups(dupByNameAndCategory, options.limit, includeCategory: true);
}

void _printFolderGroups(List<MapEntry<String, List<Folder>>> groups, int limit,
    {bool includeCategory = false}) {
  if (groups.isEmpty) {
    stdout.writeln('  none');
    return;
  }

  final capped = groups.take(limit).toList();
  for (final entry in capped) {
    final folders = entry.value;
    final sample = folders
        .take(5)
        .map((f) => '${_keyForBoxValue(f)}:${f.id}')
        .join(', ');
    final name = folders.first.name;
    final categoryId = folders.first.categoryId;
    final label = includeCategory
        ? '"$name" (categoryId: $categoryId)'
        : '"$name"';
    stdout.writeln('  $label -> ${folders.length} items');
    stdout.writeln('    hiveKey:id: $sample');
  }

  if (groups.length > limit) {
    stdout.writeln('  ... and ${groups.length - limit} more');
  }
}

void _reportTags(
  Box<TagLite> tagBox,
  Box<TagCategory> tagCategoryBox,
  _Options options,
) {
  final tags = tagBox.values.toList();
  stdout.writeln('[Tags] total: ${tags.length}');

  final categoriesById = <String, String>{
    for (final c in tagCategoryBox.values) c.id: c.name,
  };

  final byName = <String, List<TagLite>>{};
  final byNameAndCategory = <String, List<TagLite>>{};
  final byId = <String, List<TagLite>>{};

  for (final tag in tags) {
    final nameKey =
        _normalizeName(tag.name, caseInsensitive: options.caseInsensitive);
    byName.putIfAbsent(nameKey, () => []).add(tag);

    final compositeKey = '$nameKey::${tag.tagCategoryId ?? 'null'}';
    byNameAndCategory.putIfAbsent(compositeKey, () => []).add(tag);

    byId.putIfAbsent(tag.id, () => []).add(tag);
  }

  final dupByName = byName.entries.where((e) => e.value.length > 1).toList();
  final dupByNameAndCategory =
      byNameAndCategory.entries.where((e) => e.value.length > 1).toList();

  stdout.writeln('[Tags] duplicates by name: ${dupByName.length}');
  _printTagGroups(dupByName, categoriesById, options.limit);

  stdout.writeln('[Tags] duplicates by name+category: ${dupByNameAndCategory.length}');
  _printTagGroups(dupByNameAndCategory, categoriesById, options.limit,
      includeCategory: true);

  final dupById = byId.entries.where((e) => e.value.length > 1).toList();
  stdout.writeln('[Tags] duplicates by id: ${dupById.length}');
  _printTagGroups(dupById, categoriesById, options.limit, includeCategory: true);
}

void _printTagGroups(
  List<MapEntry<String, List<TagLite>>> groups,
  Map<String, String> categoriesById,
  int limit, {
  bool includeCategory = false,
}) {
  if (groups.isEmpty) {
    stdout.writeln('  none');
    return;
  }

  final capped = groups.take(limit).toList();
  for (final entry in capped) {
    final tags = entry.value;
    final sample = tags
        .take(5)
        .map((t) => '${_keyForBoxValue(t)}:${t.id}')
        .join(', ');
    final name = tags.first.name;
    String label;
    if (includeCategory) {
      final categoryId = tags.first.tagCategoryId;
      final categoryName =
          categoryId == null ? 'No category' : categoriesById[categoryId] ?? 'Unknown';
      label = '"$name" (category: $categoryName, id: $categoryId)';
    } else {
      label = '"$name"';
    }
    stdout.writeln('  $label -> ${tags.length} items');
    stdout.writeln('    hiveKey:id: $sample');
  }

  if (groups.length > limit) {
    stdout.writeln('  ... and ${groups.length - limit} more');
  }
}

void _reportCategories(Box<Category> categoryBox, _Options options) {
  final categories = categoryBox.values.toList();
  stdout.writeln('[Categories] total: ${categories.length}');

  final byName = <String, List<Category>>{};
  for (final category in categories) {
    final nameKey = _normalizeName(category.name,
        caseInsensitive: options.caseInsensitive);
    byName.putIfAbsent(nameKey, () => []).add(category);
  }

  final dupByName = byName.entries.where((e) => e.value.length > 1).toList();
  stdout.writeln('[Categories] duplicates by name: ${dupByName.length}');
  if (dupByName.isEmpty) {
    stdout.writeln('  none');
    return;
  }

  final capped = dupByName.take(options.limit).toList();
  for (final entry in capped) {
    final items = entry.value;
    final sample = items
        .take(5)
        .map((c) => '${_keyForBoxValue(c)}:${c.id}')
        .join(', ');
    final name = items.first.name;
    stdout.writeln('  "$name" -> ${items.length} items');
    stdout.writeln('    hiveKey:id: $sample');
  }
  if (dupByName.length > options.limit) {
    stdout.writeln('  ... and ${dupByName.length - options.limit} more');
  }
}

String _keyForBoxValue(HiveObject obj) {
  final key = obj.key;
  return key == null ? 'null' : key.toString();
}

class TagLite {
  final String id;
  final String name;
  final int colorValue;
  final String? tagCategoryId;

  TagLite({
    required this.id,
    required this.name,
    required this.colorValue,
    this.tagCategoryId,
  });
}

class TagLiteAdapter extends TypeAdapter<TagLite> {
  @override
  final int typeId = 3;

  @override
  TagLite read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TagLite(
      id: fields[0] as String,
      name: fields[1] as String,
      colorValue: fields[2] as int,
      tagCategoryId: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TagLite obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.colorValue)
      ..writeByte(3)
      ..write(obj.tagCategoryId);
  }
}
