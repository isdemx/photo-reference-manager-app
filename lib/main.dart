// lib/main.dart

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
import 'package:photographers_reference_app/src/presentation/bloc/folder_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';
import 'package:photographers_reference_app/src/presentation/screens/all_photos_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/folder_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/main_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/photo_viewer_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/tag_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/upload_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  // Регистрируем адаптеры
  Hive.registerAdapter(CategoryAdapter());
  Hive.registerAdapter(FolderAdapter());
  Hive.registerAdapter(PhotoAdapter());
  Hive.registerAdapter(TagAdapter());
  Hive.registerAdapter(UserSettingsAdapter());

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final Future<void> _initHive = _initializeHive();

  static Future<void> _initializeHive() async {
    // Удаляем боксы, если необходимо
    // await Hive.deleteBoxFromDisk('categories');
    // await Hive.deleteBoxFromDisk('folders');
    // await Hive.deleteBoxFromDisk('photos');
    // await Hive.deleteBoxFromDisk('tags');
    // await Hive.deleteBoxFromDisk('photos');

    // Открываем боксы
    await Hive.openBox<Category>('categories');
    await Hive.openBox<Folder>('folders');
    await Hive.openBox<Photo>('photos');
    await Hive.openBox<Tag>('tags');
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
          // Показываем индикатор загрузки пока Hive инициализируется
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
    return MultiBlocProvider(
      providers: [
        BlocProvider<CategoryBloc>(
          create: (context) => CategoryBloc(
            categoryRepository: CategoryRepositoryImpl(Hive.box('categories')),
          )..add(LoadCategories()),
        ),
        BlocProvider<FolderBloc>(
          create: (context) => FolderBloc(
            folderRepository: FolderRepositoryImpl(Hive.box('folders')),
          )..add(LoadFolders()),
        ),
        BlocProvider<PhotoBloc>(
          create: (context) => PhotoBloc(
            photoRepository: PhotoRepositoryImpl(Hive.box('photos')),
          )..add(LoadPhotos()),
        ),
        BlocProvider<TagBloc>(
          create: (context) => TagBloc(
            tagRepository: TagRepositoryImpl(Hive.box('tags')),
          )..add(LoadTags()),
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
          '/upload': (context) => const UploadScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/folder') {
            final folder = settings.arguments as Folder;
            return MaterialPageRoute(
              builder: (context) => FolderScreen(folder: folder),
            );
          } else if (settings.name == '/photo') {
            final args = settings.arguments as Map<String, dynamic>;
            final photos =
                args['photos'] as List<Photo>; // Получаем список фотографий
            final index = args['index'] as int; // Получаем индекс фотографии
            return MaterialPageRoute(
              builder: (context) => PhotoViewerScreen(
                photos: photos,
                initialIndex: index,
              ),
            );
          } else if (settings.name == '/all_photos') {
            return MaterialPageRoute(
              builder: (context) => const AllPhotosScreen(),
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
    );
  }
}
