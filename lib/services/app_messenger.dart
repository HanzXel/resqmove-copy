import 'package:flutter/material.dart';

/// App-wide SnackBars using [MaterialApp.scaffoldMessengerKey].
class AppMessenger {
  AppMessenger._();

  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static DateTime? _lastSnack;

  static void showErrorThrottled(
    String message, {
    Duration throttle = const Duration(seconds: 5),
  }) {
    final now = DateTime.now();
    if (_lastSnack != null && now.difference(_lastSnack!) < throttle) return;
    _lastSnack = now;
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFC62828),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
