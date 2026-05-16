// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Notification Service
//  lib/services/notification_service.dart
//
//  Handles:
//    • Local push notifications (flutter_local_notifications)
//    • Firebase Cloud Messaging (FCM) for remote push
//    • Notification channel setup for Android 8+
//
//  Usage:
//    await NotificationService.instance.init();   ← call in main()
//    NotificationService.instance.showLocal(...)  ← show from anywhere
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

// ── Top-level FCM background handler (required by firebase_messaging) ─────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM Background] \${message.notification?.title}: \${message.notification?.body}');
  await NotificationService.instance.showLocal(
    title: message.notification?.title ?? 'ResQMove',
    body: message.notification?.body ?? '',
    payload: message.data['payload']?.toString(),
    isDispatch: message.data['type'] == 'dispatch',
  );
}

// ── Channel IDs ───────────────────────────────────────────────────────────────
const _kDispatchChannelId = 'resqmove_dispatch';
const _kDispatchChannelName = 'Dispatch Alerts';
const _kStatusChannelId = 'resqmove_status';
const _kStatusChannelName = 'Trip Status Updates';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _fcm;

  /// Invoked when user taps a notification. Receives the payload string.
  Function(String? payload)? onNotificationTapped;

  bool _initialized = false;

  // ── Init ────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _initLocal();
    await _initFcm();
    await _requestPermission();
  }

  // ── Local notifications setup ──────────────────────────────────────────────

  Future<void> _initLocal() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (details) {
        onNotificationTapped?.call(details.payload);
      },
      onDidReceiveBackgroundNotificationResponse: _onBackgroundTap,
    );

    final plugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await plugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _kDispatchChannelId,
        _kDispatchChannelName,
        description: 'Critical alerts for incoming ambulance dispatch requests.',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
      ),
    );

    await plugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _kStatusChannelId,
        _kStatusChannelName,
        description: 'Ambulance booking status updates.',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      ),
    );
  }

  // ── FCM setup ──────────────────────────────────────────────────────────────

  Future<void> _initFcm() async {
    try {
      await Firebase.initializeApp();
      _fcm = FirebaseMessaging.instance;

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      FirebaseMessaging.onMessageOpenedApp.listen((msg) {
        onNotificationTapped?.call(msg.data['payload']?.toString());
      });

      final initial = await _fcm!.getInitialMessage();
      if (initial != null) {
        onNotificationTapped?.call(initial.data['payload']?.toString());
      }

      final token = await _fcm!.getToken();
      if (kDebugMode) debugPrint('[NotificationService] FCM token: \$token');

      _fcm!.onTokenRefresh.listen((newToken) {
        if (kDebugMode) debugPrint('[NotificationService] FCM token refreshed: \$newToken');
        // TODO: POST /device/token with newToken once backend is live
      });
    } catch (e) {
      // Firebase not configured yet (missing google-services.json) — graceful fallback
      if (kDebugMode) debugPrint('[NotificationService] Firebase init skipped: \$e');
    }
  }

  // ── Permission request ─────────────────────────────────────────────────────

  Future<void> _requestPermission() async {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    }
    try {
      await _fcm?.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    } catch (_) {}
  }

  // ── Foreground FCM message handler ────────────────────────────────────────

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await showLocal(
      title: notification.title ?? 'ResQMove',
      body: notification.body ?? '',
      payload: message.data['payload']?.toString(),
      isDispatch: message.data['type'] == 'dispatch',
    );
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> showLocal({
    required String title,
    required String body,
    String? payload,
    bool isDispatch = false,
  }) async {
    final channelId = isDispatch ? _kDispatchChannelId : _kStatusChannelId;
    final channelName = isDispatch ? _kDispatchChannelName : _kStatusChannelName;

    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: isDispatch ? Importance.max : Importance.high,
          priority: isDispatch ? Priority.max : Priority.high,
          ticker: 'ResQMove',
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  Future<void> notifyAmbulanceDispatched({String? eta}) async {
    await showLocal(
      title: '🚑 Ambulance Dispatched',
      body: eta != null
          ? 'Your ambulance is en route — ETA \$eta minutes.'
          : 'Your ambulance is on the way to your location.',
    );
  }

  Future<void> notifyStatusUpdate(String statusLabel) async {
    await showLocal(
      title: 'Trip Update',
      body: statusLabel,
    );
  }

  Future<void> notifyDriverIncomingRequest(String emergencyType, String address) async {
    await showLocal(
      title: '🚨 Incoming Request',
      body: '\$emergencyType — \$address',
      isDispatch: true,
    );
  }

  Future<String?> getFcmToken() async {
    try {
      return await _fcm?.getToken();
    } catch (_) {
      return null;
    }
  }
}

@pragma('vm:entry-point')
void _onBackgroundTap(NotificationResponse details) {
  // handled when app resumes via onNotificationTapped
}
