import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/client_model.dart';
import '../models/agent_connection_model.dart';

/// Manages CRUD operations for the client (customer) table.
class ClientService {
  final SupabaseClient _client;
  final List<String> _targetUserIds;

  ClientService(this._client, {List<String>? targetUserIds}) 
    : _targetUserIds = targetUserIds ?? [_client.auth.currentUser!.id];

  String get _userId => _client.auth.currentUser!.id;

  /// Fetch all clients for the target users.
  Future<List<ClientModel>> getClients({int limit = 3000, int offset = 0}) async {
    final response = await _client
        .from('client')
        .select('*, user:user_id(name)')
        .inFilter('user_id', _targetUserIds)
        .order('full_name', ascending: true)
        .range(offset, offset + limit - 1);

    return (response as List).map((e) => ClientModel.fromJson(e)).toList();
  }

  /// Get a single client by ID.
  Future<ClientModel?> getClient(String clientId) async {
    final response = await _client
        .from('client')
        .select()
        .eq('id', clientId)
        .inFilter('user_id', _targetUserIds)
        .maybeSingle();

    if (response == null) return null;
    return ClientModel.fromJson(response);
  }

  /// Search clients by name, policy number, or phone.
  Future<List<ClientModel>> searchClients(String query) async {
    final response = await _client
        .from('client')
        .select('*, user:user_id(name)')
        .inFilter('user_id', _targetUserIds)
        .or('full_name.ilike.%$query%,Policy_Number.ilike.%$query%,mobile_number.ilike.%$query%')
        .order('full_name', ascending: true)
        .limit(50);

    return (response as List).map((e) => ClientModel.fromJson(e)).toList();
  }

  /// Add a new client.
  Future<ClientModel> addClient(Map<String, dynamic> data) async {
    // If user_id is already in data (passed from UI), use it. Otherwise use current user.
    if (data['user_id'] == null) {
      data['user_id'] = _userId;
    }

    final response =
        await _client.from('client').insert(data).select().single();

    return ClientModel.fromJson(response);
  }

  /// Update an existing client.
  Future<void> updateClient(String clientId, Map<String, dynamic> data) async {
    await _client
        .from('client')
        .update(data)
        .eq('id', clientId)
        .inFilter('user_id', _targetUserIds);
  }

  /// Delete a client.
  Future<void> deleteClient(String clientId) async {
    await _client
        .from('client')
        .delete()
        .eq('id', clientId)
        .inFilter('user_id', _targetUserIds);
  }

  /// Fetch clients with expiring policies.
  Future<List<ClientModel>> getExpiringPolicies() async {
    final response = await _client
        .from('client')
        .select()
        .inFilter('user_id', _targetUserIds)
        .not('policy_end_date', 'is', null)
        .order('policy_end_date', ascending: true);

    return (response as List).map((e) => ClientModel.fromJson(e)).toList();
  }
}
