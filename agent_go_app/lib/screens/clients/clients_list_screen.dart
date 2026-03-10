import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme/app_colors.dart';
import '../../models/client_model.dart';
import '../../services/client_service.dart';
import '../../components/client/client_card.dart';
import '../../components/common/empty_state.dart';
import '../../utils/url_launcher_helper.dart';
import 'client_detail_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/agent_provider.dart';
import '../../components/common/agent_switcher.dart';
import 'package:easy_localization/easy_localization.dart';

/// Screen listing all clients with search and add functionality.
class ClientsListScreen extends ConsumerStatefulWidget {
  const ClientsListScreen({super.key});

  @override
  ConsumerState<ClientsListScreen> createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends ConsumerState<ClientsListScreen> {
  late ClientService _clientService;
  List<ClientModel> _clients = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    // Initialize with current agent context
    final targetUserIds = ref.read(agentProvider).targetUserIds;
    _clientService = ClientService(Supabase.instance.client, targetUserIds: targetUserIds);
    _loadClients();
    _scrollController.addListener(() {
      if (_scrollController.offset > 400 && !_showScrollToTop) {
        setState(() => _showScrollToTop = true);
      } else if (_scrollController.offset <= 400 && _showScrollToTop) {
        setState(() => _showScrollToTop = false);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    setState(() => _isLoading = true);
    try {
      List<ClientModel> clients;
      if (_searchQuery.isNotEmpty) {
        clients = await _clientService.searchClients(_searchQuery);
      } else {
        clients = await _clientService.getClients();
      }
      if (mounted) setState(() => _clients = clients);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearch(String query) {
    _searchQuery = query;
    _loadClients();
  }

  void _openClientDetail(ClientModel client) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientDetailScreen(client: client),
      ),
    ).then((_) => _loadClients());
  }

  void _addClient() async {
    final agentState = ref.read(agentProvider);
    String? ownerId;
    
    // If specific agent selected, use it
    if (agentState.selectedAgent != null) {
      ownerId = agentState.selectedAgent!.id;
    } 
    // If "All" is selected but they manage others, ask which one
    else if (agentState.availableAgents.length > 1) {
      final selected = await _showAgentPicker(agentState.availableAgents);
      if (selected == null) return;
      ownerId = selected.id;
    }

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientDetailScreen(client: null, ownerId: ownerId),
      ),
    ).then((_) => _loadClients());
  }

  Future<AgentDetails?> _showAgentPicker(List<AgentDetails> agents) async {
    return showDialog<AgentDetails>(
      context: context,
      builder: (ctx) => AlertDialog(
      title: Text('select_owner_agent'.tr()),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: agents.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (ctx, index) {
              final agent = agents[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    agent.name.characters.first,
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ),
                title: Text(agent.name),
                subtitle: Text('Code: ${agent.agentCode}'),
                onTap: () => Navigator.pop(ctx, agent),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for agent changes to refresh list
    ref.listen<AgentState>(agentProvider, (previous, next) {
      if (previous?.targetUserIds != next.targetUserIds) {
        _clientService = ClientService(Supabase.instance.client, targetUserIds: next.targetUserIds);
        _loadClients();
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Agent Switcher and Search
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(
              children: [
                const AgentSwitcher(isLight: true),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'search'.tr() + '...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchCtrl.clear();
                              _onSearch('');
                            },
                          )
                        : null,
                  ),
                  onChanged: _onSearch,
                ),
              ],
            ),
          ),

        // Client count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              Text(
                '${_clients.length} clients',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addClient,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Client'),
              ),
            ],
          ),
        ),

        // Client list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _clients.isEmpty
                  ? EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: _searchQuery.isNotEmpty
                          ? 'No clients found'
                          : 'No clients yet',
                      subtitle: _searchQuery.isNotEmpty
                          ? 'Try a different search term'
                          : 'Add your first client to get started',
                      actionLabel:
                          _searchQuery.isEmpty ? 'Add Client' : null,
                      onAction: _searchQuery.isEmpty ? _addClient : null,
                    )
                  : RefreshIndicator(
                      onRefresh: _loadClients,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _clients.length,
                        itemBuilder: (context, index) {
                          final client = _clients[index];
                          return ClientCard(
                            client: client,
                            onTap: () => _openClientDetail(client),
                            onCall: client.mobileNumber != null
                                ? () => UrlLauncherHelper.makeCall(
                                    client.fullPhoneNumber)
                                : null,
                            onWhatsApp: client.mobileNumber != null
                                ? () => UrlLauncherHelper.openWhatsApp(
                                    phoneNumber: client.fullPhoneNumber)
                                : null,
                          );
                        },
                      ),
                    ),
        ),
      ],
    ),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton.small(
              onPressed: () {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              },
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.arrow_upward_rounded),
            )
          : null,
    );
  }
}
