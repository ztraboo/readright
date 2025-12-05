import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:readright/utils/app_constants.dart';

// This was generated with ChatGPT to provide a simple online/offline monitoring utility.
// Singleton OnlineMonitor
// start/stop, stream of status changes, SharedPreferences persistence, safe to call from AppInitializer
// Benefits:
// - Keeps AppInitializer focused on startup orchestration.
// - Reusable across the app (widgets or services can subscribe to online/offline changes).
// - Easier to test and mock.
// - Centralized control (start/stop, interval, probe host, prefs key).
class OnlineMonitor {
  OnlineMonitor._internal();
  static final OnlineMonitor instance = OnlineMonitor._internal();

  static const String prefsKey = AppConstants.prefIsOnline;
  final Duration _defaultInterval = const Duration(seconds: 10);

  Timer? _timer;
  SharedPreferences? _prefs;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _running = false;

  /// Start monitoring. Safe to call multiple times.
  Future<void> start({Duration? interval, String probeHost = 'google.com'}) async {
    if (_running) return;
    _prefs ??= await SharedPreferences.getInstance();
    await _checkAndSet(probeHost);
    _timer = Timer.periodic(interval ?? _defaultInterval, (_) => _checkAndSet(probeHost));
    _running = true;
  }

  /// Stop monitoring.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  /// Stream of online status changes.
  Stream<bool> get onStatusChanged => _controller.stream;

  /// Current known status (may be null before first probe completes).
  bool? get currentStatus => _prefs?.getBool(prefsKey);

  Future<void> _checkAndSet(String probeHost) async {
    bool online = false;
    try {
      final result = await InternetAddress.lookup(probeHost).timeout(const Duration(seconds: 5));
      online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      online = false;
    }

    try {
      await _prefs?.setBool(prefsKey, online);
      debugPrint('OnlineMonitor: Online ($online)');
    } catch (_) {
      // ignore write failures
    }

    // emit status to listeners
    if (!_controller.isClosed) {
      _controller.add(online);
    }
  }

  /// Dispose resources (call on app shutdown if desired).
  Future<void> dispose() async {
    stop();
    await _controller.close();
  }
}