import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  // Регистрируем адаптеры
  Hive.registerAdapter(CategoryAdapter());
  Hive.registerAdapter(FolderAdapter());
  Hive.registerAdapter(PhotoAdapter());
  Hive.registerAdapter(TagAdapter());
  Hive.registerAdapter(UserSettingsAdapter());

  // Инициализация баз данных
  final tagBox = await Hive.openBox<Tag>('tags');
  final tagRepository = TagRepositoryImpl(tagBox);
  await tagRepository.initializeDefaultTags();

  final categoryBox = await Hive.openBox<Category>('categories');
  final categoryRepository = CategoryRepositoryImpl(categoryBox);
  await categoryRepository.initializeDefaultCategory();

  // Миграция для обновления старых данных
  await migratePhotoBox();

  runApp(MyApp());
}

Future<void> migratePhotoBox() async {
  print('Starting migration...');
  final box = await Hive.openBox<Photo>('photos');
  for (var key in box.keys) {
    final photo = box.get(key);
    if (photo != null && photo.mediaType == null) {
      photo.mediaType = 'image'; // Устанавливаем значение по умолчанию
      await box.put(key, photo); // Сохраняем обновления
      print('Migrated photo with key $key');
    }
  }
  print('Migration complete');
}

class MyApp extends StatelessWidget {
  final Future<void> _initHive = _initializeHive();

  static Future<void> openHiveBoxes() async {
    print('Opening Hive boxes...');
    await Hive.openBox<Category>('categories');
    await Hive.openBox<Folder>('folders');
    await Hive.openBox<Photo>('photos');
    await Hive.openBox<Tag>('tags');
    print('Hive boxes opened successfully.');
  }

  static Future<void> _initializeHive() async {
    print('Initializing Hive...');
    await openHiveBoxes();
    await PhotoPathHelper().initialize();
    print('Hive initialization complete.');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initHive,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return const PhotographersReferenceApp();
        } else if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text('Error initializing Hive: ${snapshot.error}'),
              ),
            ),
          );
        } else {
          return const MaterialApp(
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }
      },
    );
  }
}

class PhotographersReferenceApp extends StatelessWidget {
  const PhotographersReferenceApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<CategoryRepositoryImpl>(
          create: (context) => CategoryRepositoryImpl(Hive.box('categories')),
        ),
        RepositoryProvider<FolderRepositoryImpl>(
          create: (context) => FolderRepositoryImpl(Hive.box('folders')),
        ),
        RepositoryProvider<PhotoRepositoryImpl>(
          create: (context) => PhotoRepositoryImpl(Hive.box('photos')),
        ),
        RepositoryProvider<TagRepositoryImpl>(
          create: (context) => TagRepositoryImpl(Hive.box('tags')),
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
            create: (context) => SessionBloc(),
          ),
          BlocProvider<FilterBloc>(
            create: (context) => FilterBloc(),
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
            // '/upload': (context) => const UploadScreen(),
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
              // Проверяем, есть ли переданный folder
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
