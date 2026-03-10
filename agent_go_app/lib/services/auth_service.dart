import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

/// Handles authentication and user profile operations.
class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  /// Current authenticated user ID.
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Whether a user is signed in.
  bool get isAuthenticated => _client.auth.currentUser != null;

  /// Stream of auth state changes.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Sign up with email and password.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: fullName != null ? {'full_name': fullName} : null,
    );
  }

  /// Sign in with email and password.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Get user profile from the public.user table.
  Future<UserModel?> getUserProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;

    final response =
        await _client.from('user').select().eq('id', userId).maybeSingle();

    if (response == null) return null;
    return UserModel.fromJson(response);
  }

  /// Update user profile.
  Future<void> updateProfile({
    String? name,
    String? phoneNumber,
    String? profile,
    bool? notification,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (phoneNumber != null) updates['phone_number'] = phoneNumber;
    if (profile != null) updates['profile'] = profile;
    if (notification != null) updates['notification'] = notification;

    if (updates.isNotEmpty) {
      await _client.from('user').update(updates).eq('id', userId);
    }
  }

  /// Send password reset email.
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }
}
