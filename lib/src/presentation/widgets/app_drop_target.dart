import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:photographers_reference_app/src/presentation/helpers/get_media_type.dart';
import 'package:photographers_reference_app/src/presentation/helpers/photo_save_helper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photographers_reference_app/src/presentation/bloc/photo_bloc.dart';

class AppDropTarget extends StatefulWidget {
  final Widget child;

  const AppDropTarget({Key? key, required this.child}) : super(key: key);

  @override
  _AppDropTargetState createState() => _AppDropTargetState();
}

class _AppDropTargetState extends State<AppDropTarget> {
  bool _dragOver = false;

  Future<void> _handleDrop(List<dynamic> files) async {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    print('Current route: $currentRoute');
    return;

    // Не реагируем, если НЕ на MainScreen
    if (currentRoute != null &&
        currentRoute != '/' &&
        currentRoute != '/main') {
      print('Skip drop because current route is $currentRoute');
      return;
    }

    bool uploadedAny = false;

    for (final xfile in files) {
      final file = File(xfile.path);
      final bytes = await file.readAsBytes();
      final fileName = p.basename(file.path);
      final mediaType = getMediaType(file.path);

      final newPhoto = await PhotoSaveHelper.savePhoto(
        fileName: fileName,
        bytes: bytes,
        context: context,
        mediaType: mediaType
      );

      context.read<PhotoBloc>().add(AddPhoto(newPhoto));
      uploadedAny = true;
    }

    if (uploadedAny && currentRoute != '/all_photos') {
      Navigator.pushNamed(context, '/all_photos');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: (details) => _handleDrop(details.files),
      onDragEntered: (_) => setState(() => _dragOver = true),
      onDragExited: (_) => setState(() => _dragOver = false),
      child: Container(
        color: _dragOver ? Colors.black12 : null,
        child: widget.child,
      ),
    );
  }
}
