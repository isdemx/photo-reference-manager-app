// utils/import_database.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:hive/hive.dart';
import 'package:photographers_reference_app/src/utils/hive_boxes.dart';

Future<void> importDatabase(BuildContext context) async {
  print('Import start');
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return Center(child: CircularProgressIndicator());
    },
  );
  try {
    // Allow the user to pick the backup file
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select the backup file',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    print('Import result $result');

    if (result != null && result.files.single.path != null) {
      final backupFilePath = result.files.single.path!;
      final backupFile = File(backupFilePath);
      print('Import backupFile $backupFile');

      // Close all open Hive boxes before importing
      await Hive.close();
      print('Hive closed');

      // Get the Hive directory path
      final appDir = await getApplicationDocumentsDirectory();
      print('Import appDir $appDir');
      final hiveDirPath = appDir.path;
      print('Import hiveDirPath $hiveDirPath');

      // Clear the current Hive directory
      final hiveDir = Directory(hiveDirPath);
      if (hiveDir.existsSync()) {
        await hiveDir.delete(recursive: true);
        print('Hive directory cleared');
      }
      await hiveDir.create();
      print('Hive directory recreated');

      // Extract the archive to the Hive directory
      final bytes = await backupFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      print('Archive decoded');

      for (var file in archive) {
        final filename = file.name;
        final data = file.content as List<int>;

        final outFile = File('$hiveDirPath/$filename');
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(data, flush: true);
        print('Extracted file: $filename');
      }

      // Reopen Hive boxes
      await openHiveBoxes();
      print('Hive boxes reopened');

      Navigator.of(context).pop(); // Close the loader

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Database successfully imported'),
          duration: Duration(seconds: 25),
        ),
      );
    } else {
      Navigator.of(context).pop(); // Close the loader
      print('Import canceled by user');
    }
  } catch (e) {
    Navigator.of(context).pop(); // Close the loader
    print('Error while importing database: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not import database'),
        duration: Duration(seconds: 25),
      ),
    );
  }
}
