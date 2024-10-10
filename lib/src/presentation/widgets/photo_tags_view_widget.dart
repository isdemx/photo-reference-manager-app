// lib/src/presentation/widgets/tag_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';
import 'package:photographers_reference_app/src/presentation/screens/tag_screen.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class PhotoTagsViewWidget extends StatelessWidget {
  final Photo photo;

  const PhotoTagsViewWidget({Key? key, required this.photo}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TagBloc, TagState>(
      builder: (context, tagState) {
        if (tagState is TagLoaded) {
          final tags = tagState.tags
              .where((tag) => photo.tagIds.contains(tag.id))
              .toList();

          return SingleChildScrollView(
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
                    // Открываем Color Picker для выбора цвета тега
                    _showColorPicker(context, tag);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: Chip(
                      label: Text(
                        tag.name,
                        style: const TextStyle(
                          fontSize: 10.0, // Уменьшаем размер шрифта для тонкого чипа
                        ),
                      ),
                      side: BorderSide.none,
                      labelPadding: const EdgeInsets.symmetric(
                          vertical: 2.0,
                          horizontal: 3.0), // Паддинг для уменьшения толщины
                      backgroundColor: Color(tag.colorValue),
                      visualDensity: VisualDensity(
                          horizontal: -2.0, vertical: -2.0), // Настройка плотности для уменьшения высоты
                      onDeleted: () {
                        // Удаление тега из фотографии
                        photo.tagIds.remove(tag.id);
                        context.read<PhotoBloc>().add(UpdatePhoto(photo));
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }

  void _showColorPicker(BuildContext context, Tag tag) {
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
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Ok'),
              onPressed: () {
                // Обновляем цвет тега
                tag.colorValue = pickerColor.value;
                context.read<TagBloc>().add(UpdateTag(tag));
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
