import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme/app_colors.dart';
import '../../models/monthly_due_model.dart';
import '../../services/due_service.dart';
import '../../services/reminder_service.dart';
import '../../services/auto_call_service.dart';
import '../../components/dues/due_card.dart';
import '../../components/dues/due_detail_sheet.dart';
import '../../components/common/empty_state.dart';
import '../../utils/formatters.dart';
import '../../utils/url_launcher_helper.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../providers/agent_provider.dart';
import '../../components/common/agent_switcher.dart';

/// Screen displaying monthly dues with search, month/status filters.
class DuesListScreen extends ConsumerStatefulWidget {
  final String? initialStatus;
  const DuesListScreen({super.key, this.initialStatus});

  @override
  ConsumerState<DuesListScreen> createState() => _DuesListScreenState();
}

class _DuesListScreenState extends ConsumerState<DuesListScreen> {
  late DueService _dueService;
  late final ReminderService _reminderService;
  List<MonthlyDueModel> _allDues = [];
  List<MonthlyDueModel> _filteredDues = [];
  List<String> _months = [];
  bool _isLoading = true;
  String? _selectedMonth;
  String? _selectedStatus;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  List<String> get _statusFilterLabels => ['all'.tr(), 'pending'.tr(), 'paid'.tr(), 'overdue'.tr(), 'lapsed'.tr()];
  final _statusFilterValues = ['All', 'Pending', 'Paid', 'Overdue', 'Lapsed'];

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    final targetUserIds = ref.read(agentProvider).targetUserIds;
    _dueService = DueService(client, targetUserIds: targetUserIds);
    _reminderService = ReminderService(client);
    _selectedStatus = widget.initialStatus;
    _loadMonths();
  }

  @override
  void didUpdateWidget(covariant DuesListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialStatus != oldWidget.initialStatus) {
      setState(() {
        _selectedStatus = widget.initialStatus;
      });
      _loadDues();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMonths() async {
    try {
      final months = await _dueService.getAvailableMonths();
      if (mounted) {
        setState(() {
          _months = months;
          _selectedMonth = months.isNotEmpty ? months.first : null;
        });
        _loadDues();
      }
    } catch (e) {
      _loadDues();
    }
  }

  Future<void> _loadDues() async {
    setState(() => _isLoading = true);
    try {
      final dues = await _dueService.getDues(
        dueMonth: _selectedMonth,
        status: _selectedStatus,
      );
      if (mounted) {
        setState(() {
          _allDues = dues;
          _applySearch();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredDues = _allDues;
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredDues = _allDues.where((due) {
        return due.displayName.toLowerCase().contains(q) ||
            due.policyNumber.toLowerCase().contains(q);
      }).toList();
    }
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      _applySearch();
    });
  }

  // ── Mark as paid ──
  Future<void> _markAsPaid(MonthlyDueModel due) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('mark_as_paid'.tr()),
        content: Text(
          'payment_confirm'.tr(args: [Formatters.currency(due.totalPremium), due.policyNumber]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('cancel'.tr())),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('confirm'.tr())),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dueService.markAsPaid(due.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Marked as paid!'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadDues();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: $e'),
                backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  // ── Call client (with options) ──
  void _callClient(MonthlyDueModel due) {
    final phone = due.clientPhone ?? '';
    final cc = due.clientPhoneCc ?? '+91';
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('No phone number available. Add it in Clients tab.')),
      );
      return;
    }

    UrlLauncherHelper.makeCall('$cc$phone');
    _reminderService.logReminder(
      reminderType: 'call',
      dueId: due.id,
      clientId: due.clientId,
      policyNumber: due.policyNumber,
      callType: 'manual',
    );
  }

  // ── WhatsApp client ──
  void _whatsAppClient(MonthlyDueModel due) {
    final phone = due.clientPhone ?? '';
    final cc = due.clientPhoneCc ?? '+91';
    if (phone.isNotEmpty) {
      final message = UrlLauncherHelper.premiumReminderMessage(
        clientName: due.displayName,
        policyNumber: due.policyNumber,
        amount: Formatters.currency(due.totalPremium),
        dueMonth: Formatters.dueMonth(due.dueMonth),
      );

      UrlLauncherHelper.openWhatsApp(
        phoneNumber: '$cc$phone',
        message: message,
      );

      _reminderService.logReminder(
        reminderType: 'whatsapp',
        dueId: due.id,
        clientId: due.clientId,
        policyNumber: due.policyNumber,
        messageContent: message,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('No phone number available. Add it in Clients tab.')),
      );
    }
  }

  // ── Email client ──
  void _emailClient(MonthlyDueModel due) {
    if (due.clientEmail != null) {
      UrlLauncherHelper.sendEmail(
        due.clientEmail!,
        subject: 'Premium Reminder - ${due.policyNumber}',
        body: 'Dear ${due.displayName},\n\nThis is a reminder regarding the premium due for your policy ${due.policyNumber} for ${Formatters.dueMonth(due.dueMonth)}. The amount is ${Formatters.currency(due.totalPremium)}.\n\nPlease ignore if already paid.\n\nRegards,\nAgent',
      );
    }
  }

  // ── Auto Call Client (AI) ──
  Future<void> _autoCallClient(MonthlyDueModel due) async {
    final phone = due.clientPhone ?? '';
    final cc = due.clientPhoneCc ?? '+91';
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('No phone number available. Add it in Clients tab.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Initiate Auto Call'),
        content: Text(
          'Do you want the AI Voice Assistant to call ${due.displayName} and remind them of their Rs. ${due.totalPremium} due?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
              child: const Text('Auto Call')),
        ],
      ),
    );

    if (confirmed == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Triggering AI over n8n...'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
      
      final success = await AutoCallService.triggerAutoCall(
        clientName: due.displayName,
        phoneNumber: '$cc$phone',
        policyNumber: due.policyNumber,
        amountDue: due.totalPremium,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('AI Call initiated successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          _reminderService.logReminder(
            reminderType: 'call',
            dueId: due.id,
            clientId: due.clientId,
            policyNumber: due.policyNumber,
            callType: 'auto_n8n_vapi',
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to trigger AI. Check n8n webhook URL.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  // ── Auto Call All Pending (Bulk) ──
  Future<void> _autoCallAll() async {
    final pendingDues = _filteredDues.where((d) => !d.isPaid && d.clientPhone != null && d.clientPhone!.isNotEmpty).toList();

    if (pendingDues.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pending dues with phone numbers available.'), backgroundColor: AppColors.warning),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Initiate Bulk AI Calls'),
        content: Text('Are you sure you want to let the AI Voice Assistant automatically call all ${pendingDues.length} clients with pending dues?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
              child: const Text('Start Calling')),
        ],
      ),
    );

    if (confirmed == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Initiating AI calls for ${pendingDues.length} clients...'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
      
      int successCount = 0;
      for (final due in pendingDues) {
        final cc = due.clientPhoneCc ?? '+91';
        final success = await AutoCallService.triggerAutoCall(
          clientName: due.displayName,
          phoneNumber: '$cc${due.clientPhone}',
          policyNumber: due.policyNumber,
          amountDue: due.totalPremium,
        );

        if (success) {
          successCount++;
          _reminderService.logReminder(
            reminderType: 'call',
            dueId: due.id,
            clientId: due.clientId,
            policyNumber: due.policyNumber,
            callType: 'auto_n8n_vapi_bulk',
          );
        }
        // Small delay to prevent rate-limiting on n8n webhook
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully triggered $successCount AI calls!'),
            backgroundColor: successCount > 0 ? AppColors.success : AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for agent changes to refresh list
    ref.listen<AgentState>(agentProvider, (previous, next) {
      if (previous?.targetUserIds != next.targetUserIds) {
        _dueService = DueService(Supabase.instance.client, targetUserIds: next.targetUserIds);
        _loadMonths();
      }
    });

    return Column(
      children: [
        // Agent Switcher
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: AgentSwitcher(isLight: true),
        ),

        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
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
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: _onSearch,
          ),
        ),

        // Month selector
        if (_months.isNotEmpty)
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _months.length,
              itemBuilder: (context, index) {
                final month = _months[index];
                final isSelected = month == _selectedMonth;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(Formatters.dueMonth(month)),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedMonth = month);
                      _loadDues();
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),

        // Status filter
        SizedBox(
          height: 42,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _statusFilterLabels.length,
            itemBuilder: (context, index) {
              final label = _statusFilterLabels[index];
              final filter = _statusFilterValues[index];
              final value = filter == 'All' ? null : filter.toLowerCase();
              final isSelected = value == _selectedStatus;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedStatus = value);
                    _loadDues();
                  },
                  selectedColor: AppColors.primarySurface,
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Dues count + total
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                '${_filteredDues.length} dues',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              if (_filteredDues.isNotEmpty)
                Text(
                  'Total: ${Formatters.currency(_filteredDues.fold(0.0, (sum, d) => sum + d.totalPremium))}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                ),
            ],
          ),
        ),
        
        // Auto Call All Action (Bulk) hidden for now
        /*
        if (_filteredDues.any((d) => !d.isPaid))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _autoCallAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  foregroundColor: const Color(0xFF8B5CF6),
                  elevation: 0,
                  side: const BorderSide(color: Color(0xFF8B5CF6)),
                ),
                icon: const Icon(Icons.smart_toy_rounded),
                label: const Text('Generate Auto Call (All Pending)'),
              ),
            ),
          ),
        */
          
        const SizedBox(height: 8),

        // Dues list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredDues.isEmpty
                  ? EmptyState(
                      icon: _searchQuery.isNotEmpty
                          ? Icons.search_off_rounded
                          : Icons.receipt_long_rounded,
                      title: _searchQuery.isNotEmpty
                          ? 'No results for "$_searchQuery"'
                          : 'No dues found',
                      subtitle: _searchQuery.isNotEmpty
                          ? 'Try searching by policy number or name'
                          : 'Upload a due-list PDF to see dues here',
                    )
                  : RefreshIndicator(
                      onRefresh: _loadDues,
                      child: ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _filteredDues.length,
                        itemBuilder: (context, index) {
                          final due = _filteredDues[index];
                          return DueCard(
                            due: due,
                            onTap: () => DueDetailSheet.show(
                              context,
                              due,
                              onCall: () => _callClient(due),
                              onWhatsApp: () => _whatsAppClient(due),
                              onEmail: () => _emailClient(due),
                              onAutoCall: () => _autoCallClient(due),
                              onMarkPaid: () => _markAsPaid(due),
                            ),
                            onCall: () => _callClient(due),
                            onWhatsApp: () => _whatsAppClient(due),
                            onEmail: () => _emailClient(due),
                            onAutoCall: () => _autoCallClient(due),
                            onMarkPaid: () => _markAsPaid(due),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}
