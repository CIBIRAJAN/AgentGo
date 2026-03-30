import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AgentDetails {
  final String id;
  final String name;
  final String agentCode;

  AgentDetails(this.id, this.name, this.agentCode);

  factory AgentDetails.fromJson(Map<String, dynamic> json) {
    return AgentDetails(
      json['id'] as String,
      json['name'] as String,
      json['agent_code'] as String? ?? 'N/A',
    );
  }
}

class AgentState {
  final List<AgentDetails> availableAgents;
  final AgentDetails? selectedAgent; // if null, ALL
  final bool isLoading;

  AgentState({
    required this.availableAgents,
    this.selectedAgent,
    this.isLoading = false,
  });

  /// Returns the IDs of users to filter by based on selection.
  List<String> get targetUserIds {
    if (selectedAgent != null) {
      return [selectedAgent!.id];
    }
    // If null, it means 'All Managed Agents' is selected.
    final ids = availableAgents.map((a) => a.id).toList();
    if (ids.isEmpty) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) return [user.id];
    }
    return ids;
  }

  String? get selectedAgentId => selectedAgent?.id;

  AgentState copyWith({
    List<AgentDetails>? availableAgents,
    AgentDetails? selectedAgent,
    bool? isLoading,
    bool clearSelected = false,
  }) {
    return AgentState(
      availableAgents: availableAgents ?? this.availableAgents,
      selectedAgent: clearSelected ? null : (selectedAgent ?? this.selectedAgent),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AgentNotifier extends Notifier<AgentState> {
  @override
  AgentState build() {
    // Initiate loading immediately
    Future.microtask(() => loadAgents());
    return AgentState(availableAgents: [], isLoading: true);
  }

  Future<void> loadAgents() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      state = state.copyWith(isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true);

    try {
      final res = await client.rpc('get_managed_agents_details', params: {
        'manager_uid': user.id
      });
      
      final list = (res as List).map((e) => AgentDetails.fromJson(e)).toList();
      
      // If no agent is selected, default to the first one (which is the current user)
      AgentDetails? newSelected = state.selectedAgent;
      if (newSelected == null && list.isNotEmpty) {
        newSelected = list.first;
      }
      
      state = state.copyWith(availableAgents: list, selectedAgent: newSelected, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  void selectAgent(AgentDetails? agent) {
    state = state.copyWith(selectedAgent: agent, clearSelected: agent == null);
  }

  void reset() {
    state = state.copyWith(selectedAgent: null, clearSelected: true);
  }
  
  void refresh() async {
    await loadAgents();
  }
}

final agentProvider = NotifierProvider<AgentNotifier, AgentState>(AgentNotifier.new);
