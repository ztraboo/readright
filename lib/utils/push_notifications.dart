// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:timezone/timezone.dart' as tz;
// import 'package:timezone/data/latest.dart' as tz;
// import 'package:permission_handler/permission_handler.dart';

// /// Service for scheduling a daily 12:00 PM reminder
// class DailyReminderService {
//   static final FlutterLocalNotificationsPlugin _notificationsPlugin =
//       FlutterLocalNotificationsPlugin();

//   /// Must be called once (usually in main())
//   static Future<void> init() async {
//     // Initialize timezone package
//     tz.initializeTimeZones();
//     // Use device local timezone
//     tz.setLocalLocation(tz.local); 

//     // Android initialization
//     const AndroidInitializationSettings androidSettings =
//         AndroidInitializationSettings('@mipmap/ic_launcher');

//     // iOS initialization
//     const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
//       requestAlertPermission: true,
//       requestBadgePermission: true,
//       requestSoundPermission: true,
//     );

//     const InitializationSettings settings = InitializationSettings(
//       android: androidSettings,
//       iOS: iosSettings,
//     );

//     await _notificationsPlugin.initialize(
//       settings,
//       onDidReceiveNotificationResponse: (details) {
//         print('Notification tapped! Payload: ${details.payload}');
//       },
//     );

//     print('DailyReminderService initialized');
//   }

//   /// Request notification permissions
//   static Future<bool> requestPermissionsIfNeeded() async {
//     // iOS permission
//     final iosPlugin = _notificationsPlugin
//         .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
//     if (iosPlugin != null) {
//       final bool? granted = await iosPlugin.requestPermissions(
//         alert: true,
//         badge: true,
//         sound: true,
//       );
//       return granted ?? false;
//     }

//     // Android API 33+ runtime permission
//     if (await Permission.notification.isDenied) {
//       final result = await Permission.notification.request();
//       return result.isGranted;
//     }

//     return true;
//   }

//   /// Schedules a daily reminder at 12:00 PM, or in 10 seconds for test mode
//   static Future<void> scheduleDailyNoonReminder({bool testMode = false}) async {
//     final scheduledTime = _nextInstanceOfNoon(testMode: testMode);
//     print('Notification scheduled for ${scheduledTime.toLocal()}');

//     const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
//       'daily_reminder_channel',
//       'Daily Practice Reminder',
//       channelDescription: 'Daily 12 PM reading practice reminder',
//       importance: Importance.max,
//       priority: Priority.high,
//       playSound: true,
//       ticker: 'Time to practice!',
//     );

//     const NotificationDetails notificationDetails = NotificationDetails(
//       android: androidDetails,
//       iOS: DarwinNotificationDetails(
//         presentAlert: true,
//         presentBadge: true,
//         presentSound: true,
//       ),
//     );

//     await _notificationsPlugin.zonedSchedule(
//       0,
//       'Time to Practice 📚',
//       'Open ReadRight and practice your words!',
//       scheduledTime,
//       notificationDetails,
//       androidAllowWhileIdle: true,
//       uiLocalNotificationDateInterpretation:
//           UILocalNotificationDateInterpretation.absoluteTime,
//       matchDateTimeComponents: testMode ? null : DateTimeComponents.time,
//     );

//     print('Notification scheduled successfully');
//   }

//   /// Cancel daily reminder
//   static Future<void> cancelDailyReminder() async {
//     await _notificationsPlugin.cancel(0);
//     print('Daily reminder canceled');
//   }

//   /// Returns the next 12:00 PM occurrence (or 10 seconds from now if testMode)
// static tz.TZDateTime _nextInstanceOfNoon({bool testMode = false}) {
//   final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

//   if (testMode) {
//     // Schedule 10 seconds from now in local time
//     return now.add(const Duration(seconds: 10));
//   } else {
//     tz.TZDateTime scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 12);
//     if (scheduled.isBefore(now)) {
//       scheduled = scheduled.add(const Duration(days: 1));
//     }
//     return scheduled;
//   }
// }
//   static Future<void> showImmediateTestNotification() async {
//   const AndroidNotificationDetails androidDetails =
//       AndroidNotificationDetails(
//     'immediate_test_channel',
//     'Immediate Test Notifications',
//     channelDescription: 'Immediate test notifications',
//     importance: Importance.max,
//     priority: Priority.high,
//   );

//   const NotificationDetails details = NotificationDetails(
//     android: androidDetails,
//     iOS: DarwinNotificationDetails(
//       presentAlert: true,
//       presentSound: true,
//     ),
//   );

//   await _notificationsPlugin.show(
//     123,
//     '✅ Test Notification',
//     'This should appear instantly',
//     details,
//   );
// }
// }
