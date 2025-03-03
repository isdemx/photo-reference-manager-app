import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

Future<Directory> getIosTemporaryDirectory() async {
  if (Platform.isIOS || Platform.isAndroid) {
    const MethodChannel channel = MethodChannel('my_app/temp_dir');
    final String path = await channel.invokeMethod('getNSTemporaryDirectory');
    return Directory(path);
  } else {
    // Для других платформ используем стандартный метод
    return await getTemporaryDirectory();
  }
}
