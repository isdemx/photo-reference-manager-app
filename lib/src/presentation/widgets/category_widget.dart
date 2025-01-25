import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:photographers_reference_app/src/domain/entities/category.dart';
import 'package:photographers_reference_app/src/presentation/bloc/category_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/folder_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/session_bloc.dart';
import 'package:photographers_reference_app/src/presentation/helpers/categories_helpers.dart';
import 'package:photographers_reference_app/src/presentation/widgets/folder_widget.dart';
import 'package:photographers_reference_app/src/utils/longpress_vibrating.dart';

class CategoryWidget extends StatelessWidget {
  final Category category;

  const CategoryWidget({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, sessionState) {
        final showPrivate = sessionState.showPrivate;

        // Пропускаем приватные категории, если showPrivate = false
        if (!showPrivate && (category.isPrivate == true)) {
          return const SizedBox.shrink(); // Не показываем категорию
        }

        return ExpansionTile(
          shape: const Border(),
          title: GestureDetector(
            onLongPress: () {
              vibrate();
              CategoriesHelpers.showEditCategoryDialog(context, category);
            },
            child: Text(category.name),
          ),
          initiallyExpanded: category.collapsed !=
              true, // Если collapsed != true, категория раскрыта
          onExpansionChanged: (isExpanded) {
            // Отправляем событие обновления категории при изменении состояния (сворачивание/разворачивание)
            final updatedCategory = category.copyWith(collapsed: !isExpanded);
            context.read<CategoryBloc>().add(UpdateCategory(updatedCategory));
          },
          trailing: IconButton(
            tooltip: 'Add new folder',
            icon: const Icon(Iconsax.add),
            onPressed: () {
              CategoriesHelpers.showAddFolderDialog(context, category);
            },
          ),
          children: [
            BlocBuilder<FolderBloc, FolderState>(
              builder: (context, folderState) {
                if (folderState is FolderLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (folderState is FolderLoaded) {
                  // Фильтрация папок в зависимости от состояния showPrivate
                  final folders = folderState.folders.where((folder) {
                    return folder.categoryId == category.id &&
                        (showPrivate ||
                            (folder.isPrivate == null ||
                                folder.isPrivate == false));
                  }).toList();

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      // Ширина одной папки (адаптивная, между 200 и 300px)
                      final double folderWidth = constraints.maxWidth < 600 ? 130.0 : 200.0;
                      final int crossAxisCount =
                          (constraints.maxWidth / folderWidth).floor();

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: folders.length + 1, // +1 для кнопки "+"
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount, // Динамическое количество колонок
                          childAspectRatio: 1, // Квадратные ячейки
                          mainAxisSpacing: 8.0,
                          crossAxisSpacing: 8.0,
                        ),
                        itemBuilder: (context, index) {
                          if (index < folders.length) {
                            // Отображаем существующую папку
                            final folder = folders[index];
                            return FolderWidget(folder: folder);
                          } else {
                            // Последняя ячейка — кнопка "+"
                            return Center(
                              child: IconButton(
                                icon: const Icon(
                                  Iconsax.add,
                                  size: 32.0,
                                ),
                                tooltip: 'Add new folder',
                                onPressed: () {
                                  CategoriesHelpers.showAddFolderDialog(
                                      context, category);
                                },
                              ),
                            );
                          }
                        },
                      );
                    },
                  );
                } else {
                  return const Center(child: Text('Failed to load folders.'));
                }
              },
            ),
          ],
        );
      },
    );
  }
}
