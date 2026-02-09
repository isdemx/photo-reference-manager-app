import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:photographers_reference_app/src/mini-apps/color_harmony_game.dart';
import 'package:photographers_reference_app/src/mini-apps/hang_photos_game_screen.dart';
import 'package:photographers_reference_app/src/mini-apps/photo_magnet_game_screen.dart';
import 'package:photographers_reference_app/src/presentation/bloc/category_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/session_bloc.dart';
import 'package:photographers_reference_app/src/presentation/helpers/categories_helpers.dart';
import 'package:photographers_reference_app/src/presentation/screens/upload_screen.dart';
import 'package:photographers_reference_app/src/presentation/widgets/category_widget.dart';
import 'package:photographers_reference_app/src/presentation/widgets/settings_dialog.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int logoTapCount = 0;
  Timer? _tapTimer;

  String? _appVersion;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = info.version;
        });
      }
    } catch (_) {
      // в случае ошибки просто оставим null
    }
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    super.dispose();
  }

  void _openSettings(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (dialogCtx) {
        return SettingsDialog(appVersion: _appVersion);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          // Упрощённый заголовок: логотип + тройной тап для приватного режима
          title: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () {
                  logoTapCount++;
                  _tapTimer?.cancel();
                  _tapTimer = Timer(const Duration(seconds: 1), () {
                    logoTapCount = 0;
                  });

                  if (logoTapCount >= 3) {
                    context.read<SessionBloc>().add(ToggleShowPrivateEvent());
                    logoTapCount = 0;
                    _tapTimer?.cancel();

                    final showPrivate =
                        context.read<SessionBloc>().state.showPrivate;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          showPrivate
                              ? 'Private mode enabled'
                              : 'Private mode disabled',
                          style: const TextStyle(
                            color: Color.fromARGB(255, 190, 190, 190),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        duration: const Duration(seconds: 1),
                        backgroundColor: const Color.fromARGB(255, 47, 47, 47),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 10,
                      ),
                    );
                  }
                },
                onLongPress: () {
                  // Сбрасываем счётчик кликов, чтобы не конфликтовал
                  logoTapCount = 0;
                  _tapTimer?.cancel();

                  final rnd = Random();

                  // Список доступных мини-игр
                  final games = [
                    const PhotoMagnetGameScreen(),
                    const HangPhotosGameScreen(),
                    const ColorHarmonyGame(),
                  ];

                  // Выбираем одну рандомно
                  final selectedGame = games[rnd.nextInt(games.length)];

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => selectedGame,
                    ),
                  );
                },
                child: BlocBuilder<SessionBloc, SessionState>(
                  builder: (context, sessionState) {
                    final bool showPrivate = sessionState.showPrivate;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: showPrivate
                              ? const Color.fromARGB(255, 82, 82, 82)
                              : Colors.transparent,
                          width: 1.0,
                        ),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Image.asset(
                        'assets/refma-logo.png',
                        height: 22,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Iconsax.add),
              tooltip: 'Add new category',
              onPressed: () {
                CategoriesHelpers.showAddCategoryDialog(context);
              },
            ),
            IconButton(
              icon: const Icon(Iconsax.import_1),
              tooltip: 'Download photos/videos',
              onPressed: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const UploadScreen(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      return child;
                    },
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Iconsax.gallery),
              tooltip: 'All photos gallery',
              onPressed: () {
                Navigator.pushNamed(context, '/all_photos');
              },
            ),
            IconButton(
              icon: const Icon(Iconsax.grid_3),
              tooltip: 'My collages',
              onPressed: () {
                Navigator.pushNamed(context, '/my_collages');
              },
            ),
            IconButton(
              icon: const Icon(Iconsax.tag_2),
              onPressed: () {
                Navigator.pushNamed(context, '/all_tags');
              },
              tooltip: 'All Tags',
            ),
            IconButton(
              icon: const Icon(Iconsax.setting_2),
              tooltip: 'Settings',
              onPressed: () => _openSettings(context),
            ),
          ],
        ),
        body: BlocBuilder<CategoryBloc, CategoryState>(
          builder: (context, categoryState) {
            return BlocBuilder<PhotoBloc, PhotoState>(
              builder: (context, photoState) {
                if (categoryState is CategoryLoading ||
                    photoState is PhotoLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (categoryState is CategoryLoaded &&
                    photoState is PhotoLoaded) {
                  final categories = categoryState.categories;
                  final photos = photoState.photos;

                  if ((categories.isEmpty ||
                          (categories.length == 1 &&
                              categories.first.name == "General")) &&
                      photos.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Welcome to Refma!\n\nTo get started, upload your first image using the "Upload" button below. You can also create categories and folders to organize your images efficiently.\n\nUse the "+" button in the app bar to create new category, and within each category, you can add folders to manage your collection.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16.0),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/upload');
                              },
                              child: const Text('Upload'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return CategoryWidget(category: category);
                    },
                  );
                }

                return const Center(child: Text('Failed to load content.'));
              },
            );
          },
      ),
    );
  }
}
