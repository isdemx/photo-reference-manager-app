import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/category.dart';
import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/presentation/bloc/folder_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/category_bloc.dart';
import 'package:uuid/uuid.dart';

class AddFolderDialog extends StatefulWidget {
  final Category? category;

  const AddFolderDialog({
    Key? key,
    this.category,
  }) : super(key: key);

  @override
  _AddFolderDialogState createState() => _AddFolderDialogState();
}

class _AddFolderDialogState extends State<AddFolderDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isPrivate = false;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      _focusNode.requestFocus();
    });
  }

  void _addFolder() {
    final String name = _controller.text.trim();
    final String? categoryId = widget.category?.id ?? _selectedCategoryId;
    if (name.isNotEmpty && categoryId != null) {
      final Folder folder = Folder(
        id: const Uuid().v4(),
        name: name,
        categoryId: categoryId,
        photoIds: [],
        dateCreated: DateTime.now(),
        isPrivate: _isPrivate,
        sortOrder: 0,
      );
      context.read<FolderBloc>().add(AddFolder(folder));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
      },
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction(onInvoke: (e) => _addFolder()),
        },
        child: Focus(
          autofocus: true,
          child: AlertDialog(
            title: const Text('Add Folder'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: const InputDecoration(hintText: 'Folder Name'),
                  onSubmitted: (_) => _addFolder(),
                ),
                const SizedBox(height: 16.0),
                CheckboxListTile(
                  title: const Text('Is Private (3 taps on logo to show)'),
                  value: _isPrivate,
                  onChanged: (bool? value) {
                    setState(() {
                      _isPrivate = value ?? false;
                    });
                  },
                ),
                if (widget.category == null) ...[
                  const SizedBox(height: 16.0),
                  BlocBuilder<CategoryBloc, CategoryState>(
                    builder: (context, state) {
                      if (state is CategoryLoaded) {
                        return DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Select Category',
                          ),
                          items: state.categories.map((category) {
                            return DropdownMenuItem<String>(
                              value: category.id,
                              child: Text(category.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCategoryId = value;
                            });
                          },
                        );
                      }
                      return const CircularProgressIndicator();
                    },
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: _addFolder,
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

void showAddFolderDialog(BuildContext context, {Category? category}) {
  showDialog(
    context: context,
    builder: (context) => AddFolderDialog(category: category),
  );
}
