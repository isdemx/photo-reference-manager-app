import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class RatingPromptHandler {
  static const _launchCountKey = 'launchCount';
  static const _hasRatedKey = 'hasRated';

  static Future<bool> shouldShowPrompt() async {
    print('shouldShowPrompt');
    final prefs = await SharedPreferences.getInstance();
    final alreadyRated = prefs.getBool(_hasRatedKey) ?? false;
    print('shouldShowPrompt alreadyRated = $alreadyRated');
    if (alreadyRated) return false;

    final launchCount = prefs.getInt(_launchCountKey) ?? 0;
    prefs.setInt(_launchCountKey, launchCount + 1);

    print('shouldShowPrompt launchCount = $launchCount');

    if (launchCount < 2) return false;

    bool rand = Random().nextInt(5) == 0;

    print('shouldShowPrompt rand = $rand');

    // 1 из 5 шансов
    return rand;
  }

  static Future<void> markAsRated() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(_hasRatedKey, true);
  }

  static void showRatingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Enjoying the app?"),
        content: const Text(
            "This app does not use analytics or tracking to protect your privacy.\n\n"
            "The only way to support its development is by putting rating and leaving a review.\n\n"
            "Your feedback helps the app grow and reach more users. Thank you!"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Later"),
          ),
          TextButton(
            onPressed: () async {
              await markAsRated();
              _openStoreLink();
              Navigator.of(ctx).pop();
            },
            child: const Text("Leave a review"),
          ),
        ],
      ),
    );
  }

  static void _openStoreLink() async {
    const androidUrl = 'market://details?id=com.example.app';
    const iosUrl = 'https://apps.apple.com/app/id6733253421';

    final fallbackUrl = Platform.isAndroid
        ? 'https://play.google.com/store/apps/details?id=com.example.app'
        : iosUrl;

    final uri = Uri.parse(Platform.isAndroid ? androidUrl : iosUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await launchUrl(Uri.parse(fallbackUrl),
          mode: LaunchMode.externalApplication);
    }
  }
}
