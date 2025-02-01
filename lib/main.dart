import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;  // <--- Добавьте этот импорт

// Импортируем все нужные сущности, адаптеры и репозитории
import 'package:photographers_reference_app/src/data/repositories/category_repository_impl.dart';
import 'package:photographers_reference_app/src/data/repositories/folder_repository_impl.dart';
import 'package:photographers_reference_app/src/data/repositories/photo_repository_impl.dart';
import 'package:photographers_reference_app/src/data/repositories/tag_repository_impl.dart';
import 'package:photographers_reference_app/src/domain/entities/category.dart';
import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/domain/entities/user_settings.dart';

import 'package:photographers_reference_app/src/presentation/bloc/category_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/filter_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/folder_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/session_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';

import 'package:photographers_reference_app/src/presentation/screens/all_photos_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/all_tags_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/folder_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/main_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/photo_viewer_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/tag_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/upload_screen.dart';

import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';

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

  // 3. Открытие всех боксов (по одному разу).
  final tagBox = await Hive.openBox<Tag>('tags');
  final categoryBox = await Hive.openBox<Category>('categories');
  final folderBox = await Hive.openBox<Folder>('folders');
  final photoBox = await Hive.openBox<Photo>('photos');

  // 4. Запуск миграции (если нужно)
  await migratePhotoBox(photoBox);

  // Инициализация дефолтных данных (например, начальные теги/категории)
  final tagRepository = TagRepositoryImpl(tagBox);
  await tagRepository.initializeDefaultTags();

  final categoryRepository = CategoryRepositoryImpl(categoryBox);
  await categoryRepository.initializeDefaultCategory();

  // (Опционально) Инициализируем пути для фото
  await PhotoPathHelper().initialize();

  // 5. Запуск приложения. Передаём открытые боксы в MyApp, чтобы дальше не открывать их повторно.
  runApp(MyApp(
    tagBox: tagBox,
    categoryBox: categoryBox,
    folderBox: folderBox,
    photoBox: photoBox,
  ));
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

  const MyApp({
    Key? key,
    required this.tagBox,
    required this.categoryBox,
    required this.folderBox,
    required this.photoBox,
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
        ],
        child: MaterialApp(
          title: 'Photographers Reference',
          theme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: Colors.black,
            scaffoldBackgroundColor: Colors.black,
            appBarTheme: const AppBarTheme(
              color: Colors.black,
            ),
          ),
          home: const MainScreen(),
          routes: {
            '/all_tags': (context) => const AllTagsScreen(),
            '/all_photos': (context) => const AllPhotosScreen(),
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
