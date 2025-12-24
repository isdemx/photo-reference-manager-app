import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
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
    BuildContext context,
    String tagName,
    Photo? photo, {
    String? tagCategoryId,
  }) {
    final tagBloc = context.read<TagBloc>();
    final existingTags = (tagBloc.state as TagLoaded).tags;

    // Пытаемся найти существующий тег по имени (case-insensitive)
    final existingTag = existingTags.firstWhere(
      (tag) => tag.name.toLowerCase() == tagName.toLowerCase(),
      orElse: () => Tag(id: '', name: '', colorValue: Colors.blue.value),
    );

    if (existingTag.id.isNotEmpty) {
      // Если тег уже существует — просто вешаем его на фото (категорию не трогаем)
      if (photo != null && !photo.tagIds.contains(existingTag.id)) {
        photo.tagIds.add(existingTag.id);
        context.read<PhotoBloc>().add(UpdatePhoto(photo));
      }
    } else {
      // Создаём новый тег С УЧЁТОМ выбранной категории
      final newTag = Tag(
        id: const Uuid().v4(),
        name: tagName,
        colorValue: Colors.blue.value,
        tagCategoryId: tagCategoryId, // ← вот это и не хватало
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
    String? selectedCategoryId;

    // Достаём категории из TagCategoryBloc
    final tagCategoryState = context.read<TagCategoryBloc>().state;
    final categories = tagCategoryState is TagCategoryLoaded
        ? tagCategoryState.categories
        : <TagCategory>[];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add tag'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Tag name',
                ),
              ),
              const SizedBox(height: 16),
              if (categories.isNotEmpty)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedCategoryId,
                  items: categories
                      .map(
                        (c) => DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(c.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    selectedCategoryId = value;
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                final tagName = controller.text.trim();
                if (tagName.isEmpty) return;

                final newTag = Tag(
                  id: const Uuid().v4(),
                  name: tagName,
                  colorValue: Colors.grey.value,
                  tagCategoryId: selectedCategoryId, // выбранная категория
                );

                context.read<TagBloc>().add(AddTag(newTag));

                Navigator.of(context).pop();
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

  /// Общий full-screen диалог для работы с тегами.
  /// Используется и для одного изображения, и для мультивыбора.
  static Future<bool> _showFullScreenTagDialog({
    required BuildContext context,
    required List<Photo> photos,
    required String title,
    required String subtitle,
    required bool allowNewTagCreation,
    required bool multiAssign,
  }) async {
    bool anyChanged = false;

    // Обеспечим наличие данных
    final tagBloc = context.read<TagBloc>();
    if (tagBloc.state is! TagLoaded) {
      tagBloc.add(LoadTags());
    }

    final catBloc = context.read<TagCategoryBloc>();
    if (catBloc.state is! TagCategoryLoaded) {
      catBloc.add(const LoadTagCategories());
    }

    final singlePhoto = photos.length == 1 ? photos.first : null;
    final TextEditingController controller = TextEditingController();
    String? selectedCategoryId; // пока не используем в _addTagToBloc

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (dialogCtx) {
        return BlocBuilder<TagCategoryBloc, TagCategoryState>(
          builder: (catCtx, catState) {
            return BlocBuilder<TagBloc, TagState>(
              builder: (tagCtx, tagState) {
                final bool loading = tagState is! TagLoaded ||
                    !(catState is TagCategoryLoaded ||
                        catState is TagCategoryInitial);

                if (loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final tags = (tagState as TagLoaded).tags;

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

                // Группируем теги по categoryId
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
                ].where((s) => s.tags.isNotEmpty).toList();

                return Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: EdgeInsets.zero,
                  child: SafeArea(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isMacOS =
                            defaultTargetPlatform == TargetPlatform.macOS;
                        final size = MediaQuery.of(context).size;
                        final maxWidth = isMacOS
                            ? (size.width * 0.6).clamp(420.0, 900.0)
                            : size.width;
                        final maxHeight = isMacOS
                            ? (size.height * 0.9).clamp(420.0, size.height)
                            : size.height;

                        return Align(
                          alignment: Alignment.center,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: maxWidth,
                              maxHeight: maxHeight,
                            ),
                            child: Container(
                              width: maxWidth,
                              height: maxHeight,
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Верхняя панель: заголовок + крестик
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Close',
                                        icon: const Icon(Icons.close,
                                            color: Colors.white),
                                        onPressed: () =>
                                            Navigator.of(dialogCtx).pop(false),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  if (allowNewTagCreation)
                                    _NewTagInlineEditor(
                                      controller: controller,
                                      categories: categories,
                                      onCategoryChanged: (val) {
                                        selectedCategoryId = val;
                                      },
                                      onSubmitAdd: () {
                                        final String tagName =
                                            controller.text.trim();
                                        if (tagName.isNotEmpty &&
                                            singlePhoto != null) {
                                          _addTagToBloc(
                                            dialogCtx,
                                            tagName,
                                            singlePhoto,
                                            tagCategoryId:
                                                selectedCategoryId, // ← передаём выбранную категорию
                                          );
                                          anyChanged = true;
                                          controller.clear();
                                        }
                                      },
                                    ),

                                  // Список секций с тегами
                                  Expanded(
                                    child: sections.isEmpty
                                        ? const Center(
                                            child: Text(
                                              'No tags yet',
                                              style: TextStyle(
                                                color: Colors.white54,
                                              ),
                                            ),
                                          )
                                        : Scrollbar(
                                            thumbVisibility: true,
                                            child: ListView.builder(
                                              itemCount: sections.length,
                                              itemBuilder: (_, index) {
                                                final s = sections[index];
                                                return Padding(
                                                  padding: const EdgeInsets.only(
                                                      bottom: 16),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        s.title,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 15,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Wrap(
                                                        spacing: 8,
                                                        runSpacing: 8,
                                                        children: s.tags.map((tag) {
                                                          final allHave = photos.every(
                                                            (p) => p.tagIds
                                                                .contains(tag.id),
                                                          );
                                                          final someHave = photos.any(
                                                            (p) => p.tagIds
                                                                .contains(tag.id),
                                                          );

                                                          // selected для single/multi
                                                          final isSelected = multiAssign
                                                              ? allHave
                                                              : photos.first.tagIds
                                                                  .contains(tag.id);

                                                          IconData? icon;
                                                          if (multiAssign) {
                                                            if (allHave) {
                                                              icon = Icons.check;
                                                            } else if (someHave) {
                                                              icon = Icons.remove;
                                                            }
                                                          }

                                                          return ChoiceChip(
                                                            avatar: icon != null
                                                                ? Icon(
                                                                    icon,
                                                                    size: 16,
                                                                    color: Colors.white,
                                                                  )
                                                                : null,
                                                            label: Text(
                                                              tag.name,
                                                              overflow:
                                                                  TextOverflow.ellipsis,
                                                            ),
                                                            selected: isSelected,
                                                            selectedColor:
                                                                Color(tag.colorValue)
                                                                    .withOpacity(0.7),
                                                            backgroundColor:
                                                                Color(tag.colorValue),
                                                            labelStyle: const TextStyle(
                                                              color: Colors.white,
                                                            ),
                                                            onSelected: (selected) {
                                                              final photoBloc =
                                                                  dialogCtx.read<
                                                                      PhotoBloc>();

                                                              if (!multiAssign) {
                                                                // Один кадр: просто тумблер
                                                                final p = photos.first;
                                                                if (selected) {
                                                                  if (!p.tagIds
                                                                      .contains(
                                                                          tag.id)) {
                                                                    p.tagIds
                                                                        .add(tag.id);
                                                                    photoBloc.add(
                                                                        UpdatePhoto(p));
                                                                  }
                                                                } else {
                                                                  if (p.tagIds.contains(
                                                                      tag.id)) {
                                                                    p.tagIds
                                                                        .remove(tag.id);
                                                                    photoBloc.add(
                                                                        UpdatePhoto(p));
                                                                  }
                                                                }
                                                                anyChanged = true;
                                                              } else {
                                                                // Мультивыбор: логика all/some
                                                                for (final p
                                                                    in photos) {
                                                                  if (allHave ||
                                                                      someHave) {
                                                                    p.tagIds
                                                                        .remove(tag.id);
                                                                  } else {
                                                                    if (!p.tagIds
                                                                        .contains(
                                                                            tag.id)) {
                                                                      p.tagIds
                                                                          .add(tag.id);
                                                                    }
                                                                  }
                                                                  photoBloc.add(
                                                                      UpdatePhoto(p));
                                                                }
                                                                anyChanged = true;
                                                              }

                                                              (tagCtx as Element)
                                                                  .markNeedsBuild();
                                                            },
                                                          );
                                                        }).toList(),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                  ),

                                  // Нижняя панель с кнопками
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dialogCtx).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      const SizedBox(width: 8),
                                      if (allowNewTagCreation)
                                        ElevatedButton(
                                          onPressed: () {
                                            // Просто закрываем диалог.
                                            // Само добавление тега делается через onSubmitAdd
                                            // внутри _NewTagInlineEditor, когда юзер жмёт
                                            // на кнопку [+] рядом с инпутом.
                                            Navigator.of(dialogCtx).pop(anyChanged);
                                          },
                                          child: const Text('Done'),
                                        )
                                      else
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.of(dialogCtx).pop(anyChanged),
                                          child: const Text('OK'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    ).then((v) => v ?? false);
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

  /// Диалог добавления тегов к ОДНОМУ изображению (full-screen).
  static Future<bool> showAddTagToImageDialog(
    BuildContext context,
    Photo photo,
  ) {
    return _showFullScreenTagDialog(
      context: context,
      photos: [photo],
      title: 'Add Tag',
      subtitle: '1 image selected',
      allowNewTagCreation: true,
      multiAssign: false,
    );
  }

  /// Диалог массового назначения тегов нескольким фотографиям (full-screen).
  static Future<bool> showAddTagToImagesDialog(
    BuildContext context,
    List<Photo> photos,
  ) {
    return _showFullScreenTagDialog(
      context: context,
      photos: photos,
      title: 'Add tags to selected images',
      subtitle: '${photos.length} images selected',
      allowNewTagCreation: true,
      multiAssign: true,
    );
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

class _NewTagInlineEditor extends StatefulWidget {
  final TextEditingController controller;
  final List<TagCategory> categories;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onSubmitAdd;

  const _NewTagInlineEditor({
    Key? key,
    required this.controller,
    required this.categories,
    required this.onCategoryChanged,
    required this.onSubmitAdd,
  }) : super(key: key);

  @override
  State<_NewTagInlineEditor> createState() => _NewTagInlineEditorState();
}

class _NewTagInlineEditorState extends State<_NewTagInlineEditor>
    with SingleTickerProviderStateMixin {
  bool _showCategory = false;
  String? _selectedCategoryId;

  void _toggleCategoryVisibility(bool value) {
    if (widget.categories.isEmpty) return;
    setState(() {
      _showCategory = value;
    });
  }

  void _handleAddPressed() {
    final name = widget.controller.text.trim();
    if (name.isEmpty) return;

    // передаём выбранную категорию наружу
    widget.onCategoryChanged(_selectedCategoryId);
    widget.onSubmitAdd();

    // после добавления чистим поле и сворачиваем категорию
    setState(() {
      widget.controller.clear();
      _showCategory = false;
      _selectedCategoryId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasCategories = widget.categories.isNotEmpty;

    // при отсутствии категорий вторая строка всегда видна (иначе некуда нажать Add)
    final rowVisible = !hasCategories ? true : _showCategory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Первая строка — только инпут имени
        Focus(
          onFocusChange: (hasFocus) {
            if (hasFocus && hasCategories) {
              _toggleCategoryVisibility(true);
            }
          },
          child: TextField(
            controller: widget.controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Tag name',
              hintStyle: const TextStyle(color: Colors.white54),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
              suffixIcon: hasCategories
                  ? IconButton(
                      tooltip:
                          _showCategory ? 'Hide category' : 'Show category',
                      icon: Icon(
                        _showCategory
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.white70,
                      ),
                      onPressed: () =>
                          _toggleCategoryVisibility(!_showCategory),
                    )
                  : null,
            ),
            onSubmitted: (_) => _handleAddPressed(),
          ),
        ),

        // Вторая строка — категория + кнопка Add (всё вместе анимированно выезжает)
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: !rowVisible
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: Row(
                    children: [
                      if (hasCategories)
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategoryId,
                            isExpanded: true,
                            dropdownColor: Colors.grey[900],
                            decoration: const InputDecoration(
                              labelText: 'Category (optional)',
                              labelStyle: TextStyle(color: Colors.white70),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white24),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                            ),
                            items: widget.categories
                                .map(
                                  (c) => DropdownMenuItem<String>(
                                    value: c.id,
                                    child: Text(
                                      c.name,
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedCategoryId = val;
                              });
                              widget.onCategoryChanged(val);
                            },
                          ),
                        ),

                      if (hasCategories) const SizedBox(width: 8),

                      // Кнопка добавления тега (на второй строке, стилизована под dark UI)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          backgroundColor: Colors.white10,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(
                              color: Colors.white24,
                            ),
                          ),
                        ),
                        onPressed: _handleAddPressed,
                        icon: const Icon(
                          Iconsax.add,
                          size: 18,
                        ),
                        label: const Text(
                          'Add',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }
}
