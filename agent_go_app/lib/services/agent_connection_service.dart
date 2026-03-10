import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/agent_connection_model.dart';
import '../models/user_model.dart';

class AgentConnectionService {
  final SupabaseClient _client;

  AgentConnectionService(this._client);
  String get _userId => _client.auth.currentUser!.id;

  /// Send connection request to an agent code
  Future<void> sendRequest(String agentCode) async {
    final res = await _client.rpc('send_connection_request', params: {
      'target_agent_code': agentCode
    });
    return res;
  }

  /// Respond to a request
  Future<void> respondRequest(String connectionId, String status) async {
    await _client.rpc('respond_connection_request', params: {
      'connection_id': connectionId,
      'response_status': status
    });
  }

  /// Get pending requests for current user (where someone else wants to manage this user)
  Future<List<AgentConnectionModel>> getPendingRequests() async {
    final response = await _client
        .from('agent_connections')
        .select('*, manager:manager_id(name)')
        .eq('owner_id', _userId)
        .eq('status', 'pending');
        
    return (response as List).map((e) => AgentConnectionModel.fromJson(e)).toList();
  }

  /// Get active connections where they are managed BY me.
  Future<List<AgentConnectionModel>> getMyConnections() async {
    final response = await _client
        .from('agent_connections')
        .select('*, owner:owner_id(name, agent_code)')
        .eq('manager_id', _userId)
        .eq('status', 'accepted');
        
    return (response as List).map((e) => AgentConnectionModel.fromJson(e)).toList();
  }

  /// Get active connections where I am managed BY someone.
  Future<List<AgentConnectionModel>> getManagers() async {
    final response = await _client
        .from('agent_connections')
        .select('*, manager:manager_id(name)')
        .eq('owner_id', _userId)
        .eq('status', 'accepted');
        
    return (response as List).map((e) => AgentConnectionModel.fromJson(e)).toList();
  }

  /// Delete connection
  Future<void> removeConnection(String connectionId) async {
    await _client.from('agent_connections').delete().eq('id', connectionId);
  }

  /// Gets all user IDs this agent manages (including themselves)
  Future<List<String>> getManagedUserIds() async {
    try {
      final res = await _client.rpc('get_managed_users', params: {
        'agent_id': _userId
      });
      return List<String>.from(res);
    } catch (e) {
      return [_userId];
    }
  }

  /// Gets the agent code of current user
  Future<String?> getMyAgentCode() async {
    final res = await _client.from('user').select('agent_code').eq('id', _userId).maybeSingle();
    return res?['agent_code'] as String?;
  }
}
