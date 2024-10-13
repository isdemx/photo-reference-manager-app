import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';
import 'package:photographers_reference_app/src/presentation/widgets/column_slider.dart';
import 'package:photographers_reference_app/src/presentation/widgets/photo_grid_view.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class AllPhotosScreen extends StatefulWidget {
  const AllPhotosScreen({Key? key}) : super(key: key);

  @override
  _AllPhotosScreenState createState() => _AllPhotosScreenState();
}

class _AllPhotosScreenState extends State<AllPhotosScreen> {
  bool _isPinterestLayout = false;
  bool _filterNotRef = true;
  int _columnCount = 3; // Начальное значение колонок

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PhotoBloc, PhotoState>(
      builder: (context, photoState) {
        return BlocBuilder<TagBloc, TagState>(
          builder: (context, tagState) {
            if (photoState is PhotoLoading || tagState is TagLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (photoState is PhotoLoaded && tagState is TagLoaded) {
              final tags = tagState.tags;

              final List<Photo> photos = _filterNotRef
                  ? photoState.photos.where((photo) {
                      return photo.tagIds.every((tagId) {
                        final tag = tags.firstWhere((tag) => tag.id == tagId);
                        return tag.name != "Not Ref";
                      });
                    }).toList()
                  : photoState.photos;

              String titleText = 'All Photos (${photos.length})';

              if (photos.isEmpty) {
                return Scaffold(
                  appBar: AppBar(
                    title: Text(titleText),
                  ),
                  body: const Center(child: Text('No photos available.')),
                );
              }

              return Scaffold(
                body: Stack(
                  children: [
                    CustomScrollView(
                      slivers: [
                        SliverAppBar(
                          backgroundColor: Colors.black.withOpacity(0.5),
                          pinned: true,
                          title: Row(
                            children: [
                              Expanded(child: Text(titleText)),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _filterNotRef = !_filterNotRef;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6.0, vertical: 3.0),
                                  decoration: BoxDecoration(
                                    color: _filterNotRef
                                        ? Colors.blueAccent
                                        : Colors.transparent,
                                    border:
                                        Border.all(color: Colors.blueAccent),
                                    borderRadius: BorderRadius.circular(20.0),
                                  ),
                                  child: Text(
                                    'Ref Only',
                                    style: TextStyle(
                                      fontSize: 12.0,
                                      color: _filterNotRef
                                          ? Colors.white
                                          : Colors.blueAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            IconButton(
                              icon: Icon(_isPinterestLayout
                                  ? Icons.grid_on
                                  : Icons.dashboard),
                              onPressed: () {
                                setState(() {
                                  _isPinterestLayout = !_isPinterestLayout;
                                });
                              },
                              tooltip: _isPinterestLayout
                                  ? 'Switch to Grid View'
                                  : 'Switch to Pinterest View',
                            ),
                          ],
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.all(8.0),
                          sliver: PhotoGridView(
                            photos: photos,
                            pinterestView:
                                _isPinterestLayout, // Логика для выбора типа сетки
                            columnCount: _columnCount, // Количество колонок
                            onPhotoTap: (photo, index) {
                              Navigator.pushNamed(
                                context,
                                '/photo',
                                arguments: {'photos': photos, 'index': index},
                              );
                            },
                            onDeleteTap: (photo) {
                              context
                                  .read<PhotoBloc>()
                                  .add(DeletePhoto(photo.id));
                            },
                          ),
                        ),
                      ],
                    ),
                    ColumnSlider(
                      initialCount: 3,
                      columnCount: _columnCount,
                      onChanged: (value) {
                        setState(() {
                          _columnCount = value;
                        });
                      },
                    ),
                  ],
                ),
              );
            } else {
              return const Center(child: Text('Failed to load photos.'));
            }
          },
        );
      },
    );
  }
}
