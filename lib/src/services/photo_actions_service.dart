// lib/src/presentation/services/photo_actions_service.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/utils/photo_share_helper.dart';

class PhotoActionsService {
  final BuildContext context;

  PhotoActionsService(this.context);

  Future<void> sharePhotos(List<Photo> photos) async {
    final shareHelper = PhotoShareHelper();

    try {
      var shared = await shareHelper.shareMultiplePhotos(photos);
      if (shared) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shared successfully'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sharing error: $e')),
      );
    }
  }

  Future<void> deletePhotos(List<Photo> photos) async {
    final photoBloc = BlocProvider.of<PhotoBloc>(context);

    for (var photo in photos) {
      photoBloc.add(DeletePhoto(photo.id));
    }
  }

  // Future<void> addPhotosToFolder(List<Photo> photos) async {
  //   // Assuming you have an updated AddToFolderWidget that accepts multiple photos
  //   await showDialog(
  //     context: context,
  //     builder: (context) {
  //       return AddToFolderWidget(
  //         photos: photos,
  //         onFolderAdded: () {
  //           // Handle any additional logic after adding to folder
  //         },
  //       );
  //     },
  //   );
  // }

  // Future<void> addPhotosToTag(List<Photo> photos) async {
  //   // Assuming you have an updated AddTagWidget that accepts multiple photos
  //   await showDialog(
  //     context: context,
  //     builder: (context) {
  //       return AddTagWidget(
  //         photos: photos,
  //         onTagAdded: () {
  //           // Handle any additional logic after adding tags
  //         },
  //       );
  //     },
  //   );
  // }
}
