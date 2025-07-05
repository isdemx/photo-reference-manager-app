import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/presentation/widgets/video_view.dart';
import '../../domain/entities/folder.dart';
import '../../domain/entities/photo.dart';
import '../../domain/entities/tag.dart';
import '../bloc/folder_bloc.dart';
import '../bloc/photo_bloc.dart';
import '../bloc/tag_bloc.dart';
import '../../utils/photo_path_helper.dart';

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

class _PhotoPickerWidgetState extends State<PhotoPickerWidget> {
  String? _folderId;
  String? _tagId;
  bool _multiSelect = false;
  final List<Photo> _selected = [];

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

                // фильтруем фото
                var photos = photoState.photos;
                if (_folderId != null)
                  photos = photos
                      .where((p) => p.folderIds.contains(_folderId))
                      .toList();
                if (_tagId != null)
                  photos =
                      photos.where((p) => p.tagIds.contains(_tagId)).toList();

                return Scaffold(
                  appBar: AppBar(
                    title: Text(_multiSelect
                        ? 'Selected: ${_selected.length}'
                        : 'Choose photo (${photos.length})'),
                    actions: _multiSelect
                        ? [
                            IconButton(
                              icon: const Icon(Icons.done),
                              onPressed: () {
                                widget.onMultiSelectDone
                                    ?.call(List.of(_selected));
                                _exitMultiSelect();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: _exitMultiSelect,
                            )
                          ]
                        : null,
                  ),
                  body: Column(
                    children: [
                      // ------------------ панель фильтра ---------------------------------
                      Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Text('Folder:',
                                    style: TextStyle(color: Colors.white)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButton<String?>(
                                    value: _folderId,
                                    dropdownColor: Colors.grey[900],
                                    style: const TextStyle(color: Colors.white),
                                    iconEnabledColor: Colors.white,
                                    isExpanded: true,
                                    items: [
                                      const DropdownMenuItem(
                                          value: null,
                                          child: Text('All Folders')),
                                      ...folders.map((f) => DropdownMenuItem(
                                          value: f.id, child: Text(f.name))),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _folderId = v),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6, // чтобы был отступ между строками
                              children: [
                                _TagBadge(
                                  label: 'All',
                                  color: Colors.grey.shade700.value,
                                  selected: _tagId == null,
                                  onTap: () => setState(() => _tagId = null),
                                ),
                                for (final t in tags)
                                  _TagBadge(
                                    label: t.name,
                                    color: t.colorValue,
                                    selected: _tagId == t.id,
                                    onTap: () => setState(() => _tagId = t.id),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // ------------------ сетка фото --------------------------------------
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                          itemCount: photos.length,
                          itemBuilder: (_, i) {
                            final p = photos[i];
                            final path =
                                PhotoPathHelper().getFullPath(p.fileName);
                            final sel = _selected.contains(p);

                            // ── контент ячейки ──────────────────────────────────────────────────────────
                            Widget thumb;
                            if (p.mediaType == 'video') {
                              // берём готовый VideoView; чтобы ролик сразу играл, передаём одинаковые
                              // index/currentIndex  (= i), а контроллер не нужен.
                              thumb = VideoView(
                                i,
                                p,
                                i,
                                null,
                                initialVolume: 0,
                                hideVolume: true,
                                hidePlayPause: true,
                              );
                            } else {
                              thumb = Image.file(File(path), fit: BoxFit.cover);
                            }

                            // ── подпись для видео ──────────────────────────────────────────────────────
                            final List<Widget> stackChildren = [thumb];

                            if (p.mediaType == 'video') {
                              stackChildren.add(
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 2, horizontal: 4),
                                    color: Colors.black45,
                                    child: Text(
                                      p.fileName, // или p.title, если есть
                                      overflow: TextOverflow
                                          .ellipsis, // одна строка, с троеточием
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 11),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              );
                            }

                            // ── синий оверлей выбора ───────────────────────────────────────────────────
                            if (sel) {
                              stackChildren.add(
                                Container(
                                  color: Colors.blue.withOpacity(0.45),
                                  alignment: Alignment.bottomRight,
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(Icons.check_circle,
                                      color: Colors.white),
                                ),
                              );
                            }

                            return GestureDetector(
                              onTap: () => _onTap(p),
                              onLongPress: () => _onLongPress(p),
                              child: Stack(
                                  fit: StackFit.expand,
                                  children: stackChildren),
                            );
                          },
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
      _selected.contains(p) ? _selected.remove(p) : _selected.add(p);
      if (_selected.isEmpty) _exitMultiSelect();
    });
  }

  void _exitMultiSelect() {
    setState(() {
      _multiSelect = false;
      _selected.clear();
    });
  }
}

// ============================================================================
// вспомогательные виджеты
// ============================================================================
class _Loader extends StatelessWidget {
  const _Loader();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
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
