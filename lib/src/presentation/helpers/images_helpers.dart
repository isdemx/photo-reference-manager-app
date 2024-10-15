import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/helpers/custom_snack_bar.dart';
import 'package:photographers_reference_app/src/utils/photo_share_helper.dart';

class ImagesHelpers {

  static Future<bool> deleteImagesWithConfirmation(
      BuildContext context, List<Photo> photos) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content:
              const Text('Are you sure you want to delete these pictures?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context)
                    .pop(false); // Закрыть диалог и вернуть false
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Если подтверждено, удаляем фотографии
                for (var photo in photos) {
                  BlocProvider.of<PhotoBloc>(context)
                      .add(DeletePhoto(photo.id));
                }
                Navigator.of(context)
                    .pop(true); // Закрыть диалог и вернуть true
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    ).then((value) => value ?? false); // Если результат null, возвращаем false
  }

  static Future<bool> sharePhotos(
      BuildContext context, List<Photo> photos) async {
    if (photos.isEmpty) return false; // Если нет фотографий, возвращаем false

    final PhotoShareHelper shareHelper = PhotoShareHelper();

    try {
      var shared = await shareHelper.shareMultiplePhotos(photos);
      if (shared) {
        CustomSnackBar.showSuccess(context, 'Shared successfully');
        return true; // Возвращаем true при успешном шаринге
      }

      return false; // Возвращаем false, если не удалось расшарить
    } catch (e) {
      CustomSnackBar.showError(context, 'Sharing error: $e');
      return false; // Возвращаем false в случае ошибки
    }
  }
}
