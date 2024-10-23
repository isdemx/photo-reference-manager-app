// lib/src/presentation/screens/main_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:photographers_reference_app/src/presentation/bloc/category_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/session_bloc.dart';
import 'package:photographers_reference_app/src/presentation/helpers/categories_helpers.dart';
import 'package:photographers_reference_app/src/presentation/screens/upload_screen.dart';
import 'package:photographers_reference_app/src/presentation/widgets/category_widget.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int logoTapCount = 0;
  Timer? _tapTimer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done &&
                snapshot.hasData) {
              final packageInfo = snapshot.data!;

              return Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.end, // Центрируем по нижнему краю
                children: [
                  GestureDetector(
                    onTap: () {
                      logoTapCount++;
                      _tapTimer?.cancel();
                      _tapTimer = Timer(const Duration(seconds: 1), () {
                        logoTapCount = 0;
                      });

                      if (logoTapCount >= 3) {
                        context
                            .read<SessionBloc>()
                            .add(ToggleShowPrivateEvent());
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
                                  color: Colors.white), // Белый цвет текста
                              textAlign:
                                  TextAlign.center, // Центрирование текста
                            ),
                            duration: const Duration(seconds: 1),
                            backgroundColor: Colors.purple, // Фиолетовый фон
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10), // Скругленные углы
                            ),
                            elevation:
                                10, // Добавим тень для эффекта всплывания
                            
                          ),
                        );
                      }
                    },
                    child: BlocBuilder<SessionBloc, SessionState>(
                      builder: (context, sessionState) {
                        final bool showPrivate = sessionState.showPrivate;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 2, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: showPrivate
                                  ? Colors.purple
                                  : Colors.transparent,
                              width: 1.0, // Толщина рамки
                            ),
                            borderRadius: BorderRadius.circular(
                                8.0), // Скругленные углы для рамки
                          ),
                          child: Image.asset(
                            'assets/refma-logo.png', // Ваш логотип
                            height: 30, // Уменьшенный размер логотипа
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 5),
                  Padding(
                    padding: const EdgeInsets.only(left: 5.0),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        'v${packageInfo.version}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10.0,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              return Image.asset(
                'assets/refma-logo.png', // Логотип при загрузке версии
                height: 40,
              );
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Open add category dialog
              CategoriesHelpers.showAddCategoryDialog(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.upload),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UploadScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: () {
              Navigator.pushNamed(context, '/all_photos');
            },
          ),
          IconButton(
            icon: const Icon(Icons.label),
            onPressed: () {
              Navigator.pushNamed(context, '/all_tags');
            },
            tooltip: 'All Tags',
          ),
        ],
      ),
      body: BlocBuilder<CategoryBloc, CategoryState>(
        builder: (context, categoryState) {
          if (categoryState is CategoryLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (categoryState is CategoryLoaded) {
            var categories = categoryState.categories;

            if (categories.isEmpty) {
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
                      const SizedBox(
                          height: 20), // Отступ между текстом и кнопкой
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
          } else {
            return const Center(child: Text('No categories available.'));
          }
        },
      ),
    );
  }
}
