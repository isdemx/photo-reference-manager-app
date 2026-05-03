import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:iconsax/iconsax.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';
import 'package:photographers_reference_app/src/presentation/theme/app_theme.dart';
import 'package:photographers_reference_app/src/utils/platform_utils.dart';
import 'package:uuid/uuid.dart';
import 'package:photographers_reference_app/src/domain/entities/tag_category.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_category_bloc.dart';

class TagsHelpers {
  static const List<Shadow> _tagIconShadows = [
    Shadow(
      color: Color(0x66000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
    Shadow(
      color: Color(0x44000000),
      blurRadius: 6,
      offset: Offset(0, 0),
    ),
  ];

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

                final tags = tagState.tags;

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

                void closeDialog() {
                  Navigator.of(dialogCtx).pop(anyChanged);
                }

                return Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: isDesktopPlatform
                      ? const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 28,
                        )
                      : EdgeInsets.zero,
                  child: SafeArea(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = isDesktopPlatform;
                        final size = MediaQuery.of(context).size;
                        final colors = context.appThemeColors;
                        final maxWidth = isDesktop
                            ? (size.width * 0.46).clamp(460.0, 720.0)
                            : size.width;
                        final maxHeight = isDesktop
                            ? (size.height * 0.76).clamp(420.0, 680.0)
                            : size.height;

                        return CallbackShortcuts(
                          bindings: <ShortcutActivator, VoidCallback>{
                            const SingleActivator(LogicalKeyboardKey.escape):
                                closeDialog,
                            const SingleActivator(LogicalKeyboardKey.enter):
                                closeDialog,
                          },
                          child: Focus(
                            autofocus: true,
                            child: Align(
                              alignment: Alignment.center,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: maxWidth,
                                  maxHeight: maxHeight,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colors.surface,
                                    borderRadius: BorderRadius.circular(
                                      isDesktop ? 10 : 0,
                                    ),
                                    border: Border.all(color: colors.border),
                                    boxShadow: isDesktop
                                        ? const [
                                            BoxShadow(
                                              color: Color(0x66000000),
                                              blurRadius: 24,
                                              offset: Offset(0, 14),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      isDesktop ? 18 : 16,
                                      isDesktop ? 14 : 16,
                                      isDesktop ? 18 : 16,
                                      isDesktop ? 14 : 16,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    title,
                                                    style: TextStyle(
                                                      fontSize:
                                                          isDesktop ? 16 : 18,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: colors.text,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    subtitle,
                                                    style: TextStyle(
                                                      fontSize:
                                                          isDesktop ? 12 : 13,
                                                      color: colors.subtle,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Close',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              icon: Icon(
                                                Icons.close,
                                                color: colors.subtle,
                                                size: isDesktop ? 18 : 22,
                                              ),
                                              onPressed: closeDialog,
                                            ),
                                          ],
                                        ),
                                        Divider(
                                          height: isDesktop ? 18 : 20,
                                          color: colors.border,
                                        ),
                                        if (allowNewTagCreation)
                                          _NewTagInlineEditor(
                                            controller: controller,
                                            categories: categories,
                                            onCategoryChanged: (val) {
                                              selectedCategoryId = val;
                                            },
                                            onSubmitAdd: () {
                                              final tagName =
                                                  controller.text.trim();
                                              if (tagName.isNotEmpty &&
                                                  singlePhoto != null) {
                                                _addTagToBloc(
                                                  dialogCtx,
                                                  tagName,
                                                  singlePhoto,
                                                  tagCategoryId:
                                                      selectedCategoryId,
                                                );
                                                anyChanged = true;
                                                controller.clear();
                                              }
                                            },
                                            onDone:
                                                isDesktop ? closeDialog : null,
                                          ),
                                        Expanded(
                                          child: sections.isEmpty
                                              ? Center(
                                                  child: Text(
                                                    'No tags yet',
                                                    style: TextStyle(
                                                      color: colors.subtle,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                )
                                              : Scrollbar(
                                                  thumbVisibility: true,
                                                  child: ListView.builder(
                                                    padding: EdgeInsets.only(
                                                      top: isDesktop ? 2 : 4,
                                                      right: isDesktop ? 10 : 6,
                                                    ),
                                                    itemCount: sections.length,
                                                    itemBuilder: (_, index) {
                                                      final section =
                                                          sections[index];
                                                      return Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                          bottom: isDesktop
                                                              ? 14
                                                              : 16,
                                                        ),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              section.title,
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontSize:
                                                                    isDesktop
                                                                        ? 12
                                                                        : 15,
                                                                color: colors
                                                                    .subtle,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 7,
                                                            ),
                                                            Wrap(
                                                              spacing: isDesktop
                                                                  ? 6
                                                                  : 4,
                                                              runSpacing:
                                                                  isDesktop
                                                                      ? 6
                                                                      : 1,
                                                              children: section
                                                                  .tags
                                                                  .map((tag) {
                                                                final allHave =
                                                                    photos
                                                                        .every(
                                                                  (p) => p
                                                                      .tagIds
                                                                      .contains(
                                                                    tag.id,
                                                                  ),
                                                                );
                                                                final someHave =
                                                                    photos.any(
                                                                  (p) => p
                                                                      .tagIds
                                                                      .contains(
                                                                    tag.id,
                                                                  ),
                                                                );
                                                                final isSelected = multiAssign
                                                                    ? allHave
                                                                    : photos
                                                                        .first
                                                                        .tagIds
                                                                        .contains(
                                                                            tag.id);

                                                                IconData? icon;
                                                                if (multiAssign) {
                                                                  if (allHave) {
                                                                    icon = Icons
                                                                        .check;
                                                                  } else if (someHave) {
                                                                    icon = Icons
                                                                        .remove;
                                                                  }
                                                                }

                                                                return ChoiceChip(
                                                                  visualDensity:
                                                                      VisualDensity
                                                                          .compact,
                                                                  materialTapTargetSize:
                                                                      MaterialTapTargetSize
                                                                          .shrinkWrap,
                                                                  side:
                                                                      BorderSide(
                                                                    color: isSelected
                                                                        ? Colors
                                                                            .white38
                                                                        : Colors
                                                                            .black26,
                                                                  ),
                                                                  shape:
                                                                      const StadiumBorder(),
                                                                  avatar: icon !=
                                                                          null
                                                                      ? Icon(
                                                                          icon,
                                                                          size: isDesktop
                                                                              ? 13
                                                                              : 14,
                                                                          color:
                                                                              Colors.white,
                                                                          shadows:
                                                                              _tagIconShadows,
                                                                        )
                                                                      : null,
                                                                  label: Text(
                                                                    tag.name,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                  selected:
                                                                      isSelected,
                                                                  selectedColor:
                                                                      Color(tag
                                                                              .colorValue)
                                                                          .withValues(
                                                                    alpha: 0.74,
                                                                  ),
                                                                  backgroundColor:
                                                                      Color(tag
                                                                          .colorValue),
                                                                  labelStyle:
                                                                      TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        isDesktop
                                                                            ? 11
                                                                            : 12,
                                                                    shadows:
                                                                        _tagIconShadows,
                                                                  ),
                                                                  padding:
                                                                      EdgeInsets
                                                                          .symmetric(
                                                                    horizontal:
                                                                        isDesktop
                                                                            ? 7
                                                                            : 8,
                                                                    vertical:
                                                                        isDesktop
                                                                            ? 0
                                                                            : 2,
                                                                  ),
                                                                  onSelected:
                                                                      (selected) {
                                                                    final photoBloc =
                                                                        dialogCtx
                                                                            .read<PhotoBloc>();

                                                                    if (!multiAssign) {
                                                                      final p =
                                                                          photos
                                                                              .first;
                                                                      if (selected) {
                                                                        if (!p
                                                                            .tagIds
                                                                            .contains(tag.id)) {
                                                                          p.tagIds
                                                                              .add(tag.id);
                                                                          photoBloc
                                                                              .add(UpdatePhoto(p));
                                                                        }
                                                                      } else {
                                                                        if (p
                                                                            .tagIds
                                                                            .contains(tag.id)) {
                                                                          p.tagIds
                                                                              .remove(tag.id);
                                                                          photoBloc
                                                                              .add(UpdatePhoto(p));
                                                                        }
                                                                      }
                                                                      anyChanged =
                                                                          true;
                                                                    } else {
                                                                      for (final p
                                                                          in photos) {
                                                                        if (allHave ||
                                                                            someHave) {
                                                                          p.tagIds
                                                                              .remove(tag.id);
                                                                        } else if (!p
                                                                            .tagIds
                                                                            .contains(tag.id)) {
                                                                          p.tagIds
                                                                              .add(tag.id);
                                                                        }
                                                                        photoBloc
                                                                            .add(UpdatePhoto(p));
                                                                      }
                                                                      anyChanged =
                                                                          true;
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
                                        Divider(
                                          height: isDesktop ? 18 : 20,
                                          color: colors.border,
                                        ),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: FilledButton(
                                            onPressed: closeDialog,
                                            child: Text(
                                              allowNewTagCreation
                                                  ? 'Done'
                                                  : 'OK',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
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
  final VoidCallback? onDone;

  const _NewTagInlineEditor({
    required this.controller,
    required this.categories,
    required this.onCategoryChanged,
    required this.onSubmitAdd,
    this.onDone,
  });

  @override
  State<_NewTagInlineEditor> createState() => _NewTagInlineEditorState();
}

class _NewTagInlineEditorState extends State<_NewTagInlineEditor>
    with SingleTickerProviderStateMixin {
  bool _showCategory = false;
  String? _selectedCategoryId;
  final FocusNode _tagInputFocusNode = FocusNode();

  @override
  void dispose() {
    _tagInputFocusNode.dispose();
    super.dispose();
  }

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

  void _cancelTagInput() {
    widget.onCategoryChanged(null);
    setState(() {
      widget.controller.clear();
      _showCategory = false;
      _selectedCategoryId = null;
    });
  }

  void _handleEscapePressed() {
    final hasDraft = widget.controller.text.trim().isNotEmpty ||
        _showCategory ||
        _selectedCategoryId != null;
    if (hasDraft) {
      _cancelTagInput();
      return;
    }
    widget.onDone?.call();
  }

  void _handleEnterPressed() {
    if (widget.controller.text.trim().isEmpty) {
      widget.onDone?.call();
      return;
    }
    _handleAddPressed();
  }

  @override
  Widget build(BuildContext context) {
    final hasCategories = widget.categories.isNotEmpty;
    final isDesktop = isDesktopPlatform;
    final colors = context.appThemeColors;

    // при отсутствии категорий вторая строка всегда видна (иначе некуда нажать Add)
    final rowVisible = !hasCategories ? true : _showCategory;

    final editor = Column(
      crossAxisAlignment:
          isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 360 : double.infinity,
          ),
          child: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.escape):
                  _handleEscapePressed,
              const SingleActivator(LogicalKeyboardKey.enter):
                  _handleEnterPressed,
            },
            child: Focus(
              onFocusChange: (hasFocus) {
                if (hasFocus && hasCategories) {
                  _toggleCategoryVisibility(true);
                }
              },
              child: TextField(
                focusNode: _tagInputFocusNode,
                controller: widget.controller,
                style: TextStyle(
                  color: colors.text,
                  fontSize: isDesktop ? 12 : 13,
                ),
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: 'Tag name',
                  hintStyle: TextStyle(color: colors.subtle),
                  filled: true,
                  fillColor: colors.surfaceAlt,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 10 : 12,
                    vertical: isDesktop ? 9 : 11,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.accent),
                  ),
                ),
                onSubmitted: (_) => _handleEnterPressed(),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration:
              isDesktop ? Duration.zero : const Duration(milliseconds: 200),
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
                            initialValue: _selectedCategoryId,
                            isExpanded: true,
                            dropdownColor: colors.surface,
                            style: TextStyle(
                              color: colors.text,
                              fontSize: isDesktop ? 12 : 13,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Category (optional)',
                              labelStyle: TextStyle(color: colors.subtle),
                              filled: true,
                              fillColor: colors.surfaceAlt,
                              isDense: true,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: colors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: colors.accent),
                              ),
                            ),
                            items: widget.categories
                                .map(
                                  (c) => DropdownMenuItem<String>(
                                    value: c.id,
                                    child: Text(
                                      c.name,
                                      style: TextStyle(color: colors.text),
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
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          backgroundColor: colors.surfaceAlt,
                          foregroundColor: colors.text,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: colors.border),
                          ),
                        ),
                        onPressed: _handleAddPressed,
                        icon: const Icon(
                          Iconsax.add,
                          size: 16,
                        ),
                        label: const Text(
                          'Add',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 8),
      ],
    );

    if (!isDesktop) return editor;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: editor,
      ),
    );
  }
}
