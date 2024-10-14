// lib/src/presentation/screens/all_tags_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';
import 'package:photographers_reference_app/src/presentation/helpers/custom_snack_bar.dart';
import 'package:photographers_reference_app/src/presentation/screens/tag_screen.dart';
import 'package:uuid/uuid.dart';

class AllTagsScreen extends StatefulWidget {
  const AllTagsScreen({Key? key}) : super(key: key);

  @override
  _AllTagsScreenState createState() => _AllTagsScreenState();
}

class _AllTagsScreenState extends State<AllTagsScreen> {
  Map<String, int> tagPhotoCounts = {};

  void _showAddTagDialog(BuildContext context) {
    final TextEditingController _controller = TextEditingController();
    final tagBloc = context.read<TagBloc>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add tag'),
          content: TextField(
            controller: _controller,
            decoration: const InputDecoration(hintText: 'Tag name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final String tagName = _controller.text.trim();
                if (tagName.isNotEmpty) {
                  final newTag = Tag(
                    id: const Uuid().v4(),
                    name: tagName,
                    colorValue: Colors.blue.value,
                  );
                  tagBloc.add(AddTag(newTag));
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, Tag tag) {
    final tagBloc = context.read<TagBloc>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete tag'),
          content: Text('Are you sure wnat to delete "${tag.name}" tag?'),
          actions: [
            TextButton(
              onPressed: () {
                tagBloc.add(DeleteTag(tag.id));
                Navigator.of(context).pop();
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showColorPickerDialog(BuildContext context, Tag tag) {
    Color pickerColor = Color(tag.colorValue);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Color for "${tag.name}" tag'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (Color color) {
                pickerColor = color;
              },
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final updatedTag = Tag(
                  id: tag.id,
                  name: tag.name,
                  colorValue: pickerColor.value,
                );
                context.read<TagBloc>().add(UpdateTag(updatedTag));
                Navigator.of(context).pop();
              },
              child: const Text('Ok'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showEditTagDialog(BuildContext context, Tag tag) {
    final TextEditingController _controller =
        TextEditingController(text: tag.name);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit tag'),
          content: TextField(
            controller: _controller,
            decoration: const InputDecoration(hintText: 'Tag name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final String tagName = _controller.text.trim();
                if (tagName.isNotEmpty) {
                  final updatedTag = Tag(
                    id: tag.id,
                    name: tagName,
                    colorValue: tag.colorValue,
                  );
                  context.read<TagBloc>().add(UpdateTag(updatedTag));
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Ok'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Map<String, int> _computeTagPhotoCounts(List<Tag> tags, List<Photo> photos) {
    final Map<String, int> counts = {};
    for (var tag in tags) {
      counts[tag.id] = 0;
    }
    for (var photo in photos) {
      for (var tagId in photo.tagIds) {
        if (counts.containsKey(tagId)) {
          counts[tagId] = counts[tagId]! + 1;
        }
      }
    }
    return counts;
  }

  @override
  void initState() {
    super.initState();
    // Инициализируем загрузку тегов и фотографий
    context.read<TagBloc>().add(LoadTags());
    context.read<PhotoBloc>().add(LoadPhotos());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _showAddTagDialog(context);
            },
          ),
        ],
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<TagBloc, TagState>(
            listener: (context, state) {
              if (state is TagError) {
                CustomSnackBar.showError(context, state.message);
              }
            },
          ),
          BlocListener<PhotoBloc, PhotoState>(
            listener: (context, state) {
              if (state is PhotoError) {
                CustomSnackBar.showError(context, state.message);
              }
            },
          ),
        ],
        child: BlocBuilder<TagBloc, TagState>(
          builder: (context, tagState) {
            if (tagState is TagLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (tagState is TagLoaded) {
              final tags = tagState.tags;
              final photoState = context.watch<PhotoBloc>().state;
              if (photoState is PhotoLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (photoState is PhotoLoaded) {
                final photos = photoState.photos;
                tagPhotoCounts = _computeTagPhotoCounts(tags, photos);
                final sortedTags = List<Tag>.from(tags);
                sortedTags.sort((a, b) {
                  final countA = tagPhotoCounts[a.id] ?? 0;
                  final countB = tagPhotoCounts[b.id] ?? 0;
                  return countB.compareTo(countA);
                });

                return ListView.builder(
                  itemCount: sortedTags.length,
                  itemBuilder: (context, index) {
                    final tag = sortedTags[index];
                    final photoCount = tagPhotoCounts[tag.id] ?? 0;

                    return ListTile(
                      key: ValueKey(tag.id), // Добавляем уникальный ключ
                      leading: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TagScreen(tag: tag),
                            ),
                          );
                        },
                        onLongPress: () {
                          _showColorPickerDialog(context, tag);
                        },
                        child: CircleAvatar(
                          backgroundColor: Color(tag.colorValue),
                          child: Text(
                            tag.name.isNotEmpty
                                ? tag.name[0].toUpperCase()
                                : '',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      title: GestureDetector(
                        onTap: () {
                          tag.name != 'Not Ref'
                              ? _showEditTagDialog(context, tag)
                              : null;
                        },
                        child: Text(tag.name),
                      ),
                      subtitle: Text('$photoCount photo'),
                      trailing: tag.name != 'Not Ref'
                          ? IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                _showDeleteConfirmationDialog(context, tag);
                              },
                            )
                          : null,
                    );
                  },
                );
              } else if (photoState is PhotoError) {
                return Center(child: Text('Error: ${photoState.message}'));
              } else {
                return const Center(child: Text('Caanot load photos'));
              }
            } else if (tagState is TagError) {
              return Center(child: Text('Error: ${tagState.message}'));
            } else {
              return const Center(child: Text('Caanot load tags'));
            }
          },
        ),
      ),
    );
  }
}
