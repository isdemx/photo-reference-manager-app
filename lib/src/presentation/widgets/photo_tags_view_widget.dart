// lib/src/presentation/widgets/tag_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';
import 'package:photographers_reference_app/src/presentation/helpers/tags_helpers.dart';
import 'package:photographers_reference_app/src/presentation/screens/tag_screen.dart';
import 'package:photographers_reference_app/src/utils/longpress_vibrating.dart';

class PhotoTagsViewWidget extends StatefulWidget {
  final Photo photo;

  const PhotoTagsViewWidget({super.key, required this.photo});

  @override
  _PhotoTagsViewWidgetState createState() => _PhotoTagsViewWidgetState();
}

class _PhotoTagsViewWidgetState extends State<PhotoTagsViewWidget> {
  static const double _minHeight = 32.0;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TagBloc, TagState>(
      builder: (context, tagState) {
        if (tagState is TagLoaded) {
          final tags = tagState.tags
              .where((tag) => widget.photo.tagIds.contains(tag.id))
              .toList();

          return SizedBox(
            height: _minHeight,
            child: tags.isEmpty
                ? const SizedBox.shrink()
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal, // Горизонтальный скролл
                    child: Row(
                      children: tags.map((tag) {
                        return GestureDetector(
                          onTap: () {
                            // Переход на экран с фотографиями по тегу
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TagScreen(tag: tag),
                              ),
                            );
                          },
                          onLongPress: () {
                            vibrate();
                            // Открываем Color Picker для выбора цвета тега
                            TagsHelpers.showColorPickerDialog(context, tag);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                            child: Chip(
                              label: Text(
                                tag.name,
                                style: const TextStyle(
                                  fontSize:
                                      10.0, // Уменьшаем размер шрифта для тонкого чипа
                                ),
                              ),
                              side: BorderSide.none,
                              labelPadding: const EdgeInsets.symmetric(
                                  vertical: 2.0,
                                  horizontal:
                                      3.0), // Паддинг для уменьшения толщины
                              backgroundColor: Color(tag.colorValue),
                              visualDensity: const VisualDensity(
                                  horizontal: -2.0,
                                  vertical:
                                      -2.0), // Настройка плотности для уменьшения высоты
                              onDeleted: () {
                                setState(() {
                                  // Удаление тега из фотографии и обновление состояния
                                  widget.photo.tagIds.remove(tag.id);
                                  context
                                      .read<PhotoBloc>()
                                      .add(UpdatePhoto(widget.photo));
                                });
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          );
        } else {
          return const SizedBox(height: _minHeight);
        }
      },
    );
  }
}
