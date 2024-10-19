// utils/export_database.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';

Future<void> exportDatabase(BuildContext context) async {
  print('Export start');
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return Center(child: CircularProgressIndicator());
    },
  );
  try {
    // Get the documents directory to save the backup file
    final appDir = await getApplicationDocumentsDirectory();
    print('Export appDir $appDir');
    final backupFilePath = '${appDir.path}/hive_backup.zip';
    print('Export backupFilePath $backupFilePath');

    // Create archive
    final encoder = ZipFileEncoder();
    print('Export encoder $encoder');
    encoder.create(backupFilePath);

    // Get Hive directory path
    final hiveDirPath = appDir.path;
    print('Export hiveDirPath $hiveDirPath');

    // Add all Hive files to the archive
    final hiveDir = Directory(hiveDirPath);
    print('Export hiveDir $hiveDir');
    final files = hiveDir.listSync(recursive: true);
    print('Export files $files');
    for (var file in files) {
      if (file is File && !file.path.endsWith('hive_backup.zip')) {
        final relativePath = file.path.replaceFirst(hiveDirPath, '');
        encoder.addFile(file, relativePath);
        print('Added file to archive: ${file.path}');
      }
    }

    encoder.close();
    print('Export encoder closed');

    Navigator.of(context).pop(); // Close the loader
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Database successfully exported to $backupFilePath'),
        duration: const Duration(seconds: 25),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  } catch (e) {
    Navigator.of(context).pop(); // Close the loader
    print('Error while exporting database: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not export database'),
        duration: Duration(seconds: 25),
      ),
    );
  }
}
