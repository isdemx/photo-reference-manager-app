import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:iconsax/iconsax.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:photographers_reference_app/src/domain/entities/tag_category.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_category_bloc.dart';

class TagsHelpers {
  static void _addTagToBloc(
      BuildContext context, String tagName, Photo? photo) {
    final tagBloc = context.read<TagBloc>();
    final existingTags = (tagBloc.state as TagLoaded).tags;

    final existingTag = existingTags.firstWhere(
      (tag) => tag.name.toLowerCase() == tagName.toLowerCase(),
      orElse: () => Tag(id: '', name: '', colorValue: Colors.blue.value),
    );

    if (existingTag.id.isNotEmpty) {
      // Если тег уже существует, добавляем его к фотографии, если указана
      if (photo != null && !photo.tagIds.contains(existingTag.id)) {
        photo.tagIds.add(existingTag.id);
        context.read<PhotoBloc>().add(UpdatePhoto(photo));
      }
    } else {
      // Если тег не существует, создаем новый и добавляем в TagBloc и PhotoBloc
      final newTag = Tag(
        id: const Uuid().v4(),
        name: tagName,
        colorValue: Colors.blue.value,
      );
      tagBloc.add(AddTag(newTag));
      if (photo != null) {
        photo.tagIds.add(newTag.id);
        context.read<PhotoBloc>().add(UpdatePhoto(photo));
      }
    }
  }

  static void showAddTagDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add tag'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Tag name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final String tagName = controller.text.trim();
                if (tagName.isNotEmpty) {
                  _addTagToBloc(
                      context, tagName, null); // Передаем null для фото
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

  static Future<bool> showAddTagToImageDialog(
      BuildContext context, Photo photo) async {
    final TextEditingController controller = TextEditingController();
    final tagBloc = context.read<TagBloc>();

    if (tagBloc.state is! TagLoaded) {
      tagBloc.add(LoadTags());
    }

    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return BlocBuilder<TagBloc, TagState>(
          builder: (context, tagState) {
            if (tagState is TagLoaded) {
              final existingTags = tagState.tags;

              return AlertDialog(
                title: const Text('Add Tag'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: controller,
                        decoration: const InputDecoration(hintText: 'Tag Name'),
                      ),
                      const SizedBox(height: 16.0),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: existingTags.map((tag) {
                          final isSelected = photo.tagIds.contains(tag.id);

                          return ChoiceChip(
                            label: Text(tag.name),
                            selected: isSelected,
                            selectedColor:
                                Color(tag.colorValue).withOpacity(0.5),
                            backgroundColor: Color(tag.colorValue),
                            onSelected: (selected) {
                              if (selected) {
                                if (!photo.tagIds.contains(tag.id)) {
                                  photo.tagIds.add(tag.id);
                                  context
                                      .read<PhotoBloc>()
                                      .add(UpdatePhoto(photo));
                                }
                              } else {
                                if (photo.tagIds.contains(tag.id)) {
                                  photo.tagIds.remove(tag.id);
                                  context
                                      .read<PhotoBloc>()
                                      .add(UpdatePhoto(photo));
                                }
                              }
                              (context as Element).markNeedsBuild();
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context)
                        .pop(false), // Возвращаем false при отмене
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      final String tagName = controller.text.trim();
                      if (tagName.isNotEmpty) {
                        _addTagToBloc(context, tagName, photo); // Передаем фото
                      }
                      Navigator.of(context)
                          .pop(true); // Возвращаем true при добавлении тега
                    },
                    child: const Text('Add'),
                  ),
                ],
              );
            } else if (tagState is TagLoading) {
              return const Center(child: CircularProgressIndicator());
            } else {
              return const Center(child: Text('Failed to load tags.'));
            }
          },
        );
      },
    ).then((value) => value ?? false); // Если результат null, возвращаем false
  }

  static void showDeleteConfirmationDialog(BuildContext context, Tag tag) {
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

  static void showColorPickerDialog(BuildContext context, Tag tag) {
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
                final updatedTag = tag.copyWith(
                  colorValue: pickerColor.value,
                );
                context.read<TagBloc>().add(UpdateTag(updatedTag));
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

  static void showEditTagDialog(BuildContext context, Tag tag) {
    final TextEditingController controller =
        TextEditingController(text: tag.name);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit tag'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Tag name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final String tagName = controller.text.trim();
                if (tagName.isNotEmpty) {
                  final updatedTag = tag.copyWith(
                    name: tagName,
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

  static Map<String, int> computeTagPhotoCounts(
      List<Tag> tags, List<Photo> photos) {
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

  /// Диалог массового назначения тега нескольким фотографиям.
  /// Возвращает true, если были изменения.
  /// Показывает тот же диалог, но для массива фото.
  /// Возвращает true, если пользователь нажал "OK"
  /// Диалог массового назначения тега нескольким фотографиям.
  /// Возвращает true, если были изменения.
  static Future<bool> showAddTagToImagesDialog(
    BuildContext context,
    List<Photo> photos,
  ) async {
    bool anyChanged = false;

    // Обеспечим наличие данных
    final tagBloc = context.read<TagBloc>();
    if (tagBloc.state is! TagLoaded) tagBloc.add(LoadTags());

    final catBloc = context.read<TagCategoryBloc>();
    if (catBloc.state is! TagCategoryLoaded) {
      catBloc.add(const LoadTagCategories());
    }

    return await showDialog<bool>(
      context: context,
      builder: (_) {
        return BlocBuilder<TagCategoryBloc, TagCategoryState>(
          builder: (context, catState) {
            return BlocBuilder<TagBloc, TagState>(
              builder: (context, tagState) {
                final bool loading = tagState is! TagLoaded ||
                    !(catState is TagCategoryLoaded ||
                        catState is TagCategoryInitial);

                if (loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final tags = (tagState as TagLoaded).tags;
                print('tags length: ${tags.length}');
                final tagDebugList = tags
                    .map(
                        (t) => {'tagCategory': t.tagCategoryId, 'name': t.name})
                    .toList();
                print('tags (name+id): $tagDebugList');

                final categories = catState is TagCategoryLoaded
                    ? List<TagCategory>.from(catState.categories)
                    : <TagCategory>[];

                // Сортируем категории: sortOrder ↑, затем name ↑
                categories.sort((a, b) {
                  final byOrder = a.sortOrder.compareTo(b.sortOrder);
                  return byOrder != 0
                      ? byOrder
                      : a.name.toLowerCase().compareTo(b.name.toLowerCase());
                });

                // Группируем теги по категориям
                final Map<String?, List<Tag>> grouped = {};
                for (final t in tags) {
                  grouped.putIfAbsent(t.tagCategoryId, () => []).add(t);
                }

                // Внутри каждой группы — сортировка по имени
                for (final entry in grouped.entries) {
                  entry.value.sort(
                    (a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                  );
                }

                // Секции: все категории по порядку + «Без категории» в конце
                final sections = <_TagSection>[
                  for (final c in categories)
                    _TagSection(
                      title: c.name,
                      categoryId: c.id,
                      tags: grouped[c.id] ?? const [],
                    ),
                  _TagSection(
                    title: 'No category',
                    categoryId: null,
                    tags: grouped[null] ?? const [],
                  ),
                ]
                    .where((s) => s.tags.isNotEmpty)
                    .toList(); // пустые секции скрываем

                return AlertDialog(
                  title: const Text('Add tags to selected images'),
                  content: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: sections.map((s) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Заголовок секции
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    s.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                // Список чипов тегов этой секции
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: s.tags.map((tag) {
                                    final allHave = photos.every(
                                        (p) => p.tagIds.contains(tag.id));
                                    final someHave = photos
                                        .any((p) => p.tagIds.contains(tag.id));

                                    IconData? icon;
                                    if (allHave) {
                                      icon = Icons.check;
                                    } else if (someHave) {
                                      icon = Icons.remove;
                                    } else {
                                      icon = null;
                                    }

                                    return ChoiceChip(
                                      avatar: icon != null
                                          ? Icon(icon,
                                              size: 16, color: Colors.white)
                                          : null,
                                      label: Text(tag.name),
                                      selected: allHave,
                                      selectedColor: Color(tag.colorValue)
                                          .withOpacity(0.5),
                                      backgroundColor: Color(tag.colorValue),
                                      labelStyle:
                                          const TextStyle(color: Colors.white),
                                      onSelected: (_) {
                                        for (final photo in photos) {
                                          if (allHave || someHave) {
                                            photo.tagIds.remove(tag.id);
                                          } else {
                                            if (!photo.tagIds
                                                .contains(tag.id)) {
                                              photo.tagIds.add(tag.id);
                                            }
                                          }
                                          context
                                              .read<PhotoBloc>()
                                              .add(UpdatePhoto(photo));
                                        }
                                        anyChanged = true;
                                        (context as Element).markNeedsBuild();
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, anyChanged),
                      child: const Text('OK'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    ).then((v) => v ?? false);
  }
}

/// Внутренняя модель секции для диалога
class _TagSection {
  final String title;
  final String? categoryId;
  final List<Tag> tags;
  _TagSection(
      {required this.title, required this.categoryId, required this.tags});
}
