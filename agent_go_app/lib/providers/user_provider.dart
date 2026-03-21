import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class UserNotifier extends AsyncNotifier<UserModel?> {
  final _authService = AuthService(Supabase.instance.client);

  @override
  Future<UserModel?> build() async {
    return _authService.getUserProfile();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _authService.getUserProfile());
  }

  bool get isBasePlan => state.value?.planTier == 'base';
  bool get isMidPlan => state.value?.planTier == 'mid';
  bool get isPremiumPlan => state.value?.planTier == 'premium';
}

final userProvider = AsyncNotifierProvider<UserNotifier, UserModel?>(UserNotifier.new);
