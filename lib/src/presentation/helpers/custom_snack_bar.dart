import 'package:flutter/material.dart';

class CustomSnackBar {
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Center( // Выровнять текст по центру
          child: Text(
            message,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center, // Дополнительно выровнять текст по центру
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 216, 83, 74).withOpacity(0.7),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Center( // Выровнять текст по центру
          child: Text(
            message,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center, // Дополнительно выровнять текст по центру
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 80, 151, 83).withOpacity(0.7),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
      ),
    );
  }
}
