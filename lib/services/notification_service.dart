import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  bool _notificationsEnabled = true;
  bool _weatherAlertsEnabled = true;
  bool _taskRemindersEnabled = true;
  bool _emailNotificationsEnabled = true;

  bool get notificationsEnabled => _notificationsEnabled;
  bool get weatherAlertsEnabled => _weatherAlertsEnabled;
  bool get taskRemindersEnabled => _taskRemindersEnabled;
  bool get emailNotificationsEnabled => _emailNotificationsEnabled;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
      
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettings = InitializationSettings(android: androidSettings);

      await _local.initialize(initializationSettings);
      await _loadSettings();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    _weatherAlertsEnabled = prefs.getBool('weather_alerts_enabled') ?? true;
    _taskRemindersEnabled = prefs.getBool('task_reminders_enabled') ?? true;
    _emailNotificationsEnabled = prefs.getBool('email_notifications_enabled') ?? true;
    notifyListeners();
  }

  Future<void> updateSettings({
    bool? notificationsEnabled,
    bool? weatherAlertsEnabled,
    bool? taskRemindersEnabled,
    bool? emailNotificationsEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (notificationsEnabled != null) {
      _notificationsEnabled = notificationsEnabled;
      await prefs.setBool('notifications_enabled', notificationsEnabled);
    }
    
    if (weatherAlertsEnabled != null) {
      _weatherAlertsEnabled = weatherAlertsEnabled;
      await prefs.setBool('weather_alerts_enabled', weatherAlertsEnabled);
    }
    
    if (taskRemindersEnabled != null) {
      _taskRemindersEnabled = taskRemindersEnabled;
      await prefs.setBool('task_reminders_enabled', taskRemindersEnabled);
    }
    
    if (emailNotificationsEnabled != null) {
      _emailNotificationsEnabled = emailNotificationsEnabled;
      await prefs.setBool('email_notifications_enabled', emailNotificationsEnabled);
    }

    notifyListeners();
  }

  Future<void> scheduleTaskReminder({
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      if (!_notificationsEnabled || !_taskRemindersEnabled) return;

      final androidDetails = const AndroidNotificationDetails(
        'task_reminder',
        'Task Reminders',
        channelDescription: 'Notifications for task reminders',
        importance: Importance.high,
        priority: Priority.high,
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await _local.zonedSchedule(
        0,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }

  Future<void> showWeatherAlert({
    required String title,
    required String body,
  }) async {
    if (!_notificationsEnabled || !_weatherAlertsEnabled) return;

    try {
      if (!_isInitialized) {
        await initialize();
      }

      final androidDetails = const AndroidNotificationDetails(
        'weather_alerts',
        'Weather Alerts',
        channelDescription: 'Notifications for weather alerts',
        importance: Importance.high,
        priority: Priority.high,
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await _local.show(0, title, body, notificationDetails);
    } catch (e) {
      print('Error showing weather alert: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      await _local.cancelAll();
    } catch (e) {
      print('Error canceling notifications: $e');
    }
  }
} 