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

class ExpiringPoliciesScreen extends ConsumerStatefulWidget {
  const ExpiringPoliciesScreen({super.key});

  @override
  ConsumerState<ExpiringPoliciesScreen> createState() => _ExpiringPoliciesScreenState();
}

class _ExpiringPoliciesScreenState extends ConsumerState<ExpiringPoliciesScreen> {
  late final ClientService _clientService;
  List<ClientModel> _allExpiring = [];
  List<ClientModel> _filtered = [];
  bool _isLoading = true;
  String _filter = 'Month'; // Day, Week, Month, Year

  @override
  void initState() {
    super.initState();
    _clientService = ClientService(Supabase.instance.client);
    _loadExpiring();
  }

  Future<void> _loadExpiring() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final targetUserIds = ref.read(agentProvider).targetUserIds;
      final data = await ClientService(Supabase.instance.client, targetUserIds: targetUserIds).getExpiringPolicies();
      if (mounted) {
        setState(() {
          _allExpiring = data;
          _applyFilter(_filter);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilter(String filter) {
    _filter = filter;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    DateTime endDate;
    if (filter == 'Day') {
      endDate = today.add(const Duration(days: 1));
    } else if (filter == 'Week') {
      endDate = today.add(const Duration(days: 7));
    } else if (filter == 'Month') {
      endDate = DateTime(today.year, today.month + 1, today.day);
    } else {
      endDate = today.add(const Duration(days: 365));
    }

    _filtered = _allExpiring.where((c) {
      if (c.policyEndDate == null) return false;
      final d = c.policyEndDate!;
      return d.isBefore(endDate) || d.isAtSameMomentAs(endDate);
    }).toList();
  }

  void _openClientDetail(ClientModel client) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientDetailScreen(client: client),
      ),
    ).then((_) => _loadExpiring());
  }

  @override
  Widget build(BuildContext context) {
    // Listen for agent changes
    ref.listen(agentProvider, (previous, next) {
      if (previous?.selectedAgentId != next.selectedAgentId) {
        _loadExpiring();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expiring Policies'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: ['Day', 'Week', 'Month', 'Year'].map((f) {
                final isSelected = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _applyFilter(f));
                    },
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.event_available_rounded,
                        title: 'No expirations',
                        subtitle: 'No policies expiring within this $_filter.',
                      )
                    : RefreshIndicator(
                        onRefresh: _loadExpiring,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final client = _filtered[index];
                            return ClientCard(
                              client: client,
                              onTap: () => _openClientDetail(client),
                              onCall: client.mobileNumber != null
                                  ? () => UrlLauncherHelper.makeCall(client.fullPhoneNumber)
                                  : null,
                              onWhatsApp: client.mobileNumber != null
                                  ? () => UrlLauncherHelper.openWhatsApp(phoneNumber: client.fullPhoneNumber)
                                  : null,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
