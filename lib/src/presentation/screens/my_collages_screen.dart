import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photographers_reference_app/src/presentation/bloc/collage_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/session_bloc.dart';
import 'package:photographers_reference_app/src/presentation/widgets/collage_photo.dart';

class MyCollagesScreen extends StatefulWidget {
  const MyCollagesScreen({Key? key}) : super(key: key);

  @override
  State<MyCollagesScreen> createState() => _MyCollagesScreenState();
}

class _MyCollagesScreenState extends State<MyCollagesScreen> {
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  String? _supportDirPath;

  // Ширина превью (вся карточка тянется по высоте за счёт пропорции картинки).
  double _tileWidth = 160;
  static const double _minTileWidth = 120;
  static const double _maxTileWidth = 360;

  @override
  void initState() {
    super.initState();
    _loadSupportDir();
  }

  Future<void> _loadSupportDir() async {
    final dir = await getApplicationSupportDirectory();
    if (!mounted) return;
    setState(() => _supportDirPath = dir.path);
  }

  String? _resolvePreviewPath(String collageId, String? previewPath) {
    if (previewPath != null &&
        previewPath.isNotEmpty &&
        File(previewPath).existsSync()) {
      return previewPath;
    }
    if (_supportDirPath == null) return null;

    final fallback = p.join(
      _supportDirPath!,
      'collages',
      'previews',
      'collage_$collageId.png',
    );
    if (File(fallback).existsSync()) {
      return fallback;
    }

    if (previewPath != null && previewPath.isNotEmpty) {
      final base = p.basename(previewPath);
      final byName = p.join(
        _supportDirPath!,
        'collages',
        'previews',
        base,
      );
      if (File(byName).existsSync()) {
        return byName;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CollageBloc, CollageState>(
      builder: (context, state) {
        if (state is CollageLoading) {
          return Scaffold(
            appBar: AppBar(title: const Text('All Collages')),
            body: const Center(child: CircularProgressIndicator()),
          );
        } else if (state is CollagesLoaded) {
          return BlocBuilder<PhotoBloc, PhotoState>(
            builder: (context, photoState) {
              if (photoState is PhotoLoading) {
                return Scaffold(
                  appBar: AppBar(title: const Text('All Collages')),
                  body: const Center(child: CircularProgressIndicator()),
                );
              } else if (photoState is PhotoLoaded) {
                final allPhotos = photoState.photos;
                final showPrivate =
                    context.watch<SessionBloc>().state.showPrivate;

                // Безопасная сортировка: берём dateUpdated ?? dateCreated ?? veryOld
                final veryOld = DateTime.fromMillisecondsSinceEpoch(0);
                final collages = state.collages
                    .where((c) => showPrivate || c.isPrivate != true)
                    .toList()
                  ..sort((a, b) {
                    final aDate = (a.dateUpdated ?? a.dateCreated) ?? veryOld;
                    final bDate = (b.dateUpdated ?? b.dateCreated) ?? veryOld;
                    return bDate.compareTo(aDate); // новые первыми
                  });

                return Scaffold(
                  appBar: AppBar(title: const Text('All Collages')),
                  body: collages.isEmpty
                      ? const Center(
                          child: Text('No collages yet'),
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  // Wrap сам переносит элементы по ширине
                                  final horizontalPadding = 12.0;
                                  final runSpacing = 12.0;
                                  final spacing = 12.0;

                                  return SingleChildScrollView(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    child: Wrap(
                                      spacing: spacing,
                                      runSpacing: runSpacing,
                                      children: collages.map((c) {
                                        final isUpdated =
                                            c.dateUpdated != null &&
                                                c.dateUpdated != c.dateCreated;
                                        final dateText = isUpdated
                                            ? 'Updated: ${_safeFormat(c.dateUpdated)}'
                                            : 'Created: ${_safeFormat(c.dateCreated)}';

                                        final resolvedPreviewPath =
                                            _resolvePreviewPath(
                                          c.id,
                                          c.previewPath,
                                        );
                                        final hasPreview =
                                            resolvedPreviewPath != null;

                                        Widget imageChild;
                                        if (hasPreview) {
                                          imageChild = Image.file(
                                            File(resolvedPreviewPath!),
                                            width: _tileWidth,
                                            fit: BoxFit
                                                .cover, // картинка целиком (по ширине она сама просчитает высоту)
                                          );
                                          // Важно: у Image с заданной width и без height
                                          // высота берётся по натуральному аспекту, т.е. контента не кропаем.
                                        } else {
                                          imageChild = Container(
                                            width: _tileWidth,
                                            color: Colors.grey.shade900,
                                            height: _tileWidth * 0.7,
                                            child: const Center(
                                              child: Icon(
                                                Icons.grid_on,
                                                color: Colors.white54,
                                                size: 32,
                                              ),
                                            ),
                                          );
                                        }

                                        return GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    PhotoCollageWidget(
                                                  key: ValueKey(c.id),
                                                  photos: [allPhotos.first],
                                                  allPhotos: allPhotos,
                                                  initialCollage: c,
                                                ),
                                              ),
                                            );
                                          },
                                          onLongPress: () => _confirmDelete(
                                              context, c.id, c.title),
                                          child: _MasonryCard(
                                            width: _tileWidth,
                                            image: imageChild,
                                            title: c.title,
                                            dateText: dateText,
                                            onDeleteTap: () => _confirmDelete(
                                                context, c.id, c.title),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  );
                                },
                              ),
                            ),

                            // Нижняя панель — слайдер масштаба
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surface
                                    .withOpacity(0.9),
                                border: Border(
                                  top: BorderSide(
                                      color: Colors.black.withOpacity(0.08)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Iconsax.search_zoom_in, size: 18),
                                  Expanded(
                                    child: Slider(
                                      min: _minTileWidth,
                                      max: _maxTileWidth,
                                      value: _tileWidth,
                                      onChanged: (v) =>
                                          setState(() => _tileWidth = v),
                                    ),
                                  ),
                                  const Icon(Iconsax.search_zoom_out, size: 18),
                                ],
                              ),
                            ),
                          ],
                        ),
                  floatingActionButton: FloatingActionButton.extended(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PhotoCollageWidget(
                            key: const ValueKey('new_photo_collage_widget'),
                            photos: [allPhotos.first],
                            allPhotos: allPhotos,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Iconsax.add),
                    label: const Text('Create New Collage'),
                    backgroundColor: Colors.black,
                  ),
                );
              } else {
                return Scaffold(
                  appBar: AppBar(title: const Text('All Collages')),
                  body: const Center(child: Text('No photos loaded.')),
                );
              }
            },
          );
        } else if (state is CollageError) {
          return Scaffold(
            appBar: AppBar(title: const Text('All Collages')),
            body: Center(child: Text('Error: ${state.message}')),
          );
        } else {
          return Scaffold(
            appBar: AppBar(title: const Text('All Collages')),
            body: const Center(child: Text('No data or unknown state')),
          );
        }
      },
    );
  }

  String _safeFormat(DateTime? dt) {
    if (dt == null) return '-';
    return _dateFormat.format(dt);
  }

  void _confirmDelete(BuildContext context, String collageId, String title) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Do you really want to delete "$title"?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Delete'),
            onPressed: () {
              Navigator.of(context).pop();
              context.read<CollageBloc>().add(DeleteCollage(collageId));
            },
          ),
        ],
      ),
    );
  }
}

/// Карточка масонри: изображение + подпись поверх снизу (градиент)
class _MasonryCard extends StatefulWidget {
  final double width;
  final Widget image;
  final String title;
  final String dateText;
  final VoidCallback onDeleteTap;

  const _MasonryCard({
    Key? key,
    required this.width,
    required this.image,
    required this.title,
    required this.dateText,
    required this.onDeleteTap,
  }) : super(key: key);

  @override
  State<_MasonryCard> createState() => _MasonryCardState();
}

class _MasonryCardState extends State<_MasonryCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: widget.width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: _hover
              ? [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.15), blurRadius: 8)
                ]
              : [],
        ),
        child: Material(
          elevation: 1.5,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // изображение
              widget.image,

              // подпись (градиент + текст)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: 1.0, // градиент всегда есть, чтобы текст читался
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black54, Colors.transparent],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: _hover ? 1.0 : 0.6,
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 0),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: _hover ? 1.0 : 0.6,
                          child: Text(
                            widget.dateText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // кнопка удаления — появляется только при наведении
              Positioned(
                top: 6,
                right: 6,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _hover ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !_hover,
                    child: Material(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: widget.onDeleteTap,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Iconsax.trash,
                              size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
