import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart'; // <- здесь живёт DartPluginRegistrant
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:photographers_reference_app/backup.service.dart';
// desktop_multi_window не обязателен здесь, но пускай остаётся — окно создаётся из сервиса
import 'package:desktop_multi_window/desktop_multi_window.dart';

// ==== DATA / DOMAIN ====
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
import 'package:photographers_reference_app/src/domain/entities/tag_category.dart';
import 'package:photographers_reference_app/src/domain/repositories/tag_category_repository.dart';

// ==== BLoC / UI ====
import 'package:photographers_reference_app/src/presentation/bloc/category_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/collage_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/filter_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/folder_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/session_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_category_bloc.dart';

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
import 'package:photographers_reference_app/src/data/repositories/tag_category_repository_impl.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// --------------------- ENTRY ---------------------

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // ВТОРОЙ движок (новое окно) требует ручной регистрации плагинов
  DartPluginRegistrant.ensureInitialized();

  // payload, переданный при создании окна
  final String payload = args.isNotEmpty ? args.first : '{}';
  final Map<String, dynamic> initialArgs = _safeDecode(payload);

  // Без window_manager в дочерних окнах

  runZonedGuarded(() async {
    // 1) Hive init
    await Hive.initFlutter();

    // 2) Идемпотентная регистрация адаптеров (важно для multi-engine)
    _registerAdaptersSafely();

    // 3) Открытие боксов
    final tagBox = await Hive.openBox<Tag>('tags');
    final categoryBox = await Hive.openBox<Category>('categories');
    final folderBox = await Hive.openBox<Folder>('folders');
    final photoBox = await Hive.openBox<Photo>('photos');
    final collageBox = await Hive.openBox<Collage>('collages');
    final tagCategoryBox = await Hive.openBox<TagCategory>('tag_categories');

    // 4) Миграции/дефолты
    await migratePhotoBox(photoBox);
    await TagRepositoryImpl(tagBox).initializeDefaultTags();
    await TagCategoryRepositoryImpl(tagCategoryBox, tagBox).initializeDefaultTagCategory();
    await CategoryRepositoryImpl(categoryBox).initializeDefaultCategory();
    await PhotoPathHelper().initialize();

    // 5) Запуск приложения
    runApp(MyApp(
      tagBox: tagBox,
      categoryBox: categoryBox,
      folderBox: folderBox,
      photoBox: photoBox,
      collageBox: collageBox,
      tagCategoryBox: tagCategoryBox,
      initialArgs: initialArgs,
    ));

    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   // Бэкап-диалог только при «обычном» старте (когда не передан спец-роут)
    //   if (((initialArgs['route'] as String?) ?? '').isEmpty && navigatorKey.currentContext != null) {
    //     BackupService.promptAndRun(navigatorKey.currentContext!);
    //   }
    // });
  }, (e, st) {
    // Чтобы видеть причину «чёрного экрана», если где-то в изоляте упало
    // ignore: avoid_print
    print('[AppError] $e\n$st');
  });
}

// --------------------- HIVE UTILS ---------------------

void _registerAdaptersSafely() {
  void safeRegister(void Function() f) {
    try {
      f();
    } catch (_) {
      // повторная регистрация в другом движке — норм, игнорируем
    }
  }

  safeRegister(() => Hive.registerAdapter(CategoryAdapter()));
  safeRegister(() => Hive.registerAdapter(FolderAdapter()));
  safeRegister(() => Hive.registerAdapter(PhotoAdapter()));
  safeRegister(() => Hive.registerAdapter(TagAdapter()));          // @HiveType(typeId: 3)
  safeRegister(() => Hive.registerAdapter(UserSettingsAdapter()));
  safeRegister(() => Hive.registerAdapter(CollageAdapter()));      // typeId = 100
  safeRegister(() => Hive.registerAdapter(CollageItemAdapter()));  // typeId = 101
  safeRegister(() => Hive.registerAdapter(TagCategoryAdapter()));  // typeId = 200
}

Map<String, dynamic> _safeDecode(String s) {
  try {
    final m = jsonDecode(s);
    if (m is Map<String, dynamic>) return m;
    return {};
  } catch (_) {
    return {};
  }
}

// --------------------- MIGRATIONS ---------------------

Future<void> migrateTagBox(Box<Tag> tagBox, Box<Photo> photoBox) async {
  // оставь здесь свою реализацию миграции тегов
}

Future<void> migratePhotoBox(Box<Photo> photoBox) async {
  print('Starting migration...');
  final appDir = await getApplicationDocumentsDirectory();
  final photosDir = p.join(appDir.path, 'photos');

  for (var key in photoBox.keys) {
    final photo = photoBox.get(key);
    if (photo != null) {
      photo.mediaType ??= 'image';
      photo.videoPreview ??= '';
      photo.videoDuration ??= '';

      if (photo.mediaType == 'video' &&
          photo.videoPreview != null &&
          photo.videoPreview!.isNotEmpty) {
        if (photo.videoPreview!.startsWith(photosDir)) {
          photo.videoPreview = p.basename(photo.videoPreview!);
          print('Updated videoPreview for photo ${photo.id} to relative path.');
        }
      }

      await photoBox.put(key, photo);
      print('Migrated photo with key $key');
    }
  }
  print('Migration complete');
}

// --------------------- APP ---------------------

class MyApp extends StatelessWidget {
  final Box<Tag> tagBox;
  final Box<Category> categoryBox;
  final Box<Folder> folderBox;
  final Box<Photo> photoBox;
  final Box<Collage> collageBox;
  final Box<TagCategory> tagCategoryBox;
  final Map<String, dynamic> initialArgs;

  const MyApp({
    Key? key,
    required this.tagBox,
    required this.categoryBox,
    required this.folderBox,
    required this.photoBox,
    required this.collageBox,
    required this.tagCategoryBox,
    required this.initialArgs,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => CategoryRepositoryImpl(categoryBox)),
        RepositoryProvider(create: (_) => FolderRepositoryImpl(folderBox)),
        RepositoryProvider(create: (_) => PhotoRepositoryImpl(photoBox)),
        RepositoryProvider(create: (_) => TagRepositoryImpl(tagBox)),
        RepositoryProvider(create: (_) => CollageRepositoryImpl(collageBox)),
        RepositoryProvider(create: (_) => TagCategoryRepositoryImpl(tagCategoryBox, tagBox)),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (ctx) => CategoryBloc(
            categoryRepository: RepositoryProvider.of<CategoryRepositoryImpl>(ctx),
          )..add(LoadCategories())),
          BlocProvider(create: (ctx) => FolderBloc(
            folderRepository: RepositoryProvider.of<FolderRepositoryImpl>(ctx),
          )..add(LoadFolders())),
          BlocProvider(create: (ctx) => PhotoBloc(
            photoRepository: RepositoryProvider.of<PhotoRepositoryImpl>(ctx),
          )..add(LoadPhotos())),
          BlocProvider(create: (ctx) => TagBloc(
            tagRepository: RepositoryProvider.of<TagRepositoryImpl>(ctx),
          )..add(LoadTags())),
          BlocProvider(create: (_) => SessionBloc()),
          BlocProvider(create: (_) => FilterBloc()),
          BlocProvider(create: (ctx) => CollageBloc(
            collageRepository: RepositoryProvider.of<CollageRepositoryImpl>(ctx),
          )..add(LoadCollages())),
          BlocProvider(create: (ctx) => TagCategoryBloc(
            tagCategoryRepository: RepositoryProvider.of<TagCategoryRepositoryImpl>(ctx),
          )..add(const LoadTagCategories())),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Photographers Reference',
          theme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: Colors.black,
            scaffoldBackgroundColor: Colors.black,
            appBarTheme: const AppBarTheme(color: Colors.black),
          ),

          // Рейтинг-попап — только при «обычном» запуске
          builder: (context, child) {
            final hasCustomRoute = ((initialArgs['route'] as String?) ?? '').isNotEmpty;
            if (!hasCustomRoute) {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (await RatingPromptHandler.shouldShowPrompt()) {
                  RatingPromptHandler.showRatingDialog(context);
                }
              });
            }
            return child ?? const SizedBox.shrink();
          },

          // Стартовый стек — сразу, без чёрного кадра
          onGenerateInitialRoutes: (_) {
            final String route = (initialArgs['route'] as String?) ?? '';
            final Map<String, dynamic> args =
                Map<String, dynamic>.from(initialArgs)..remove('route');

            if (route == '/photoById') {
              final String? photoId = args['photoId'] as String?;
              if (photoId != null && photoId.isNotEmpty) {
                Photo? target;
                for (final p in photoBox.values) {
                  if (p.id == photoId) {
                    target = p;
                    break;
                  }
                }
                if (target != null) {
                  return [
                    MaterialPageRoute(
                      builder: (_) => PhotoViewerScreen(
                        photos: [target!], // без "!"
                        initialIndex: 0,
                      ),
                    ),
                  ];
                }
              }
              return [MaterialPageRoute(builder: (_) => const MainScreen())];
            }

            if (route == '/my_collages') {
              return [MaterialPageRoute(builder: (_) => const MyCollagesScreen())];
            }
            if (route == '/all_photos') {
              return [MaterialPageRoute(builder: (_) => const AllPhotosScreen())];
            }
            if (route == '/all_tags') {
              return [MaterialPageRoute(builder: (_) => const AllTagsScreen())];
            }
            if (route == '/folder') {
              final folder = args['folder'] as Folder;
              return [MaterialPageRoute(builder: (_) => FolderScreen(folder: folder))];
            }
            if (route == '/upload') {
              final folder = args['folder'] as Folder?;
              return [MaterialPageRoute(builder: (_) => UploadScreen(folder: folder))];
            }
            if (route == '/photo') {
              final photos = args['photos'] as List<Photo>;
              final index = args['index'] as int;
              return [
                MaterialPageRoute(
                  builder: (_) => PhotoViewerScreen(photos: photos, initialIndex: index),
                )
              ];
            }
            if (route == '/tag') {
              final tag = args['tag'] as Tag;
              return [MaterialPageRoute(builder: (_) => TagScreen(tag: tag))];
            }

            // дефолт: полное приложение
            return [MaterialPageRoute(builder: (_) => const MainScreen())];
          },

          routes: {
            '/all_tags': (_) => const AllTagsScreen(),
            '/all_photos': (_) => const AllPhotosScreen(),
            '/my_collages': (_) => const MyCollagesScreen(),
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/folder') {
              final folder = settings.arguments as Folder;
              return MaterialPageRoute(builder: (_) => FolderScreen(folder: folder));
            } else if (settings.name == '/upload') {
              final folder = settings.arguments as Folder?;
              return MaterialPageRoute(builder: (_) => UploadScreen(folder: folder));
            } else if (settings.name == '/photo') {
              final args = settings.arguments as Map<String, dynamic>;
              final photos = args['photos'] as List<Photo>;
              final index = args['index'] as int;
              return MaterialPageRoute(
                builder: (_) => PhotoViewerScreen(photos: photos, initialIndex: index),
              );
            } else if (settings.name == '/tag') {
              final tag = settings.arguments as Tag;
              return MaterialPageRoute(builder: (_) => TagScreen(tag: tag));
            }
            return null;
          },
        ),
      ),
    );
  }
}
