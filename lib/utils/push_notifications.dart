import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

/// Service for scheduling a daily 12:00 PM reminder
class DailyReminderService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Must be called once (usually in main())
  static Future<void> init() async {
    // Initialize timezone package
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.local); // Use device local timezone

    // Android initialization
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings);
  }

static Future<bool> requestPermissionsIfNeeded() async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // iOS permission
  final iosPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
  if (iosPlugin != null) {
    final bool? granted = await iosPlugin.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return granted ?? false;
  }

  // Android permission (runtime required on API 33+)
  if (await Permission.notification.isDenied) {
    final result = await Permission.notification.request();
    return result.isGranted;
  }

  return true;
}

  /// Schedules a daily reminder at 12:00 PM
  /// Set [testMode] to true to schedule 10 seconds from now for testing
  static Future<void> scheduleDailyNoonReminder({bool testMode = false}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_reminder_channel',
      'Daily Practice Reminder',
      channelDescription: 'Daily 12 PM reading practice reminder',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notificationsPlugin.zonedSchedule(
      0,
      'Time to Practice 📚',
      'Open ReadRight and practice your words!',
      _nextInstanceOfNoon(testMode: testMode),
      notificationDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Cancels the daily reminder
  static Future<void> cancelDailyReminder() async {
    await _notificationsPlugin.cancel(0);
  }

  /// Determines the next 12:00 PM occurrence (or 10 seconds from now if testMode)
  static tz.TZDateTime _nextInstanceOfNoon({bool testMode = false}) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    if (testMode) {
      // Schedule 10 seconds from now for testing
      return now.add(const Duration(seconds: 10));
    } else {
      // Regular daily 12 PM
      tz.TZDateTime scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 12);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      return scheduled;
    }
  }
}
