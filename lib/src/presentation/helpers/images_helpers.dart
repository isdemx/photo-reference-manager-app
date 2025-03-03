import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/domain/entities/photo.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';
import 'package:photographers_reference_app/src/presentation/helpers/custom_snack_bar.dart';
import 'package:photographers_reference_app/src/utils/photo_share_helper.dart';

/// Диалоговое окно для подтверждения удаления
class DeleteConfirmationDialog extends StatelessWidget {
  final List<Photo> photos;

  const DeleteConfirmationDialog({
    Key? key,
    required this.photos,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Deletion'),
      content: const Text('Are you sure you want to delete these pictures?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            // Если подтверждено, удаляем фотографии
            for (var photo in photos) {
              BlocProvider.of<PhotoBloc>(context).add(DeletePhoto(photo.id));
            }
            Navigator.of(context).pop(true);
          },
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}

/// Показывает диалог для подтверждения удаления и обрабатывает нажатие Enter
Future<bool> showDeleteConfirmationDialog(
    BuildContext context, List<Photo> photos) async {
  return showDialog<bool>(
    context: context,
    builder: (_) {
      return Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          // Проверяем, что это нажатие клавиши (KeyDownEvent) и логическая клавиша Enter
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.enter) {
            // Возвращаем из диалога true — эквивалент нажатия Delete
            Navigator.of(context).pop(true);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: DeleteConfirmationDialog(photos: photos),
      );
    },
  ).then((value) => value ?? false); // Если результат null, возвращаем false
}

class ImagesHelpers {
  /// Показывает диалог подтверждения удаления и, если пользователь
  /// подтвердил, вызывает удаление фотографий.
  static Future<bool> deleteImagesWithConfirmation(
      BuildContext context, List<Photo> photos) async {
    return await showDeleteConfirmationDialog(context, photos);
  }

  /// Шарит список фотографий. Возвращает true, если шаринг успешен.
  static Future<bool> sharePhotos(BuildContext context, List<Photo> photos) async {
    if (photos.isEmpty) return false;

    final PhotoShareHelper shareHelper = PhotoShareHelper();
    try {
      final shared = await shareHelper.shareMultiplePhotos(photos);
      if (shared) {
        CustomSnackBar.showSuccess(context, 'Shared successfully');
        return true;
      }
      return false;
    } catch (e) {
      CustomSnackBar.showError(context, 'Sharing error: $e');
      return false;
    }
  }
}
