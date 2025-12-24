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

import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';
import 'package:photographers_reference_app/src/presentation/helpers/tags_helpers.dart';
import 'package:uuid/uuid.dart';
import 'package:photographers_reference_app/src/presentation/widgets/video_surface_widget.dart';
import 'package:photographers_reference_app/src/presentation/widgets/video_controls_widget.dart';

class _VideoThumbUi {
  double startFrac;
  double endFrac;
  double posFrac;
  double volume;
  double speed;
  Duration duration;
  int seekRequestId;

  _VideoThumbUi({
    this.startFrac = 0.0,
    this.endFrac = 1.0,
    this.posFrac = 0.0,
    this.volume = 0.0,
    this.speed = 1.0,
    this.duration = Duration.zero,
    this.seekRequestId = 0,
  });
}

class PhotoPickResult {
  final Photo photo;
  final String contextId;
  final List<String> contextFileNames;
  final int indexInContext;

  const PhotoPickResult({
    required this.photo,
    required this.contextId,
    required this.contextFileNames,
    required this.indexInContext,
  });
}

class PhotoPickerWidget extends StatefulWidget {
  final void Function(PhotoPickResult) onPhotoSelected;
  final void Function(List<PhotoPickResult>)? onMultiSelectDone;

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
  final Map<String, _VideoThumbUi> _videoThumbStates = <String, _VideoThumbUi>{};
  final Map<String, bool> _videoHover = <String, bool>{};
  final Map<String, bool> _controlsHover = <String, bool>{};

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
                    title: GestureDetector(
                      onTap: () =>
                          setState(() => _filtersOpen = !_filtersOpen),
                      child: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Icon(Icons.filter_list,
                              color: Colors.white70, size: 18),
                          Text(
                            'Filters',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.white),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _filtersOpen ? 'Hide' : 'Show',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: ToggleButtons(
                              isSelected: [_tagLogicAnd == false, _tagLogicAnd],
                              onPressed: (index) {
                                setState(() => _tagLogicAnd = index == 1);
                              },
                              borderRadius: BorderRadius.circular(12),
                              borderColor: Colors.transparent,
                              selectedBorderColor: Colors.transparent,
                              fillColor: Colors.blueGrey.shade700,
                              color: Colors.white70,
                              selectedColor: Colors.white,
                              constraints: const BoxConstraints(
                                minHeight: 24,
                                minWidth: 36,
                              ),
                              children: const [
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('OR', style: TextStyle(fontSize: 11)),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('AND', style: TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _selectedTagIds.clear()),
                            icon: const Icon(Icons.clear,
                                size: 14, color: Colors.white70),
                            label: const Text(
                              'Clear',
                              style:
                                  TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: _multiSelect
                        ? [
                            IconButton(
                              icon: const Icon(Icons.done),
                              tooltip: 'Add selected',
                              onPressed: () {
                                final contextFileNames = photos
                                    .map((e) => e.fileName)
                                    .toList(growable: false);
                                final indexByFileName = <String, int>{
                                  for (int i = 0;
                                      i < contextFileNames.length;
                                      i++)
                                    contextFileNames[i]: i,
                                };
                                final contextId = const Uuid().v4();
                                final results = _selectedPhotos
                                    .map(
                                      (p) => PhotoPickResult(
                                        photo: p,
                                        contextId: contextId,
                                        contextFileNames: contextFileNames,
                                        indexInContext:
                                            indexByFileName[p.fileName] ?? 0,
                                      ),
                                    )
                                    .toList(growable: false);
                                widget.onMultiSelectDone?.call(results);
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
                                  media = _buildVideoThumb(p);
                                } else {
                                  media =
                                      Image.file(File(path), fit: BoxFit.cover);
                                }

                                return GestureDetector(
                                  onTap: () => _onTap(p, photos),
                                  onLongPress: () => _onLongPress(p),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: media,
                                      ),

                                      // // подпись файла на видео
                                      // if (p.mediaType == 'video')
                                      //   Positioned(
                                      //     left: 0,
                                      //     right: 0,
                                      //     bottom: 0,
                                      //     child: Container(
                                      //       padding: const EdgeInsets.symmetric(
                                      //           vertical: 2, horizontal: 4)
                                      //         .copyWith(left: 34),
                                      //       color: Colors.black45,
                                      //       child: Text(
                                      //         p.fileName,
                                      //         overflow: TextOverflow.ellipsis,
                                      //         style: const TextStyle(
                                      //             color: Colors.white,
                                      //             fontSize: 11),
                                      //         textAlign: TextAlign.left,
                                      //       ),
                                      //     ),
                                      //   ),

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
                                      maxWidth: 500,
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

  _VideoThumbUi _ensureVideoUi(Photo photo) {
    return _videoThumbStates.putIfAbsent(photo.fileName, () => _VideoThumbUi());
  }

  Duration _fracToTime(Duration total, double f) {
    if (total == Duration.zero) return Duration.zero;
    final ms = (total.inMilliseconds * f.clamp(0.0, 1.0)).round();
    return Duration(milliseconds: ms);
  }

  double _timeToFrac(Duration total, Duration t) {
    if (total == Duration.zero) return 0.0;
    return (t.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }

  Widget _buildVideoThumb(Photo photo) {
    final fullPath = PhotoPathHelper().getFullPath(photo.fileName);
    final ui = _ensureVideoUi(photo);
    final visible = (_videoHover[photo.fileName] == true) ||
        (_controlsHover[photo.fileName] == true);

    Widget preview;
    if (photo.videoPreview != null) {
      final previewPath = PhotoPathHelper().getFullPath(photo.videoPreview!);
      preview = Image.file(File(previewPath), fit: BoxFit.cover);
    } else {
      preview = const Center(
        child: Icon(Icons.videocam, color: Colors.white70),
      );
    }

    if (!File(fullPath).existsSync()) {
      return preview;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _videoHover[photo.fileName] = true),
      onExit: (_) {
        setState(() {
          _videoHover[photo.fileName] = false;
          _controlsHover[photo.fileName] = false;
        });
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: preview),
          if (_videoHover[photo.fileName] == true)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: VideoSurface(
                  key: ValueKey(
                      'picker-vs-${photo.fileName}-${ui.duration.inMilliseconds}'),
                  filePath: fullPath,
                  startTime: _fracToTime(ui.duration, ui.startFrac),
                  endTime: ui.duration == Duration.zero
                      ? null
                      : _fracToTime(ui.duration, ui.endFrac),
                  volume: ui.volume,
                  speed: ui.speed,
                  autoplay: true,
                  onDuration: (d) {
                    setState(() => ui.duration = d);
                  },
                  onPosition: (p) {
                    setState(() => ui.posFrac = _timeToFrac(ui.duration, p));
                  },
                  externalPositionFrac: ui.posFrac,
                  externalSeekId: ui.seekRequestId,
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MouseRegion(
              onEnter: (_) =>
                  setState(() => _controlsHover[photo.fileName] = true),
              onExit: (_) =>
                  setState(() => _controlsHover[photo.fileName] = false),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: visible ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !visible,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6)
                        .copyWith(left: 34),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black45, Colors.transparent],
                      ),
                    ),
                    child: VideoControls(
                      startFrac: ui.startFrac,
                      endFrac: ui.endFrac,
                      positionFrac: ui.posFrac,
                      volume: ui.volume,
                      speed: ui.speed,
                      onSeekFrac: (f) => setState(() {
                        ui.posFrac = f.clamp(0.0, 1.0);
                        ui.seekRequestId++;
                      }),
                      onChangeRange: (rv) => setState(() {
                        ui.startFrac = rv.start;
                        ui.endFrac = rv.end;
                      }),
                      onChangeVolume: (v) => setState(() => ui.volume = v),
                      onChangeSpeed: (s) => setState(() => ui.speed = s),
                      totalDuration: ui.duration,
                      showLoopRange: false,
                      showVolume: false,
                      showSpeed: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onTap(Photo p, List<Photo> context) {
    if (_multiSelect) {
      _toggle(p);
    } else {
      final contextFileNames =
          context.map((e) => e.fileName).toList(growable: false);
      final indexInContext =
          context.indexWhere((e) => e.fileName == p.fileName);
      widget.onPhotoSelected(
        PhotoPickResult(
          photo: p,
          contextId: const Uuid().v4(),
          contextFileNames: contextFileNames,
          indexInContext: indexInContext,
        ),
      );
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

  @override
  void dispose() {
    super.dispose();
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
    final sliderTheme = SliderTheme.of(context).copyWith(
      trackHeight: 4,
      activeTrackColor: Colors.redAccent,
      inactiveTrackColor: Colors.white,
      thumbColor: Colors.transparent,
      overlayColor: Colors.transparent,
      thumbShape: SliderComponentShape.noThumb,
      overlayShape: SliderComponentShape.noOverlay,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Cols ${value.round()}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 160,
            child: SliderTheme(
              data: sliderTheme,
              child: Slider(
                value: value,
                min: 2,
                max: 8,
                divisions: 6,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
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
