import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();

  factory NotificationService() => _instance;

  NotificationService._();

  static const String _prefKeyDownloadNotifications =
      'download_notifications_enabled_v1';
  static const String _channelId = 'model_downloads';
  static const String _channelName = 'Model Downloads';
  static const String _channelDescription =
      'Shows download progress for local AI models';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  
  // Map to store auto-dismiss timers for each notification
  final Map<int, Timer> _autoDismissTimers = {};

  Future<void> initialize() async {
    if (_initialized) return;

    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _plugin.initialize(initializationSettings);

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  Future<bool> areDownloadNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyDownloadNotifications) ?? true;
  }

  Future<void> setDownloadNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyDownloadNotifications, enabled);
    if (!enabled) {
      await cancelAllDownloadNotifications();
    }
  }

  Future<bool> requestPermissionIfNeeded() async {
    await initialize();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();

    return granted ?? true;
  }

  Future<void> showDownloadProgress({
    required String modelName,
    required int received,
    required int total,
  }) async {
    await initialize();

    if (!await areDownloadNotificationsEnabled()) return;

    // Use 0-100 percentage values for Android notification progress fields.
    // Passing raw byte counts can exceed Integer size and crash plugin parsing.
    final hasTotal = total > 0;
    final progressPercent = hasTotal
        ? ((received / total) * 100).clamp(0, 100).toInt()
        : 0;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        onlyAlertOnce: true,
        showProgress: true,
        maxProgress: hasTotal ? 100 : 0,
        progress: hasTotal ? progressPercent : 0,
        indeterminate: !hasTotal,
        playSound: false,
      ),
    );

    final title = 'Downloading model';
    final body = hasTotal
        ? '$modelName • $progressPercent%'
        : '$modelName • Preparing...';

    await _plugin.show(
      _notificationIdForModel(modelName),
      title,
      body,
      details,
    );
  }

  Future<void> showDownloadCompleted(String modelName) async {
    await initialize();

    if (!await areDownloadNotificationsEnabled()) return;

    final notificationId = _notificationIdForModel(modelName);
    
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        ongoing: false,
      ),
    );

    await _plugin.show(
      notificationId,
      'Model download complete',
      '$modelName is ready to use.',
      details,
    );
    
    // Schedule auto-dismiss after 3 seconds
    _scheduleAutoDismiss(notificationId, const Duration(seconds: 3));
  }

  Future<void> showDownloadFailed(String modelName) async {
    await initialize();

    if (!await areDownloadNotificationsEnabled()) return;

    final notificationId = _notificationIdForModel(modelName);
    
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        ongoing: false,
      ),
    );

    await _plugin.show(
      notificationId,
      'Model download failed',
      'Failed to download $modelName. Tap retry in app.',
      details,
    );
  }

  Future<void> cancelDownloadNotification(String modelName) async {
    await initialize();
    final notificationId = _notificationIdForModel(modelName);
    
    // Cancel any pending auto-dismiss timer
    _autoDismissTimers[notificationId]?.cancel();
    _autoDismissTimers.remove(notificationId);
    
    await _plugin.cancel(notificationId);
  }

  Future<void> cancelAllDownloadNotifications() async {
    await initialize();
    
    // Cancel all pending auto-dismiss timers
    for (final timer in _autoDismissTimers.values) {
      timer.cancel();
    }
    _autoDismissTimers.clear();
    
    await _plugin.cancelAll();
  }

  void _scheduleAutoDismiss(int notificationId, Duration delay) {
    // Cancel any existing timer for this notification
    _autoDismissTimers[notificationId]?.cancel();
    
    // Schedule new auto-dismiss timer
    _autoDismissTimers[notificationId] = Timer(delay, () {
      _plugin.cancel(notificationId);
      _autoDismissTimers.remove(notificationId);
    });
  }

  int _notificationIdForModel(String modelName) {
    return modelName.hashCode & 0x7FFFFFFF;
  }
}
