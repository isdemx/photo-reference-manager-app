
import 'package:hive/hive.dart';
import 'package:photographers_reference_app/src/domain/entities/category.dart';
import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';

Future<void> openHiveBoxes() async {
  await Hive.openBox<Photo>('photos');
  await Hive.openBox<Tag>('tags');
  await Hive.openBox<Category>('categories');
  await Hive.openBox<Folder>('folders');
}
