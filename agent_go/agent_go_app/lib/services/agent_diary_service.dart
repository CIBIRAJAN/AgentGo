import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/agent_diary_model.dart';
import 'notification_service.dart';

class AgentDiaryService {
  final SupabaseClient _client;
  final List<String> _targetUserIds;

  AgentDiaryService(this._client, {List<String>? targetUserIds})
      : _targetUserIds = targetUserIds ?? [_client.auth.currentUser!.id];

  String get _userId => _client.auth.currentUser!.id;

  Future<List<AgentDiaryModel>> getDiaries() async {
    final response = await _client
        .from('agent_diary')
        .select()
        .inFilter('user_id', _targetUserIds)
        .order('created_at', ascending: false);

    return (response as List).map((e) => AgentDiaryModel.fromJson(e)).toList();
  }

  Future<AgentDiaryModel> createDiary({
    required String name,
    String? phoneNumber,
    String? address,
    DateTime? date1,
    DateTime? date2,
    DateTime? date3,
  }) async {
    final response = await _client.from('agent_diary').insert({
      'user_id': _userId,
      'name': name,
      'phone_number': phoneNumber,
      'address': address,
      'appointment_date_1': date1?.toUtc().toIso8601String(),
      'appointment_date_2': date2?.toUtc().toIso8601String(),
      'appointment_date_3': date3?.toUtc().toIso8601String(),
    }).select().single();

    final entry = AgentDiaryModel.fromJson(response);
    await _scheduleNotifications(entry);
    return entry;
  }

  Future<AgentDiaryModel> updateDiary({
    required String id,
    required String name,
    String? phoneNumber,
    String? address,
    DateTime? date1,
    DateTime? date2,
    DateTime? date3,
  }) async {
    final response = await _client.from('agent_diary').update({
      'name': name,
      'phone_number': phoneNumber,
      'address': address,
      'appointment_date_1': date1?.toUtc().toIso8601String(),
      'appointment_date_2': date2?.toUtc().toIso8601String(),
      'appointment_date_3': date3?.toUtc().toIso8601String(),
    }).eq('id', id).eq('user_id', _userId).select().single();

    final entry = AgentDiaryModel.fromJson(response);
    
    // Cancel old ones, schedule new ones
    await NotificationService.cancelNotificationsForDiary(id);
    await _scheduleNotifications(entry);

    return entry;
  }

  Future<void> deleteDiary(String id) async {
    await _client.from('agent_diary').delete().eq('id', id).eq('user_id', _userId);
    await NotificationService.cancelNotificationsForDiary(id);
  }

  Future<void> _scheduleNotifications(AgentDiaryModel diary) async {
    if (diary.appointmentDate1 != null) {
      await NotificationService.scheduleAppointmentReminder(diary, 1, diary.appointmentDate1!);
    }
    if (diary.appointmentDate2 != null) {
      await NotificationService.scheduleAppointmentReminder(diary, 2, diary.appointmentDate2!);
    }
    if (diary.appointmentDate3 != null) {
      await NotificationService.scheduleAppointmentReminder(diary, 3, diary.appointmentDate3!);
    }
  }
}
