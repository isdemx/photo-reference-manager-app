import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/category.dart';
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
        print('sessionState ${sessionState}');

        return ExpansionTile(
          shape: const Border(),
          title: GestureDetector(
            onLongPress: () {
              vibrate();
              CategoriesHelpers.showEditCategoryDialog(context, category);
            },
            child: Text(category.name),
          ),
          initiallyExpanded: true,
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
                        (showPrivate || (folder.isPrivate == null || folder.isPrivate == false));
                  }).toList();

                  if (folders.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('No folders in this category.'),
                    );
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: folders.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      final folder = folders[index];
                      return FolderWidget(folder: folder);
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
