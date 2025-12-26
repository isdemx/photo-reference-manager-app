import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:photographers_reference_app/src/domain/entities/tag.dart';

class SharedTagsSyncService {
  static const MethodChannel _channel = MethodChannel('refma/shared_tags');

  Future<void> syncTags(List<Tag> tags) async {
    if (kIsWeb || !Platform.isIOS) return;

    try {
      final payload = jsonEncode(tags.map((t) => t.toJson()).toList());
      await _channel.invokeMethod('setTagsJson', payload);
    } catch (e) {
      // ignore: avoid_print
      print('[SharedTagsSync] $e');
    }
  }
}
