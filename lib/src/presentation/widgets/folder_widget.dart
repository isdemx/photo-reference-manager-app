import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/folder.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/helpers/folders_helpers.dart';
import 'package:photographers_reference_app/src/utils/longpress_vibrating.dart';
import 'package:photographers_reference_app/src/utils/photo_path_helper.dart';

class FolderWidget extends StatelessWidget {
  final Folder folder;

  const FolderWidget({super.key, required this.folder});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/folder', arguments: folder);
      },
      onLongPress: () {
        vibrate();
        FoldersHelpers.showEditFolderDialog(context, folder);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(4),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // ------------ PREVIEW IMAGE ------------
            BlocBuilder<PhotoBloc, PhotoState>(
              builder: (context, photoState) {
                if (photoState is PhotoLoaded) {
                  final photos = photoState.photos
                      .where((p) => p.folderIds.contains(folder.id))
                      .toList();

                  if (photos.isNotEmpty) {
                    final last = photos.last;
                    final helper = PhotoPathHelper();
                    final fullPath = last.isStoredInApp
                        ? helper.getFullPath(last.fileName)
                        : last.path;

                    return Image.file(
                      File(fullPath),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    );
                  } else {
                    return const Center(
                      child:
                          Icon(Icons.folder, size: 48, color: Colors.white70),
                    );
                  }
                }
                return const Center(child: CircularProgressIndicator());
              },
            ),

            // ------------ NAME WITH GRADIENT FADE + SCROLL ------------
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black54,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SizedBox(
                  height: 20,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Text(
                      folder.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
