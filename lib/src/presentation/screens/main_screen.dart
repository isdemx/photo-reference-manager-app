// lib/src/presentation/screens/main_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:photographers_reference_app/src/presentation/bloc/category_bloc.dart';
import 'package:photographers_reference_app/src/presentation/helpers/categories_helpers.dart';
import 'package:photographers_reference_app/src/presentation/screens/upload_screen.dart';
import 'package:photographers_reference_app/src/presentation/widgets/category_widget.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({Key? key}) : super(key: key);

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
                  Image.asset(
                    'assets/refma-logo.png', // Ваш логотип
                    height: 30, // Уменьшенный размер логотипа
                  ),
                  const SizedBox(width: 5), // Отступ между логотипом и версией
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 5.0,
                    ),
                    child: Align(
                      alignment:
                          Alignment.bottomLeft, // Выравнивание по нижнему краю
                      child: Text(
                        'v${packageInfo.version}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10.0, // Маленький шрифт для версии
                        ),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              return Image.asset(
                'assets/refma-logo.png', // Логотип при загрузке версии
                height: 40, // Задайте нужный размер логотипа
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
          // Additional icons can be added here if needed
        ],
      ),
      body: BlocBuilder<CategoryBloc, CategoryState>(
        builder: (context, categoryState) {
          if (categoryState is CategoryLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (categoryState is CategoryLoaded) {
            var categories = categoryState.categories;
            // categories = [];

            if (categories.isEmpty) {
              // Display instructions when there are no categories
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
            // Handle other states if necessary
            return const Center(child: Text('No categories available.'));
          }
        },
      ),
    );
  }
}
