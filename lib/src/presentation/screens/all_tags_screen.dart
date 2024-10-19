// lib/src/presentation/screens/all_tags_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/tag_bloc.dart';
import 'package:photographers_reference_app/src/presentation/helpers/custom_snack_bar.dart';
import 'package:photographers_reference_app/src/presentation/helpers/tags_helpers.dart';
import 'package:photographers_reference_app/src/presentation/screens/tag_screen.dart';
import 'package:photographers_reference_app/src/utils/longpress_vibrating.dart';
import 'package:vibration/vibration.dart';

class AllTagsScreen extends StatefulWidget {
  const AllTagsScreen({Key? key}) : super(key: key);

  @override
  _AllTagsScreenState createState() => _AllTagsScreenState();
}

class _AllTagsScreenState extends State<AllTagsScreen> {
  Map<String, int> tagPhotoCounts = {};

  @override
  void initState() {
    super.initState();
    context.read<TagBloc>().add(LoadTags());
    context.read<PhotoBloc>().add(LoadPhotos());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              TagsHelpers.showAddTagDialog(context);
            },
          ),
        ],
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<TagBloc, TagState>(
            listener: (context, state) {
              if (state is TagError) {
                CustomSnackBar.showError(context, state.message);
              }
            },
          ),
          BlocListener<PhotoBloc, PhotoState>(
            listener: (context, state) {
              if (state is PhotoError) {
                CustomSnackBar.showError(context, state.message);
              }
            },
          ),
        ],
        child: BlocBuilder<TagBloc, TagState>(
          builder: (context, tagState) {
            if (tagState is TagLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (tagState is TagLoaded) {
              final tags = tagState.tags;
              final photoState = context.watch<PhotoBloc>().state;
              if (photoState is PhotoLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (photoState is PhotoLoaded) {
                final photos = photoState.photos;
                tagPhotoCounts =
                    TagsHelpers.computeTagPhotoCounts(tags, photos);
                final sortedTags = List<Tag>.from(tags);
                sortedTags.sort((a, b) {
                  final countA = tagPhotoCounts[a.id] ?? 0;
                  final countB = tagPhotoCounts[b.id] ?? 0;
                  return countB.compareTo(countA);
                });

                return ListView.builder(
                  itemCount: sortedTags.length,
                  itemBuilder: (context, index) {
                    final tag = sortedTags[index];
                    final photoCount = tagPhotoCounts[tag.id] ?? 0;

                    return ListTile(
                      key: ValueKey(tag.id), // Добавляем уникальный ключ
                      leading: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TagScreen(tag: tag),
                            ),
                          );
                        },
                        onLongPress: () {
                          vibrate();
                          TagsHelpers.showColorPickerDialog(context, tag);
                        },
                        child: CircleAvatar(
                          backgroundColor: Color(tag.colorValue),
                          child: Text(
                            tag.name.isNotEmpty
                                ? tag.name[0].toUpperCase()
                                : '',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      title: GestureDetector(
                        onTap: () {
                          tag.name != 'Not Ref'
                              ? TagsHelpers.showEditTagDialog(context, tag)
                              : null;
                        },
                        child: Text(tag.name),
                      ),
                      subtitle: Text('$photoCount images'),
                      trailing: tag.name != 'Not Ref'
                          ? IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                TagsHelpers.showDeleteConfirmationDialog(
                                    context, tag);
                              },
                            )
                          : null,
                    );
                  },
                );
              } else if (photoState is PhotoError) {
                return Center(child: Text('Error: ${photoState.message}'));
              } else {
                return const Center(child: Text('Caanot load images'));
              }
            } else if (tagState is TagError) {
              return Center(child: Text('Error: ${tagState.message}'));
            } else {
              return const Center(child: Text('Caanot load tags'));
            }
          },
        ),
      ),
    );
  }
}
