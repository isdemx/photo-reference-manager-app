import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/domain/entities/tag_category.dart';

import 'package:photographers_reference_app/src/presentation/bloc/folder_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_category_bloc.dart';

import 'package:photographers_reference_app/src/presentation/widgets/video_view.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';
import 'package:photographers_reference_app/src/presentation/helpers/tags_helpers.dart';

class PhotoPickerWidget extends StatefulWidget {
  final void Function(Photo) onPhotoSelected;
  final void Function(List<Photo>)? onMultiSelectDone;

  const PhotoPickerWidget({
    super.key,
    required this.onPhotoSelected,
    this.onMultiSelectDone,
  });

  @override
  State<PhotoPickerWidget> createState() => _PhotoPickerWidgetState();
}

class _PhotoPickerWidgetState extends State<PhotoPickerWidget>
    with TickerProviderStateMixin {
  String? _folderId;

  /// Выбранные теги (мультивыбор)
  final Set<String> _selectedTagIds = {};

  /// Логика тегов: false = ИЛИ (union), true = И (intersection)
  bool _tagLogicAnd = false;

  bool _multiSelect = false;
  final List<Photo> _selectedPhotos = [];

  /// Состояние панели фильтров (по умолчанию открыта)
  bool _filtersOpen = true;

  /// Размер грида: кол-во столбцов (изменяется ползунком)
  double _gridColumnsSlider = 4; // [2; 8]
  int get _crossAxisCount => _gridColumnsSlider.round().clamp(2, 8);

  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TagBloc, TagState>(
      builder: (_, tagState) {
        if (tagState is! TagLoaded) return const _Loader();

        return BlocBuilder<FolderBloc, FolderState>(
          builder: (_, folderState) {
            if (folderState is! FolderLoaded) return const _Loader();

            return BlocBuilder<PhotoBloc, PhotoState>(
              builder: (_, photoState) {
                if (photoState is! PhotoLoaded) return const _Loader();

                final folders = {for (var f in folderState.folders) f.id: f}
                    .values
                    .toList();
                final tags =
                    {for (var t in tagState.tags) t.id: t}.values.toList();

                final tagCatState = context.watch<TagCategoryBloc>().state;
                final List<TagCategory> categories =
                    tagCatState is TagCategoryLoaded
                        ? tagCatState.categories
                        : <TagCategory>[];

                // фильтруем фотографии
                final photos = _applyFilters(photoState.photos);

                return Scaffold(
                  appBar: AppBar(
                    title: Text(_multiSelect
                        ? 'Selected: ${_selectedPhotos.length}'
                        : 'Choose photo (${photos.length})'),
                    actions: _multiSelect
                        ? [
                            IconButton(
                              icon: const Icon(Icons.done),
                              tooltip: 'Add selected',
                              onPressed: () {
                                widget.onMultiSelectDone
                                    ?.call(List.of(_selectedPhotos));
                                _exitMultiSelect();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              tooltip: 'Cancel multi-select',
                              onPressed: _exitMultiSelect,
                            )
                          ]
                        : null,
                  ),
                  body: Column(
                    children: [
                      // ------------------ панель фильтра (сворачиваемая) ----------------
                      _FiltersHeader(
                        open: _filtersOpen,
                        onToggle: () =>
                            setState(() => _filtersOpen = !_filtersOpen),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: _filtersOpen
                            ? Container(
                                width: double.infinity,
                                color: Colors.black54,
                                padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                                child: _FilterPanel(
                                  folders: folders,
                                  allTags: tags,
                                  folderId: _folderId,
                                  categories: categories,
                                  onFolderChanged: (v) =>
                                      setState(() => _folderId = v),
                                  selectedTagIds: _selectedTagIds,
                                  tagLogicAnd: _tagLogicAnd,
                                  onToggleLogic: () => setState(
                                      () => _tagLogicAnd = !_tagLogicAnd),
                                  onClearAllTags: () {
                                    setState(() => _selectedTagIds.clear());
                                  },
                                  onToggleTag: (tagId) {
                                    setState(() {
                                      if (_selectedTagIds.contains(tagId)) {
                                        _selectedTagIds.remove(tagId);
                                      } else {
                                        _selectedTagIds.add(tagId);
                                      }
                                    });
                                  },
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),

                      // ------------------ сетка фото + оверлейный слайдер --------------
                      Expanded(
                        child: Stack(
                          children: [
                            // GRID
                            GridView.builder(
                              padding: const EdgeInsets.all(8),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: _crossAxisCount,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                              ),
                              itemCount: photos.length,
                              itemBuilder: (_, i) {
                                final p = photos[i];
                                final path =
                                    PhotoPathHelper().getFullPath(p.fileName);
                                final sel = _selectedPhotos.contains(p);

                                Widget media;
                                if (p.mediaType == 'video') {
                                  if (p.videoPreview != null) {
                                    final previewPath = PhotoPathHelper()
                                        .getFullPath(p.videoPreview!);
                                    media = Image.file(
                                      File(previewPath),
                                      fit: BoxFit.cover,
                                    );
                                  } else {
                                    media = const Center(
                                      child: Icon(
                                        Icons.videocam,
                                        color: Colors.white70,
                                      ),
                                    );
                                  }
                                } else {
                                  media =
                                      Image.file(File(path), fit: BoxFit.cover);
                                }

                                return GestureDetector(
                                  onTap: () => _onTap(p),
                                  onLongPress: () => _onLongPress(p),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: media,
                                      ),

                                      // подпись файла на видео
                                      if (p.mediaType == 'video')
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          bottom:
                                              28, // оставили место под Tag кнопку
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 2, horizontal: 4),
                                            color: Colors.black45,
                                            child: Text(
                                              p.fileName,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),

                                      // кнопка "Tag" снизу слева
                                      Positioned(
                                        left: 6,
                                        bottom: 6,
                                        child: _TagQuickButton(
                                          onTap: () async {
                                            final changed = await TagsHelpers
                                                .showAddTagToImagesDialog(
                                              context,
                                              [p],
                                            );
                                            if (changed && mounted) {
                                              // Обновим список фото из БЛОКа
                                              context
                                                  .read<PhotoBloc>()
                                                  .add(LoadPhotos());
                                              setState(() {});
                                            }
                                          },
                                        ),
                                      ),

                                      // выделение при мультиселекте
                                      if (sel)
                                        Container(
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.blue.withOpacity(0.45),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                      if (sel)
                                        const Positioned(
                                          right: 6,
                                          bottom: 6,
                                          child: Icon(Icons.check_circle,
                                              color: Colors.white),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),

                            // SLIDER OVERLAY (внизу, поверх фоток)
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 12,
                              child: SafeArea(
                                top: false,
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 540,
                                    ),
                                    child: _GridSizeSlider(
                                      value: _gridColumnsSlider,
                                      onChanged: (v) => setState(
                                          () => _gridColumnsSlider = v),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  List<Photo> _applyFilters(List<Photo> source) {
    var photos = source;

    // 1) Папка
    if (_folderId != null) {
      photos = photos
          .where((p) => p.folderIds.contains(_folderId))
          .toList(growable: false);
    }

    // 2) Теги
    if (_selectedTagIds.isNotEmpty) {
      if (_tagLogicAnd) {
        // И (intersection): фото должно содержать все выбранные теги
        photos = photos.where((p) {
          final ids = p.tagIds.toSet();
          return _selectedTagIds.every(ids.contains);
        }).toList(growable: false);
      } else {
        // ИЛИ (union): фото содержит хотя бы один выбранный тег
        photos = photos.where((p) {
          final ids = p.tagIds.toSet();
          return _selectedTagIds.any(ids.contains);
        }).toList(growable: false);
      }
    }

    return photos;
  }

  void _onTap(Photo p) {
    if (_multiSelect) {
      _toggle(p);
    } else {
      widget.onPhotoSelected(p);
    }
  }

  void _onLongPress(Photo p) {
    if (!_multiSelect) {
      setState(() => _multiSelect = true);
    }
    _toggle(p);
  }

  void _toggle(Photo p) {
    setState(() {
      _selectedPhotos.contains(p)
          ? _selectedPhotos.remove(p)
          : _selectedPhotos.add(p);
      if (_selectedPhotos.isEmpty) _exitMultiSelect();
    });
  }

  void _exitMultiSelect() {
    setState(() {
      _multiSelect = false;
      _selectedPhotos.clear();
    });
  }
}

// ============================================================================
// Виджеты/хелперы
// ============================================================================

class _Loader extends StatelessWidget {
  const _Loader();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// Заголовок секции фильтров с тогглом свернуть/развернуть
class _FiltersHeader extends StatelessWidget {
  final bool open;
  final VoidCallback onToggle;

  const _FiltersHeader({
    required this.open,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.filter_list, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                'Filters',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  open ? 'Hide' : 'Show',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
              const Spacer(),
              Icon(
                open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Кнопка "Tag" на карточке фото
class _TagQuickButton extends StatelessWidget {
  final VoidCallback onTap;
  const _TagQuickButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Iconsax.tag, size: 10, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

/// Слайдер изменения размера грида (кол-во столбцов)
class _GridSizeSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _GridSizeSlider({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.72),
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.grid_on, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Text(
              'Columns: ${value.round()}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 220,
              child: Slider(
                value: value,
                min: 2,
                max: 8,
                divisions: 6,
                label: value.round().toString(),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Группа тегов: сначала по категориям, затем «Без категории»
class _FilterPanel extends StatelessWidget {
  final List<Folder> folders;
  final List<Tag> allTags;
  final List<TagCategory> categories;

  final String? folderId;
  final ValueChanged<String?> onFolderChanged;

  final Set<String> selectedTagIds;
  final bool tagLogicAnd;
  final VoidCallback onToggleLogic;
  final VoidCallback onClearAllTags;
  final ValueChanged<String> onToggleTag;

  const _FilterPanel({
    Key? key,
    required this.folders,
    required this.allTags,
    required this.categories,
    required this.folderId,
    required this.onFolderChanged,
    required this.selectedTagIds,
    required this.tagLogicAnd,
    required this.onToggleLogic,
    required this.onClearAllTags,
    required this.onToggleTag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final grouped = _groupTagsByCategoryId(allTags);

    String _catName(String? id) {
      if (id == null) return 'No category';
      final cat = categories.firstWhere(
        (c) => c.id == id,
        orElse: () => TagCategory(
          id: '',
          name: 'Unknown',
          sortOrder: 0,
          dateCreated: DateTime.now(),
        ),
      );
      return cat.name;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Folder row
        Row(
          children: [
            const Text('Folder:', style: TextStyle(color: Colors.white)),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<String?>(
                value: folderId,
                dropdownColor: Colors.grey[900],
                style: const TextStyle(color: Colors.white),
                iconEnabledColor: Colors.white,
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All Folders'),
                  ),
                  ...folders.map(
                    (f) => DropdownMenuItem(
                      value: f.id,
                      child: Text(f.name),
                    ),
                  ),
                ],
                onChanged: onFolderChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // --- Tag logic & clear
        Row(
          children: [
            const Text('Tags:', style: TextStyle(color: Colors.white)),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('OR'),
              selected: !tagLogicAnd,
              onSelected: (_) => onToggleLogic(),
              selectedColor: Colors.blueGrey.shade700,
              labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelPadding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
            ),
            const SizedBox(width: 6),
            ChoiceChip(
              label: const Text('AND'),
              selected: tagLogicAnd,
              onSelected: (_) => onToggleLogic(),
              selectedColor: Colors.blueGrey.shade700,
              labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelPadding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onClearAllTags,
              icon: const Icon(Icons.clear, size: 16, color: Colors.white70),
              label: const Text(
                'Clear',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // --- Сначала категории
        for (final entry in grouped.byCat.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              _catName(entry.key), // <-- здесь теперь имя категории
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: entry.value.map((t) {
              final id = t.id; // id тут точно String
              final selected = selectedTagIds.contains(id);
              return _TagBadge(
                label: t.name,
                color: t.colorValue,
                selected: selected,
                onTap: () => onToggleTag(id),
              );
            }).toList(),
          ),
        ],

        // --- Потом некатегоризированные
        if (grouped.uncategorized.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              'No category',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: grouped.uncategorized.map((t) {
              final id = t.id;
              final selected = selectedTagIds.contains(id);
              return _TagBadge(
                label: t.name,
                color: t.colorValue,
                selected: selected,
                onTap: () => onToggleTag(id),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

/// Группировка тегов по tagCategoryId
class _GroupedTags {
  final Map<String, List<Tag>> byCat;
  final List<Tag> uncategorized;
  _GroupedTags(this.byCat, this.uncategorized);
}

_GroupedTags _groupTagsByCategoryId(List<Tag> all) {
  final byCat = <String, List<Tag>>{};
  final uncategorized = <Tag>[];

  for (final t in all) {
    final catId = t.tagCategoryId; // предполагается поле в Tag
    if (catId == null || (catId is String && catId.isEmpty)) {
      uncategorized.add(t);
    } else {
      final key = catId.toString();
      (byCat[key] ??= []).add(t);
    }
  }

  // сортируем по имени
  for (final e in byCat.entries) {
    e.value.sort((a, b) => a.name.compareTo(b.name));
  }
  uncategorized.sort((a, b) => a.name.compareTo(b.name));

  // при желании — сортировка порядков категорий по ключу
  final sortedByCat = Map.fromEntries(
    byCat.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );

  return _GroupedTags(sortedByCat, uncategorized);
}

class _TagBadge extends StatelessWidget {
  final String label;
  final int color;
  final bool selected;
  final VoidCallback onTap;

  const _TagBadge({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = Color(color);
    final text = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? bg : bg.withOpacity(0.6),
          borderRadius: BorderRadius.circular(18),
          border: selected ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: Text(label, style: TextStyle(color: text, fontSize: 12)),
      ),
    );
  }
}
