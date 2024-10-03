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

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final Future<void> _initHive = _initializeHive();

  static Future<void> openHiveBoxes() async {
    print('open box');
    await Hive.openBox<Category>('categories');
    await Hive.openBox<Folder>('folders');
    await Hive.openBox<Photo>('photos');
    await Hive.openBox<Tag>('tags');
    print('opened box');
  }

  static Future<void> _initializeHive() async {
    print('init');
    // Открываем боксы
    await openHiveBoxes();

    await PhotoPathHelper().initialize();
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
              categoryRepository: RepositoryProvider.of<CategoryRepositoryImpl>(context),
            )..add(LoadCategories()),
          ),
          BlocProvider<FolderBloc>(
            create: (context) => FolderBloc(
              folderRepository: RepositoryProvider.of<FolderRepositoryImpl>(context),
            )..add(LoadFolders()),
          ),
          BlocProvider<PhotoBloc>(
            create: (context) => PhotoBloc(
              photoRepository: RepositoryProvider.of<PhotoRepositoryImpl>(context),
            )..add(LoadPhotos()),
          ),
          BlocProvider<TagBloc>(
            create: (context) => TagBloc(
              tagRepository: RepositoryProvider.of<TagRepositoryImpl>(context),
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
            '/all_tags': (context) => const AllTagsScreen(),
            '/all_photos': (context) => const AllPhotosScreen(),
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/folder') {
              final folder = settings.arguments as Folder;
              return MaterialPageRoute(
                builder: (context) => FolderScreen(folder: folder),
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
