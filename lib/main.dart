import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// desktop_multi_window не обязателен здесь, но пускай остаётся — окно создаётся из сервиса
import 'package:window_manager/window_manager.dart';

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
// ==== BLoC / UI ====
import 'package:photographers_reference_app/src/presentation/bloc/category_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/collage_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/filter_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/folder_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/session_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_category_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/theme_cubit.dart';

import 'package:photographers_reference_app/src/presentation/screens/all_photos_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/all_tags_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/folder_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/lite_photo_viewer_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/lite_viewer_dispatch_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/main_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/my_collages_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/photo_viewer_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/tag_screen.dart';
import 'package:photographers_reference_app/src/presentation/screens/upload_screen.dart';
import 'package:photographers_reference_app/src/presentation/widgets/rating_prompt_handler.dart';
import 'package:photographers_reference_app/src/presentation/widgets/migration_overlay_host.dart';
import 'package:photographers_reference_app/src/presentation/widgets/app_lock_host.dart';
import 'package:photographers_reference_app/src/presentation/widgets/drag_drop_import_overlay.dart';

import 'package:photographers_reference_app/src/services/shared_tags_sync_service.dart';
import 'package:photographers_reference_app/src/services/shared_folders_sync_service.dart';
import 'package:photographers_reference_app/src/data/repositories/tag_category_repository_impl.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';
import 'package:photographers_reference_app/src/services/drag_drop_import_service.dart';
import 'package:photographers_reference_app/src/services/macos_file_open_service.dart';
import 'package:photographers_reference_app/src/services/theme_settings_service.dart';
import 'package:photographers_reference_app/src/services/navigation_history_service.dart';
import 'package:photographers_reference_app/src/presentation/theme/app_theme.dart';
import 'package:photographers_reference_app/src/services/window_service.dart';
import 'package:photographers_reference_app/src/services/app_reload_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
bool _ratingPromptScheduled = false;
bool _firstFrameRendered = false;
bool _fatalStartupUiShown = false;

void _openLog(String message) {
  debugPrint('[RefmaOpenFiles][dart] $message');
}

// --------------------- ENTRY ---------------------

void main(List<String> args) async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (!_firstFrameRendered) {
        _runFatalStartupApp(
          details.exception,
          details.stack ?? StackTrace.current,
        );
      }
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      if (!_firstFrameRendered) {
        _runFatalStartupApp(error, stack);
        return true;
      }
      return false;
    };
    // ВТОРОЙ движок (новое окно) требует ручной регистрации плагинов
    DartPluginRegistrant.ensureInitialized();
    if (!kIsWeb && Platform.isIOS) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }

    // payload, переданный при создании окна
    final bool isMultiWindowLaunch =
        args.length >= 3 && args.first == 'multi_window';
    final String payload = _extractLaunchPayload(args);
    final Map<String, dynamic> initialArgs = _safeDecode(payload);
    _openLog(
      'main start args=$args isMultiWindowLaunch=$isMultiWindowLaunch payload=$payload initialArgs=$initialArgs',
    );
    if (!isMultiWindowLaunch) {
      final Map<String, dynamic> macOSInitialRoute =
          await MacOSFileOpenService.loadInitialRoutePayload();
      _openLog('macOSInitialRoute=$macOSInitialRoute');
      if (((initialArgs['route'] as String?) ?? '').isEmpty &&
          macOSInitialRoute.isNotEmpty) {
        initialArgs
          ..clear()
          ..addAll(macOSInitialRoute);
        _openLog('initialArgs replaced from macOSInitialRoute -> $initialArgs');
      }
    }

    // Без window_manager в дочерних окнах
    final bool isChildWindow =
        ((initialArgs['route'] as String?) ?? '').isNotEmpty;
    _openLog('isChildWindow=$isChildWindow route=${initialArgs['route']}');
    if (!kIsWeb &&
        (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      await windowManager.ensureInitialized();
    }
    if (!kIsWeb &&
        (Platform.isMacOS || Platform.isWindows || Platform.isLinux) &&
        !isChildWindow) {
      if (Platform.isMacOS) {
        try {
          final themePreference =
              await ThemeSettingsService().loadPreference();
          final resolvedBrightness = switch (themePreference) {
            AppThemePreference.dark => Brightness.dark,
            AppThemePreference.light => Brightness.light,
            AppThemePreference.system =>
              PlatformDispatcher.instance.platformBrightness,
          };
          final windowBackgroundColor = resolvedBrightness == Brightness.dark
              ? AppThemes.darkColors.surfaceAlt
              : const Color(0xFFC7CED8);
          final windowOptions = WindowOptions(
            titleBarStyle: TitleBarStyle.hidden,
            windowButtonVisibility: true,
            backgroundColor: windowBackgroundColor,
          );
          await windowManager.waitUntilReadyToShow(windowOptions, () async {
            await windowManager.show();
            await windowManager.focus();
          });
        } catch (_) {}
      }
    }

    // 1) Hive init
    await Hive.initFlutter();

    // 2) Идемпотентная регистрация адаптеров (важно для multi-engine)
    _registerAdaptersSafely();

    final initialData = await _loadAppBootstrapData();

    // 5) Запуск приложения
    final shouldShowWindowAfterFirstFrame = !kIsWeb &&
        Platform.isMacOS &&
        !isMultiWindowLaunch &&
        ((initialArgs['route'] as String?) ?? '').isNotEmpty;
    runApp(_AppBootstrap(
      initialArgs: initialArgs,
      initialData: initialData,
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _firstFrameRendered = true;
      if (shouldShowWindowAfterFirstFrame) {
        try {
          await windowManager.show();
          await windowManager.focus();
        } catch (_) {}
      }
    });

    await MacOSFileOpenService.startListening(
      onFilesOpened: (filePaths) {
        _openLog('startListening callback filePaths=$filePaths');
        for (final filePath in filePaths) {
          _openLog('opening lite viewer window for $filePath');
          WindowService.openLiteViewerWindow(filePath: filePath);
        }
      },
    );
    _openLog('startListening registered');

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
    _runFatalStartupApp(e, st);
  });
}

void _runFatalStartupApp(Object error, StackTrace stackTrace) {
  if (_fatalStartupUiShown) return;
  _fatalStartupUiShown = true;
  try {
    runApp(_StartupFailureApp(error: error, stackTrace: stackTrace));
  } catch (_) {
    // Если даже error UI не смог подняться, остаётся только native log.
  }
}

class _AppBootstrapData {
  const _AppBootstrapData({
    required this.tagBox,
    required this.categoryBox,
    required this.folderBox,
    required this.photoBox,
    required this.collageBox,
    required this.tagCategoryBox,
  });

  final Box<Tag> tagBox;
  final Box<Category> categoryBox;
  final Box<Folder> folderBox;
  final Box<Photo> photoBox;
  final Box<Collage> collageBox;
  final Box<TagCategory> tagCategoryBox;
}

Future<_AppBootstrapData> _loadAppBootstrapData() async {
  final tagBox = await Hive.openBox<Tag>('tags');
  final categoryBox = await Hive.openBox<Category>('categories');
  final folderBox = await Hive.openBox<Folder>('folders');
  final photoBox = await Hive.openBox<Photo>('photos');
  final collageBox = await Hive.openBox<Collage>('collages');
  final tagCategoryBox = await Hive.openBox<TagCategory>('tag_categories');

  final tagRepository = TagRepositoryImpl(tagBox);
  await tagRepository.initializeDefaultTags();
  await TagCategoryRepositoryImpl(tagCategoryBox, tagBox)
      .initializeDefaultTagCategory();
  await SharedTagsSyncService().syncTags(await tagRepository.getTags());
  await CategoryRepositoryImpl(categoryBox).initializeDefaultCategory();
  await SharedFoldersSyncService().syncFolders(folderBox.values.toList());
  await PhotoPathHelper().initialize();

  return _AppBootstrapData(
    tagBox: tagBox,
    categoryBox: categoryBox,
    folderBox: folderBox,
    photoBox: photoBox,
    collageBox: collageBox,
    tagCategoryBox: tagCategoryBox,
  );
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap({
    required this.initialArgs,
    required this.initialData,
  });

  final Map<String, dynamic> initialArgs;
  final _AppBootstrapData initialData;

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  late _AppBootstrapData _data;
  bool _reloading = false;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    AppReloadService.instance.register(_reloadApp);
  }

  @override
  void dispose() {
    AppReloadService.instance.unregister(_reloadApp);
    super.dispose();
  }

  Future<void> _reloadApp() async {
    if (_reloading) return;
    setState(() {
      _reloading = true;
    });
    await Hive.close();
    final data = await _loadAppBootstrapData();
    if (!mounted) return;
    setState(() {
      _data = data;
      _reloading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_reloading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Refreshing data...'),
              ],
            ),
          ),
        ),
      );
    }

    return MyApp(
      tagBox: _data.tagBox,
      categoryBox: _data.categoryBox,
      folderBox: _data.folderBox,
      photoBox: _data.photoBox,
      collageBox: _data.collageBox,
      tagCategoryBox: _data.tagCategoryBox,
      initialArgs: widget.initialArgs,
    );
  }
}

String _extractLaunchPayload(List<String> args) {
  if (args.length >= 3 && args.first == 'multi_window') {
    _openLog('extractLaunchPayload multi_window payload=${args[2]}');
    return args[2];
  }
  if (args.isNotEmpty) {
    _openLog('extractLaunchPayload firstArg=${args.first}');
    return args.first;
  }
  _openLog('extractLaunchPayload default {}');
  return '{}';
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
  safeRegister(
      () => Hive.registerAdapter(TagAdapter())); // @HiveType(typeId: 3)
  safeRegister(() => Hive.registerAdapter(UserSettingsAdapter()));
  safeRegister(() => Hive.registerAdapter(CollageAdapter())); // typeId = 100
  safeRegister(
      () => Hive.registerAdapter(CollageItemAdapter())); // typeId = 101
  safeRegister(() =>
      Hive.registerAdapter(CollageViewZoneEntryAdapter())); // typeId = 102
  safeRegister(
      () => Hive.registerAdapter(TagCategoryAdapter())); // typeId = 200
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

class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp({
    required this.error,
    required this.stackTrace,
  });

  final Object error;
  final StackTrace stackTrace;

  @override
  Widget build(BuildContext context) {
    final message = error.toString();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppThemes.darkTheme(transitions: const PageTransitionsTheme()),
      home: Scaffold(
        backgroundColor: AppThemes.darkColors.canvas,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Refma could not start',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE8E5DF),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your photos are still stored on this device. Please update Refma to the latest version from the App Store.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    color: Color(0xFFBBB8B3),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppThemes.darkColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppThemes.darkColors.border),
                  ),
                  child: SelectableText(
                    message,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Color(0xFF8F8A82),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      stackTrace.toString(),
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        color: Color(0xFF6E6B66),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
    required this.tagBox,
    required this.categoryBox,
    required this.folderBox,
    required this.photoBox,
    required this.collageBox,
    required this.tagCategoryBox,
    required this.initialArgs,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bool noDesktopTransitions =
        !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => CategoryRepositoryImpl(categoryBox)),
        RepositoryProvider(create: (_) => FolderRepositoryImpl(folderBox)),
        RepositoryProvider(create: (_) => PhotoRepositoryImpl(photoBox)),
        RepositoryProvider(create: (_) => TagRepositoryImpl(tagBox)),
        RepositoryProvider(create: (_) => CollageRepositoryImpl(collageBox)),
        RepositoryProvider(
            create: (_) => TagCategoryRepositoryImpl(tagCategoryBox, tagBox)),
        RepositoryProvider(
          create: (_) => DragDropImportService(),
          dispose: (service) => service.dispose(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
              create: (ctx) => CategoryBloc(
                    categoryRepository:
                        RepositoryProvider.of<CategoryRepositoryImpl>(ctx),
                  )..add(LoadCategories())),
          BlocProvider(
              create: (ctx) => FolderBloc(
                    folderRepository:
                        RepositoryProvider.of<FolderRepositoryImpl>(ctx),
                  )..add(LoadFolders())),
          BlocProvider(
              create: (ctx) => PhotoBloc(
                    photoRepository:
                        RepositoryProvider.of<PhotoRepositoryImpl>(ctx),
                  )..add(LoadPhotos())),
          BlocProvider(
              create: (ctx) => TagBloc(
                    tagRepository:
                        RepositoryProvider.of<TagRepositoryImpl>(ctx),
                  )..add(LoadTags())),
          BlocProvider(create: (_) => SessionBloc()),
          BlocProvider(create: (_) => FilterBloc()),
          BlocProvider(
              create: (ctx) => CollageBloc(
                    collageRepository:
                        RepositoryProvider.of<CollageRepositoryImpl>(ctx),
                  )..add(LoadCollages())),
          BlocProvider(
              create: (ctx) => TagCategoryBloc(
                    tagCategoryRepository:
                        RepositoryProvider.of<TagCategoryRepositoryImpl>(ctx),
                  )..add(const LoadTagCategories())),
          BlocProvider(
            create: (_) => ThemeCubit(
              settingsService: ThemeSettingsService(),
            )..load(),
          ),
        ],
        child: BlocBuilder<ThemeCubit, ThemeState>(
          builder: (context, themeState) {
            final transitionsTheme = noDesktopTransitions
                ? const PageTransitionsTheme(
                    builders: {
                      TargetPlatform.android: _NoTransitionsBuilder(),
                      TargetPlatform.iOS: _NoTransitionsBuilder(),
                      TargetPlatform.macOS: _NoTransitionsBuilder(),
                      TargetPlatform.windows: _NoTransitionsBuilder(),
                      TargetPlatform.linux: _NoTransitionsBuilder(),
                    },
                  )
                : const PageTransitionsTheme();
            return MaterialApp(
              navigatorKey: navigatorKey,
              navigatorObservers: [NavigationHistoryService.instance.observer],
              title: 'Photographers Reference',
              themeMode: themeState.themeMode,
              theme: AppThemes.lightTheme(transitions: transitionsTheme),
              darkTheme: AppThemes.darkTheme(transitions: transitionsTheme),

              // Рейтинг-попап — только при «обычном» запуске
              builder: (context, child) {
                final hasCustomRoute =
                    ((initialArgs['route'] as String?) ?? '').isNotEmpty;
                final route = (initialArgs['route'] as String?) ?? '';
                final bypassAppLock =
                    route == '/lite_viewer' || route == '/lite_viewer_dispatch';
                if (!hasCustomRoute && !_ratingPromptScheduled) {
                  _ratingPromptScheduled = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    if (await RatingPromptHandler.shouldShowPrompt()) {
                      final navContext = navigatorKey.currentContext;
                      if (navContext == null) return;
                      if (!navContext.mounted) return;
                      RatingPromptHandler.showRatingDialog(navContext);
                    }
                  });
                }
                final content = child ?? const SizedBox.shrink();
                return DragDropImportOverlay(
                  child: AppLockHost(
                    enabled: !bypassAppLock,
                    child: MigrationOverlayHost(child: content),
                  ),
                );
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
                  return [
                    MaterialPageRoute(builder: (_) => const MainScreen())
                  ];
                }

                if (route == '/my_collages') {
                  return [
                    MaterialPageRoute(builder: (_) => const MyCollagesScreen())
                  ];
                }
                if (route == '/all_photos') {
                  return [
                    MaterialPageRoute(builder: (_) => const AllPhotosScreen())
                  ];
                }
                if (route == '/all_tags') {
                  return [
                    MaterialPageRoute(builder: (_) => const AllTagsScreen())
                  ];
                }
                if (route == '/folder') {
                  final folder = args['folder'] as Folder;
                  return [
                    MaterialPageRoute(
                        builder: (_) => FolderScreen(folder: folder))
                  ];
                }
                if (route == '/upload') {
                  final folder = args['folder'] as Folder?;
                  return [
                    MaterialPageRoute(
                        builder: (_) => UploadScreen(folder: folder))
                  ];
                }
                if (route == '/photo') {
                  final photos = args['photos'] as List<Photo>;
                  final index = args['index'] as int;
                  return [
                    MaterialPageRoute(
                      builder: (_) => PhotoViewerScreen(
                          photos: photos, initialIndex: index),
                    )
                  ];
                }
                if (route == '/tag') {
                  final tag = args['tag'] as Tag;
                  return [
                    MaterialPageRoute(builder: (_) => TagScreen(tag: tag))
                  ];
                }
                if (route == '/lite_viewer') {
                  final filePath = args['filePath'] as String?;
                  final initialViewportAspectRatio =
                      (args['initialViewportAspectRatio'] as num?)?.toDouble();
                  if (filePath != null && filePath.isNotEmpty) {
                    return [
                      MaterialPageRoute(
                        builder: (_) => LitePhotoViewerScreen(
                          initialFilePath: filePath,
                          initialViewportAspectRatio:
                              initialViewportAspectRatio,
                        ),
                      ),
                    ];
                  }
                }
                if (route == '/lite_viewer_dispatch') {
                  final filePaths = (args['filePaths'] as List?)
                      ?.whereType<String>()
                      .where((path) => path.isNotEmpty)
                      .toList();
                  if (filePaths != null && filePaths.isNotEmpty) {
                    return [
                      MaterialPageRoute(
                        builder: (_) =>
                            LiteViewerDispatchScreen(filePaths: filePaths),
                      ),
                    ];
                  }
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
                  return MaterialPageRoute(
                      builder: (_) => FolderScreen(folder: folder));
                } else if (settings.name == '/upload') {
                  final folder = settings.arguments as Folder?;
                  return MaterialPageRoute(
                      builder: (_) => UploadScreen(folder: folder));
                } else if (settings.name == '/photo') {
                  final args = settings.arguments as Map<String, dynamic>;
                  final photos = args['photos'] as List<Photo>;
                  final index = args['index'] as int;
                  return MaterialPageRoute(
                    builder: (_) =>
                        PhotoViewerScreen(photos: photos, initialIndex: index),
                  );
                } else if (settings.name == '/tag') {
                  final tag = settings.arguments as Tag;
                  return MaterialPageRoute(builder: (_) => TagScreen(tag: tag));
                } else if (settings.name == '/lite_viewer') {
                  final args = settings.arguments as Map<String, dynamic>;
                  final filePath = args['filePath'] as String;
                  final initialViewportAspectRatio =
                      (args['initialViewportAspectRatio'] as num?)?.toDouble();
                  return MaterialPageRoute(
                    builder: (_) => LitePhotoViewerScreen(
                      initialFilePath: filePath,
                      initialViewportAspectRatio: initialViewportAspectRatio,
                    ),
                  );
                } else if (settings.name == '/lite_viewer_dispatch') {
                  final args = settings.arguments as Map<String, dynamic>;
                  final filePaths = (args['filePaths'] as List)
                      .whereType<String>()
                      .where((path) => path.isNotEmpty)
                      .toList();
                  return MaterialPageRoute(
                    builder: (_) =>
                        LiteViewerDispatchScreen(filePaths: filePaths),
                  );
                }
                return null;
              },
            );
          },
        ),
      ),
    );
  }
}
