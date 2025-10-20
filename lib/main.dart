import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p; // <--- Добавьте этот импорт
import 'package:photographers_reference_app/backup.service.dart';

// Импортируем все нужные сущности, адаптеры и репозитории
import 'package:photographers_reference_app/src/data/repositories/category_repository_impl.dart';
import 'package:photographers_reference_app/src/data/repositories/collage_repository_impl.dart';
import 'package:photographers_reference_app/src/data/repositories/folder_repository_impl.dart';
import 'package:photographers_reference_app/src/data/repositories/photo_repository_impl.dart';
import 'package:photographers_reference_app/src/data/repositories/tag_repository_impl.dart';
import 'package:photographers_reference_app/src/domain/entities/category.dart';
import 'package:photographers_reference_app/src/domain/entities/collage.dart';
import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/domain/entities/user_settings.dart';

import 'package:photographers_reference_app/src/presentation/bloc/category_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/collage_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/filter_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/folder_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/session_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';

import 'package:photographers_reference_app/src/presentation/screens/all_photos_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/all_tags_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/folder_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/main_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/my_collages_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/photo_viewer_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/tag_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/upload_screen.dart';
import 'package:photographers_reference_app/src/presentation/widgets/rating_prompt_handler.dart';
import 'package:photographers_reference_app/src/services/export_service.dart';

import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';
import 'package:photographers_reference_app/src/domain/entities/tag_category.dart';
import 'package:photographers_reference_app/src/domain/repositories/tag_category_repository.dart';
import 'package:photographers_reference_app/src/data/repositories/tag_category_repository_impl.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_category_bloc.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Точка входа
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Инициализация Hive
  await Hive.initFlutter();

  // 2. Регистрация всех адаптеров
  Hive.registerAdapter(CategoryAdapter());
  Hive.registerAdapter(FolderAdapter());
  Hive.registerAdapter(PhotoAdapter());
  Hive.registerAdapter(TagAdapter());
  Hive.registerAdapter(UserSettingsAdapter());
  Hive.registerAdapter(CollageAdapter()); // typeId=100
  Hive.registerAdapter(CollageItemAdapter()); // typeId=101
  Hive.registerAdapter(TagCategoryAdapter()); // typeId = 200

  // await ExportService.run();
  // await ImportJsonService.run();

  // 3. Открытие всех боксов (по одному разу).
  final tagBox = await Hive.openBox<Tag>('tags');
  final categoryBox = await Hive.openBox<Category>('categories');
  final folderBox = await Hive.openBox<Folder>('folders');
  final photoBox = await Hive.openBox<Photo>('photos');
  final collageBox = await Hive.openBox<Collage>('collages');
  final tagCategoryBox = await Hive.openBox<TagCategory>('tag_categories');

  // Миграция тегов
  // await migrateTagBox(tagBox, photoBox);

  // 4. Запуск миграции (если нужно)
  await migratePhotoBox(photoBox);

  // Инициализация дефолтных данных (например, начальные теги/категории)
  final tagRepository = TagRepositoryImpl(tagBox);
  await tagRepository.initializeDefaultTags();

  final tagCategoryRepository =
      TagCategoryRepositoryImpl(tagCategoryBox, tagBox);
  await tagCategoryRepository.initializeDefaultTagCategory();

  final categoryRepository = CategoryRepositoryImpl(categoryBox);
  await categoryRepository.initializeDefaultCategory();

  final collageRepository = CollageRepositoryImpl(collageBox);

  // (Опционально) Инициализируем пути для фото
  await PhotoPathHelper().initialize();

  // 5. Запуск приложения. Передаём открытые боксы в MyApp, чтобы дальше не открывать их повторно.

  runApp(MyApp(
    tagBox: tagBox,
    categoryBox: categoryBox,
    folderBox: folderBox,
    photoBox: photoBox,
    collageBox: collageBox,
    tagCategoryBox: tagCategoryBox,
  ));

  WidgetsBinding.instance.addPostFrameCallback((_) {
    BackupService.promptAndRun(
      navigatorKey.currentContext!, // navigatorKey — GlobalKey<NavigatorState>
    );
  });
}

/// Миграция бокса тегов:
/// 1) rekey: все записи -> ключ == tag.id
/// 2) merge: объединить теги с одинаковым именем (case-insensitive)
/// 3) обновить все фото: заменить id дублей на мастер.id
Future<void> migrateTagBox(Box<Tag> tagBox, Box<Photo> photoBox) async {
  debugPrint('[TAG MIGRATION] Start');

  // 0) Снимем снапшот
  final entries = <dynamic, Tag>{};
  for (final k in tagBox.keys) {
    try {
      final t = tagBox.get(k);
      if (t != null) entries[k] = t;
    } catch (e) {
      debugPrint('[TAG MIGRATION] skip key=$k read error: $e');
    }
  }
  debugPrint('[TAG MIGRATION] snapshot size=${entries.length}');

  // 1) rekey: key == tag.id
  for (final entry in entries.entries) {
    final oldKey = entry.key;
    final tag = entry.value;

    try {
      if (oldKey == tag.id) continue;

      final existing = tagBox.get(tag.id);
      if (existing == null) {
        await tagBox.put(tag.id, tag);
        debugPrint('[TAG MIGRATION] Rekey $oldKey -> ${tag.id}');
      } else {
        final keepExisting =
            (existing.name.trim().length >= tag.name.trim().length);
        if (!keepExisting) {
          await tagBox.put(tag.id, tag);
          debugPrint('[TAG MIGRATION] Replace content on key ${tag.id}');
        }
      }
      await tagBox.delete(oldKey);
      debugPrint('[TAG MIGRATION] Deleted old key: $oldKey');
    } catch (e) {
      debugPrint('[TAG MIGRATION] rekey failed for key=$oldKey err=$e');
    }
  }

  // 1b) перечитать после rekey
  final idToTag = <String, Tag>{};
  for (final k in tagBox.keys) {
    try {
      final t = tagBox.get(k);
      if (t != null) idToTag[t.id] = t;
    } catch (_) {}
  }
  debugPrint('[TAG MIGRATION] after rekey uniqueIds=${idToTag.length}');

  // 2) групповое объединение (case-insensitive by name)
  final nameGroups = <String, List<Tag>>{};
  for (final t in idToTag.values) {
    final name = (t.name ?? '').trim();
    if (name.isEmpty) continue; // пропускаем совсем битые
    final key = name.toLowerCase();
    nameGroups.putIfAbsent(key, () => []).add(t);
  }

  final redirectMap = <String, String>{};
  for (final group in nameGroups.values) {
    if (group.length <= 1) continue;

    // выбор мастера
    Tag master = group.first;
    for (final t in group) {
      if ((master.tagCategoryId == null || master.tagCategoryId!.isEmpty) &&
          (t.tagCategoryId != null && t.tagCategoryId!.isNotEmpty)) {
        master = t;
      }
    }

    // категория: первая ненулевая
    String? mergedCategory = master.tagCategoryId;
    if (mergedCategory == null || mergedCategory.isEmpty) {
      for (final t in group) {
        if (t.tagCategoryId != null && t.tagCategoryId!.isNotEmpty) {
          mergedCategory = t.tagCategoryId;
          break;
        }
      }
    }

    // обновим мастера при необходимости
    if (mergedCategory != master.tagCategoryId) {
      try {
        master = master.copyWith(tagCategoryId: mergedCategory);
        await tagBox.put(master.id, master);
        idToTag[master.id] = master;
        debugPrint(
            '[TAG MIGRATION] master "${master.name}" set category=${master.tagCategoryId}');
      } catch (e) {
        debugPrint('[TAG MIGRATION] master update failed: $e');
      }
    }

    // удалим дубли
    for (final dup in group) {
      if (dup.id == master.id) continue;
      try {
        redirectMap[dup.id] = master.id;
        await tagBox.delete(dup.id);
        idToTag.remove(dup.id);
        debugPrint(
            '[TAG MIGRATION] removed dup "${dup.name}" ${dup.id} -> ${master.id}');
      } catch (e) {
        debugPrint('[TAG MIGRATION] remove dup failed id=${dup.id}: $e');
      }
    }
  }

  // 3) обновим фото
  if (redirectMap.isNotEmpty) {
    debugPrint(
        '[TAG MIGRATION] updating photos, redirects=${redirectMap.length}');
    for (final photoKey in photoBox.keys) {
      try {
        final p = photoBox.get(photoKey);
        if (p == null) continue;

        bool changed = false;
        final newTagIdsSet = <String>{};
        for (final tagId in p.tagIds) {
          final redirected = redirectMap[tagId];
          if (redirected != null) {
            newTagIdsSet.add(redirected);
            changed = true;
          } else {
            newTagIdsSet.add(tagId);
          }
        }

        if (changed) {
          final updated = p.copyWith(tagIds: newTagIdsSet.toList());
          await photoBox.put(photoKey, updated);
          debugPrint('[TAG MIGRATION] photo ${p.id} updated');
        }
      } catch (e) {
        debugPrint('[TAG MIGRATION] photo update failed key=$photoKey: $e');
      }
    }
  }

  debugPrint('[TAG MIGRATION] Done');
}

/// Пример миграции, если надо заполнить новые поля
Future<void> migratePhotoBox(Box<Photo> photoBox) async {
  print('Starting migration...');
  // Получаем актуальный каталог фотографий
  final appDir = await getApplicationDocumentsDirectory();
  final photosDir = p.join(appDir.path, 'photos');

  for (var key in photoBox.keys) {
    final photo = photoBox.get(key);
    if (photo != null) {
      // Убедитесь, что каждое новое поле имеет значение
      photo.mediaType ??= 'image';
      photo.videoPreview ??= '';
      photo.videoDuration ??= '';

      // Если это видео и videoPreview хранит абсолютный путь,
      // заменим его на basename
      if (photo.mediaType == 'video' &&
          photo.videoPreview != null &&
          photo.videoPreview!.isNotEmpty) {
        if (photo.videoPreview!.startsWith(photosDir)) {
          photo.videoPreview = p.basename(photo.videoPreview!);
          print('Updated videoPreview for photo ${photo.id} to relative path.');
        }
      }

      // Сохраните обновлённый объект
      await photoBox.put(key, photo);
      print('Migrated photo with key $key');
    }
  }
  print('Migration complete');
}

class MyApp extends StatelessWidget {
  final Box<Tag> tagBox;
  final Box<Category> categoryBox;
  final Box<Folder> folderBox;
  final Box<Photo> photoBox;
  final Box<Collage> collageBox;
  final Box<TagCategory> tagCategoryBox;

  const MyApp({
    Key? key,
    required this.tagBox,
    required this.categoryBox,
    required this.folderBox,
    required this.photoBox,
    required this.collageBox,
    required this.tagCategoryBox,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<CategoryRepositoryImpl>(
          create: (_) => CategoryRepositoryImpl(categoryBox),
        ),
        RepositoryProvider<FolderRepositoryImpl>(
          create: (_) => FolderRepositoryImpl(folderBox),
        ),
        RepositoryProvider<PhotoRepositoryImpl>(
          create: (_) => PhotoRepositoryImpl(photoBox),
        ),
        RepositoryProvider<TagRepositoryImpl>(
          create: (_) => TagRepositoryImpl(tagBox),
        ),
        RepositoryProvider<CollageRepositoryImpl>(
          create: (_) => CollageRepositoryImpl(collageBox),
        ),
        RepositoryProvider<TagCategoryRepositoryImpl>(
          create: (_) => TagCategoryRepositoryImpl(tagCategoryBox, tagBox),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<CategoryBloc>(
            create: (context) => CategoryBloc(
              categoryRepository:
                  RepositoryProvider.of<CategoryRepositoryImpl>(context),
            )..add(LoadCategories()),
          ),
          BlocProvider<FolderBloc>(
            create: (context) => FolderBloc(
              folderRepository:
                  RepositoryProvider.of<FolderRepositoryImpl>(context),
            )..add(LoadFolders()),
          ),
          BlocProvider<PhotoBloc>(
            create: (context) => PhotoBloc(
              photoRepository:
                  RepositoryProvider.of<PhotoRepositoryImpl>(context),
            )..add(LoadPhotos()),
          ),
          BlocProvider<TagBloc>(
            create: (context) => TagBloc(
              tagRepository: RepositoryProvider.of<TagRepositoryImpl>(context),
            )..add(LoadTags()),
          ),
          BlocProvider<SessionBloc>(
            create: (_) => SessionBloc(),
          ),
          BlocProvider<FilterBloc>(
            create: (_) => FilterBloc(),
          ),
          BlocProvider<CollageBloc>(
            create: (context) => CollageBloc(
              collageRepository:
                  RepositoryProvider.of<CollageRepositoryImpl>(context),
            )..add(LoadCollages()),
          ),
          BlocProvider<TagCategoryBloc>(
            create: (context) => TagCategoryBloc(
              tagCategoryRepository:
                  RepositoryProvider.of<TagCategoryRepositoryImpl>(context),
            )..add(const LoadTagCategories()),
          ),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Photographers Reference',
          theme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: Colors.black,
            scaffoldBackgroundColor: Colors.black,
            appBarTheme: const AppBarTheme(
              color: Colors.black,
            ),
          ),
          home: Builder(
            builder: (context) {
              Future.delayed(const Duration(seconds: 1), () async {
                if (await RatingPromptHandler.shouldShowPrompt()) {
                  RatingPromptHandler.showRatingDialog(context);
                }
              });
              return const MainScreen();
            },
          ),
          routes: {
            '/all_tags': (context) => const AllTagsScreen(),
            '/all_photos': (context) => const AllPhotosScreen(),
            '/my_collages': (context) => const MyCollagesScreen(),
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/folder') {
              final folder = settings.arguments as Folder;
              return MaterialPageRoute(
                builder: (context) => FolderScreen(folder: folder),
              );
            } else if (settings.name == '/upload') {
              final folder = settings.arguments as Folder?;
              return MaterialPageRoute(
                builder: (context) => UploadScreen(folder: folder),
              );
            } else if (settings.name == '/photo') {
              final args = settings.arguments as Map<String, dynamic>;
              final photos = args['photos'] as List<Photo>;
              final index = args['index'] as int;
              return MaterialPageRoute(
                builder: (context) => PhotoViewerScreen(
                  photos: photos,
                  initialIndex: index,
                ),
              );
            } else if (settings.name == '/tag') {
              final tag = settings.arguments as Tag;
              return MaterialPageRoute(
                builder: (context) => TagScreen(tag: tag),
              );
            }
            return null;
          },
        ),
      ),
    );
  }
}
