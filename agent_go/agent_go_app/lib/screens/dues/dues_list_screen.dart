import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme/app_colors.dart';
import '../../models/monthly_due_model.dart';
import '../../models/aggregated_due_model.dart';
import '../../services/due_service.dart';
import '../../services/reminder_service.dart';
import '../../services/auto_call_service.dart';
import '../../components/dues/due_card.dart';
import '../../components/dues/aggregated_due_card.dart';
import '../../components/dues/due_detail_sheet.dart';
import '../../components/common/empty_state.dart';
import '../../utils/formatters.dart';
import '../../utils/url_launcher_helper.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../providers/agent_provider.dart';
import '../../providers/user_provider.dart';
import '../../components/common/agent_switcher.dart';
import '../../components/common/upgrade_dialog.dart';

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
  List<AggregatedDueModel> _aggregatedDues = [];
  List<dynamic> _filteredDues = [];
  List<String> _months = [];
  bool _isLoading = true;
  String? _selectedMonth;
  String? _selectedStatus;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final _scrollController = ScrollController();
  bool _showScrollToTop = false;

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
    _scrollController.addListener(() {
      if (_scrollController.offset > 400 && !_showScrollToTop) {
        setState(() => _showScrollToTop = true);
      } else if (_scrollController.offset <= 400 && _showScrollToTop) {
        setState(() => _showScrollToTop = false);
      }
    });

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
    _scrollController.dispose();
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
      if (_selectedStatus == 'overdue' || _selectedStatus == 'lapsed') {
        int min = _selectedStatus == 'lapsed' ? 6 : 2;
        final dues = await _dueService.getAggregatedDues(minMonths: min);
        if (mounted) {
          setState(() {
            _aggregatedDues = dues;
            _allDues = [];
            _applySearch();
          });
        }
      } else {
        final dues = await _dueService.getDues(
          dueMonth: _selectedMonth,
          status: _selectedStatus,
        );
        if (mounted) {
          setState(() {
            _allDues = dues;
            _aggregatedDues = [];
            _applySearch();
          });
        }
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
      _filteredDues = _selectedStatus == 'overdue' || _selectedStatus == 'lapsed' ? _aggregatedDues : _allDues;
    } else {
      final q = _searchQuery.toLowerCase();
      if (_selectedStatus == 'overdue' || _selectedStatus == 'lapsed') {
        _filteredDues = _aggregatedDues.where((due) => due.displayName.toLowerCase().contains(q) || due.policyNumber.toLowerCase().contains(q)).toList();
      } else {
        _filteredDues = _allDues.where((due) {
          return due.displayName.toLowerCase().contains(q) ||
              due.policyNumber.toLowerCase().contains(q);
        }).toList();
      }
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
    if (ref.read(userProvider.notifier).isBasePlan) {
      UpgradeDialog.show(
        context: context,
        title: 'Upgrade Plan',
        message: 'WhatsApp reminders are disabled on the Base plan. Upgrade to the Mid plan to unlock automated messaging.',
      );
      return;
    }

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
    if (ref.read(userProvider.notifier).isBasePlan) {
      UpgradeDialog.show(
        context: context,
        title: 'Upgrade Plan',
        message: 'Email reminders are disabled on the Base plan. Upgrade to the Mid plan to unlock email communication.',
      );
      return;
    }

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
    final userNotif = ref.read(userProvider.notifier);
    
    if (userNotif.isBasePlan) {
      UpgradeDialog.show(
        context: context,
        title: 'Premium Feature',
        message: 'AI Voice calling is disabled on the Base plan. Upgrade to Mid or Premium to unlock.',
      );
      return;
    }

    final userModel = ref.read(userProvider).value;
    if (userNotif.isMidPlan && userModel != null) {
      if (userModel.freeCallsUsedThisMonth >= 10) {
        UpgradeDialog.show(
          context: context,
          title: 'Upgrade Required',
          message: 'You have used all 10 free AI voice calls for this month. Upgrade to the Premium Plan for unlimited calls!',
        );
        return;
      }
    }

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
        dueMonth: Formatters.dueMonth(due.dueMonth),
        clientId: due.clientId,
        dueId: due.id,
      );

      if (mounted) {
        if (success) {
          if ((userNotif.isMidPlan || userNotif.isPremiumPlan) && userModel != null) {
             try {
               await Supabase.instance.client.rpc('log_auto_call_usage', params: {'uid': userModel.id});
               ref.read(userProvider.notifier).refresh(); // reload to get new limits
             } catch (_) {}
          }
          
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
    final pendingItems = _filteredDues.where((d) {
      if (d is MonthlyDueModel) return !d.isPaid && d.clientPhone != null;
      if (d is AggregatedDueModel) return d.mobileNumber != null;
      return false;
    }).toList();

    if (pendingItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No pending dues with phone numbers available.'), backgroundColor: AppColors.warning));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Initiate Bulk AI Calls'),
        content: Text('Are you sure you want to let the AI Voice Assistant automatically call all ${pendingItems.length} clients?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary), child: const Text('Start Calling')),
        ],
      ),
    );

    if (confirmed == true) {
      int successCount = 0;
      for (final item in pendingItems) {
        bool success = false;
        if (item is MonthlyDueModel) {
          success = await AutoCallService.triggerAutoCall(
            clientName: item.displayName,
            phoneNumber: '${item.clientPhoneCc ?? '+91'}${item.clientPhone}',
            policyNumber: item.policyNumber,
            amountDue: item.totalPremium,
            dueMonth: Formatters.dueMonth(item.dueMonth),
            clientId: item.clientId,
            dueId: item.id,
          );
        } else if (item is AggregatedDueModel) {
          success = await AutoCallService.triggerAutoCall(
            clientName: item.displayName,
            phoneNumber: '${item.mobileNumberCc ?? '+91'}${item.mobileNumber}',
            policyNumber: item.policyNumber,
            amountDue: item.totalPremium,
            dueMonth: item.unpaidMonthsList,
            clientId: item.clientId,
            isOverdue: true,
            overdueMonths: item.unpaidMonthsCount,
          );
        }

        if (success) successCount++;
        await Future.delayed(const Duration(milliseconds: 500));
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully triggered $successCount AI calls!'), backgroundColor: AppColors.success));
    }
  }

  // ── Auto Call Aggregated Client ──
  Future<void> _autoCallAggregated(AggregatedDueModel due) async {
    final userNotif = ref.read(userProvider.notifier);
    if (userNotif.isBasePlan) {
      UpgradeDialog.show(context: context, title: 'Premium Feature', message: 'AI Voice calling is disabled on the Base plan.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Initiate Overdue Auto Call'),
        content: Text('Call ${due.displayName} for their total overdue of Rs. ${due.totalPremium} (${due.unpaidMonthsCount} months)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            child: const Text('Auto Call'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final cc = due.mobileNumberCc ?? '+91';
      final success = await AutoCallService.triggerAutoCall(
        clientName: due.displayName,
        phoneNumber: '$cc${due.mobileNumber}',
        policyNumber: due.policyNumber,
        amountDue: due.totalPremium,
        dueMonth: due.unpaidMonthsList,
        clientId: due.clientId,
        isOverdue: true,
        overdueMonths: due.unpaidMonthsCount,
      );

      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI Overdue Call initiated!'), backgroundColor: AppColors.success));
      }
    }
  }

  // ── Mark Aggregated as Paid ──
  Future<void> _markAggregatedAsPaid(AggregatedDueModel due) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark All as Paid'),
        content: Text('Mark all ${due.unpaidMonthsCount} months for policy ${due.policyNumber} as paid?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // We'll need a new RPC or just loop through. For now, we'll mark the specific policy's pending dues.
        await Supabase.instance.client.from('monthly_dues').update({'status': 'paid', 'payment_date': DateTime.now().toIso8601String()})
          .eq('policy_number', due.policyNumber).neq('status', 'paid');
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All pending dues marked as paid!'), backgroundColor: AppColors.success));
           _loadDues();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadDues,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
            child: Column(
              children: [
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

                const SizedBox(height: 8),

                // Month selector
                if (_months.isNotEmpty)
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            selectedColor: AppColors.secondary,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
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
                          selectedColor: AppColors.secondary.withOpacity(0.1),
                          checkmarkColor: AppColors.secondary,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.secondary : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // Bulk Send button
                if (_filteredDues.any((d) {
                  if (d is MonthlyDueModel) return !d.isPaid;
                  if (d is AggregatedDueModel) return !d.isPaid;
                  return false;
                }))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ElevatedButton.icon(
                      onPressed: _autoCallAll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.smart_toy_rounded, size: 20),
                      label: const Text(
                        'Send AI Reminder Calls to All',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                  ),

                // Dues count + total
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        '${_filteredDues.length} dues',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      if (_filteredDues.isNotEmpty)
                        Text(
                          'Total: ${Formatters.currency(_filteredDues.fold(0.0, (sum, d) {
                            if (d is MonthlyDueModel) return sum + d.totalPremium;
                            if (d is AggregatedDueModel) return sum + d.totalPremium;
                            return sum;
                          }))}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.secondary,
                              ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
          
          // Dues list
          if (_isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filteredDues.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.receipt_long_rounded,
                title: _searchQuery.isNotEmpty ? 'No results for "$_searchQuery"' : 'No dues found',
                subtitle: _searchQuery.isNotEmpty
                    ? 'Try searching by policy number or name'
                    : 'Upload a due-list PDF to see dues here',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _filteredDues[index];
                    
                    if (item is AggregatedDueModel) {
                      return AggregatedDueCard(
                        due: item,
                        onCall: () => UrlLauncherHelper.makeCall('${item.mobileNumberCc ?? '+91'}${item.mobileNumber}'),
                        onWhatsApp: () {
                          final msg = 'Dear ${item.displayName}, This is a reminder that your policy ${item.policyNumber} is in OVERDUE for ${item.unpaidMonthsCount} months (${item.unpaidMonthsList}). Total due: Rs. ${Formatters.currency(item.totalPremium)}. Please pay as soon as possible.';
                          UrlLauncherHelper.openWhatsApp(phoneNumber: '${item.mobileNumberCc ?? '+91'}${item.mobileNumber ?? ''}', message: msg);
                        },
                        onEmail: item.email != null && item.email!.isNotEmpty ? () => UrlLauncherHelper.sendEmail(item.email!, subject: 'Overdue Reminder - ${item.policyNumber}', body: 'Dear ${item.displayName}, your policy ${item.policyNumber} is in overdue.') : null,
                        onAutoCall: () => _autoCallAggregated(item),
                        onMarkPaid: () => _markAggregatedAsPaid(item),
                      );
                    }

                    final due = item as MonthlyDueModel;
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
                  childCount: _filteredDues.length,
                ),
              ),
            ),
        ],
      ),
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
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.arrow_upward_rounded),
            )
          : null,
    );
  }
}
