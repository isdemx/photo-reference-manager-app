import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
            icon: const Icon(Icons.add),
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

                  // Добавляем ячейку с кнопкой после последней папки
                  final folderCount = folders.length + 1;
                  final shouldAddPlaceholder = folders.length % 2 != 0;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: folderCount,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      if (index < folders.length) {
                        // Отображаем существующую папку
                        final folder = folders[index];
                        return FolderWidget(folder: folder);
                      } else if (shouldAddPlaceholder) {
                        // Последняя ячейка — кнопка с лаконичным "+"
                        return Center(
                          child: IconButton(
                            icon: const Icon(
                              Icons.add,
                              size: 32.0, // Увеличиваем размер иконки
                            ),
                            onPressed: () {
                              CategoriesHelpers.showAddFolderDialog(
                                  context, category);
                            },
                          ),
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
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
