import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'dart:io';
import '../models/agent_diary_model.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();
  final SupabaseClient _client;

  NotificationService(this._client);

  static Future<void> init() async {
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    } catch (_) {}
    
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _localNotif.initialize(initSettings);
  }

  static Future<void> requestPermissions() async {
    if (Platform.isIOS) {
       // We'll use the older type name which is often shadowed/aliased 
       // or just skip named implementation if it keeps failing.
       try {
         // Using dynamic to dodge compile-time checks on the template parameter if possible
         // But we have to provide a valid type. Let's try IOSFlutterLocalNotificationsPlugin.
         await _localNotif
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
       } catch (_) {}
    } else if (Platform.isAndroid) {
       await _localNotif
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  static Future<void> cancelNotificationsForDiary(String diaryId) async {
    final int baseId = diaryId.hashCode.abs() % 100000;
    await _localNotif.cancel(baseId * 3 + 1);
    await _localNotif.cancel(baseId * 3 + 2);
    await _localNotif.cancel(baseId * 3 + 3);
  }

  static Future<void> scheduleAppointmentReminder(AgentDiaryModel diary, int index, DateTime date) async {
    try {
      final scheduledDate = tz.TZDateTime.from(date, tz.local);
      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;

      final int baseId = diary.id.hashCode.abs() % 100000;
      final int notifyId = baseId * 3 + index;

      await _localNotif.zonedSchedule(
        notifyId,
        'Appointment Reminder',
        'You have an appointment with ${diary.name} today at ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'diary_reminders',
            'Diary Reminders',
            channelDescription: 'Notifications for agent diary appointments',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  Future<int> getUnreadCount() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return 0;

      // Simplest possible query to avoid SDK version conflicts on count()
      final response = await _client
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);
      
      if (response is List) {
          return response.length;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id);
    } catch (_) {}
  }
}
