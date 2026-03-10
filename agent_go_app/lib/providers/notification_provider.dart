import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';

final notificationServiceProvider = Provider((ref) => NotificationService(Supabase.instance.client));

final unreadNotifCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(notificationServiceProvider);
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  
  if (user == null) return Stream.value(0);

  // Initial count
  final controller = StreamController<int>();
  
  void updateCount() async {
    final count = await service.getUnreadCount();
    if (!controller.isClosed) controller.add(count);
  }

  updateCount();

  // Subscribe to real-time changes
  final sub = client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', user.id)
      .listen(
        (_) => updateCount(),
        onError: (err) {
          // Log or handle error silently to prevent crash
        },
      );
  
  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});
