import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseNotificationService {
  FirebaseNotificationService._();
  static final instance = FirebaseNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Call from main()
  static Future<void> firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    await Firebase.initializeApp();
    debugPrint('Background message: ${message.messageId}');
  }

  /// Initialize everything
  Future<void> initialize() async {
    await _requestPermission();
    await _setupToken();
    _setupForegroundListener();
    _setupNotificationTapListener();
  }

  /// Permissions (iOS + Android 13+)
  Future<void> _requestPermission() async {
    if (Platform.isIOS || Platform.isAndroid) {
      NotificationSettings settings =
          await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint('Permission status: ${settings.authorizationStatus}');
    }
  }

  /// Get and listen for FCM token
  Future<void> _setupToken() async {
    String? token;
    const int maxAttempts = 8; // increase attempts to give APNS more time

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        // On iOS try to read the APNS token (this can help trigger it becoming available)
        if (Platform.isIOS) {
          try {
            final apns = await _messaging.getAPNSToken();
            debugPrint('APNS token (attempt $attempt): $apns');
          } catch (e) {
            debugPrint('Error while fetching APNS token (attempt $attempt): $e');
          }
        }

        token = await _messaging.getToken();
        // If token is null or empty, treat as APNS not set and retry
        if (token != null && token.isNotEmpty) {
          break;
        } else {
          throw FirebaseException(
            plugin: 'firebase_messaging',
            code: 'apns-token-not-set',
            message: 'FCM token is null or empty',
          );
        }
      } on FirebaseException catch (e) {
        // FirebaseMessaging on iOS can throw when the APNS token is not yet available.
        if (e.code == 'apns-token-not-set') {
          debugPrint('APNS token not set yet (attempt $attempt/$maxAttempts). Retrying...');
          if (attempt == maxAttempts) {
            debugPrint('Giving up waiting for APNS token.');
          } else {
            // exponential backoff (1s, 2s, 4s, ...)
            final delaySeconds = 1 << (attempt - 1);
            await Future.delayed(Duration(seconds: delaySeconds));
            continue;
          }
        } else {
          debugPrint('Failed to get FCM token: ${e.message}');
          break;
        }
      } catch (e) {
        debugPrint('Unexpected error getting FCM token: $e');
        break;
      }
    }

    debugPrint('FCM Token: $token');

    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('New FCM Token: $newToken');
      // TODO: If you need to target individual users the save token(s) to the Firestore users collection. This is for later release if needed.
    });
  }

  /// App in foreground
  void _setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground message received');
      debugPrint('Title: ${message.notification?.title}');
      debugPrint('Body: ${message.notification?.body}');
    });
  }

  /// App opened from notification
  void _setupNotificationTapListener() {
    FirebaseMessaging.onMessageOpenedApp
        .listen((RemoteMessage message) {
      debugPrint('Notification tapped');
    });
  }

  /// App launched from terminated state
  Future<void> handleInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    if (message != null) {
      debugPrint('Opened from terminated state');
    }
  }
}
