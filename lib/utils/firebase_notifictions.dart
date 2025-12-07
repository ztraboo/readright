import 'dart:io';
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
    print('Background message: ${message.messageId}');
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

      print('Permission status: ${settings.authorizationStatus}');
    }
  }

  /// Get and listen for FCM token
  Future<void> _setupToken() async {
    final token = await _messaging.getToken();
    print('FCM Token: $token');

    _messaging.onTokenRefresh.listen((newToken) {
      print('New FCM Token: $newToken');
      // TODO: Save to backend / Firestore
    });
  }

  /// App in foreground
  void _setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message received');
      print('Title: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');
    });
  }

  /// App opened from notification
  void _setupNotificationTapListener() {
    FirebaseMessaging.onMessageOpenedApp
        .listen((RemoteMessage message) {
      print('Notification tapped');
    });
  }

  /// App launched from terminated state
  Future<void> handleInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    if (message != null) {
      print('Opened from terminated state');
    }
  }
}
