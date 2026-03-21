import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme/app_colors.dart';
import '../../services/analytics_service.dart';
import '../../services/reminder_service.dart';
import '../../services/agent_connection_service.dart';
import '../../models/agent_connection_model.dart';
import '../../utils/formatters.dart';
import '../../components/dashboard/stat_card.dart';
import '../../components/common/empty_state.dart';
import '../celebrations/celebrations_screen.dart';
import '../celebrations/global_celebrations_screen.dart';
import '../clients/expiring_policies_screen.dart';
import '../../services/client_service.dart';
import '../../services/due_service.dart';
import '../../models/client_model.dart';
import '../home/home_screen.dart';
import '../../main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../providers/agent_provider.dart';
import '../../components/common/agent_switcher.dart';
import '../../providers/notification_provider.dart';
import '../../providers/user_provider.dart';
import '../notifications/notification_screen.dart';
import '../diary/diary_screen.dart';
import '../../components/common/upgrade_dialog.dart';
import '../../config/supabase_config.dart';
import '../../utils/url_launcher_helper.dart';

/// Dashboard screen showing key metrics and recent activity.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late final AnalyticsService _analyticsService;
  late final ReminderService _reminderService;
  late final DueService _dueService;
  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _reminderCounts;
  Map<String, int>? _callStats;
  List<ClientModel> _expiringPolicies = [];
  List<String> _months = [];
  int _expireCount = 0;
  int _todayCelebrationsCount = 0;
  bool _isLoading = true;
  String? _error;
  late String _selectedMonth;
  static final Set<String> _dismissedInvites = {}; // Track dismissed invites in this session

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _analyticsService = AnalyticsService(client);
    _reminderService = ReminderService(client);
    _dueService = DueService(client);
    _selectedMonth = Formatters.currentMonth();
    _loadMonthsAndDashboard();
  }

  Future<void> _loadMonthsAndDashboard() async {
    try {
      final months = await _dueService.getAvailableMonths();
      if (mounted) {
        setState(() {
          _months = months;
          // If current month isn't in available months, pick the most recent available month
          if (_months.isNotEmpty && !_months.contains(_selectedMonth)) {
            _selectedMonth = _months.first;
          }
        });
      }
    } catch (_) {}
    _loadDashboard();
    _checkPendingInvites();
  }

  Future<void> _checkPendingInvites() async {
    try {
      final connService = AgentConnectionService(Supabase.instance.client);
      final requests = await connService.getPendingRequests();
      
      if (requests.isNotEmpty && mounted) {
        final req = requests.first;
        if (_dismissedInvites.contains(req.id)) return;

        _showConnectionPrompt(req);
      }
    } catch (_) {}
  }

  void _showConnectionPrompt(AgentConnectionModel req) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_add_rounded, color: AppColors.warning, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Connection Request',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${req.managerName ?? 'An agent'} wants to manage your clients.',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      _dismissedInvites.add(req.id);
                      Navigator.pop(ctx);
                      try {
                        await AgentConnectionService(Supabase.instance.client).respondRequest(req.id, 'declined');
                      } catch (_) {}
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppColors.error),
                      foregroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('decline'.tr()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      _dismissedInvites.add(req.id);
                      Navigator.pop(ctx);
                      try {
                        await AgentConnectionService(Supabase.instance.client).respondRequest(req.id, 'accepted');
                        ref.read(agentProvider.notifier).refresh();
                      } catch (_) {}
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('accept'.tr()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () {
                  _dismissedInvites.add(req.id);
                  Navigator.pop(ctx);
                },
                child: Text('decide_later'.tr(), style: const TextStyle(color: AppColors.textTertiary)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final agentState = ref.read(agentProvider);
      final targetUserIds = agentState.targetUserIds;
      
      // Load everything in parallel
      final results = await Future.wait<dynamic>([
        AnalyticsService(Supabase.instance.client, targetUserIds: targetUserIds).getDashboardSummary(_selectedMonth),
        ReminderService(Supabase.instance.client, targetUserIds: targetUserIds).getReminderCounts(dueMonth: _selectedMonth),
        ClientService(Supabase.instance.client, targetUserIds: targetUserIds).getExpiringPolicies(),
        ClientService(Supabase.instance.client, targetUserIds: targetUserIds).getTodayCelebrationsCount(),
        AnalyticsService(Supabase.instance.client, targetUserIds: targetUserIds).getCallStats(),
      ]);
      if (mounted) {
        setState(() {
          _summary = results[0] as Map<String, dynamic>;
          _reminderCounts = results[1] as Map<String, dynamic>;
          _expiringPolicies = results[2] as List<ClientModel>;
          _todayCelebrationsCount = results[3] as int;
          _callStats = results[4] as Map<String, int>;
          
          final now = DateTime.now();
          final next90Days = now.add(const Duration(days: 90));
          _expireCount = _expiringPolicies.where((c) {
              if (c.policyEndDate == null) return false;
              return c.policyEndDate!.isBefore(next90Days);
          }).length;

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showCallDetails(bool successful) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  successful ? 'Responded Call Logs' : 'Failed Call Logs',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _analyticsService.getCallLogDetails(successful),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError ||
                        !snapshot.hasData ||
                        snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text(
                          'No call logs found.',
                          style: TextStyle(color: AppColors.textTertiary),
                        ),
                      );
                    }
                    final logs = snapshot.data!;
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        final clientName =
                            log['client']?['full_name'] ?? 'Unknown Client';
                        final date = DateTime.parse(log['created_at']).toLocal();
                        final reason = log['error_reason'] ?? 'No answer/Busy';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: (successful
                                    ? AppColors.success
                                    : AppColors.error)
                                .withValues(alpha: 0.1),
                            child: Icon(
                                successful
                                    ? Icons.phone_in_talk_rounded
                                    : Icons.phone_missed_rounded,
                                color: successful
                                    ? AppColors.success
                                    : AppColors.error,
                                size: 20),
                          ),
                          title: Text(clientName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(Formatters.dateTime(date)),
                              if (!successful)
                                Text('Reason: $reason',
                                    style: const TextStyle(
                                        color: AppColors.error, fontSize: 11)),
                            ],
                          ),
                          trailing: successful
                              ? const Text('Answered',
                                  style: TextStyle(
                                      color: AppColors.success, fontSize: 11))
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isBlocked() {
    final user = ref.read(userProvider).value;
    if (user != null && user.isWalletBlocked) {
      UpgradeDialog.show(
        context: context,
        title: 'Wallet Blocked',
        message: 'Your Premium Wallet payments failed. Please clear your negative balance to unlock app features.',
      );
      return true;
    }
    return false;
  }

  void _openCelebrations() {
    if (_isBlocked()) return;

    if (ref.read(userProvider.notifier).isBasePlan) {
      UpgradeDialog.show(
        context: context,
        title: 'Premium Feature',
        message: 'Viewing and managing celebrations requires a Mid or Premium plan.',
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CelebrationsScreen(),
      ),
    );
  }

  void _openExpiringPolicies() {
    if (_isBlocked()) return;

    if (ref.read(userProvider.notifier).isBasePlan) {
      UpgradeDialog.show(
        context: context,
        title: 'Premium Feature',
        message: 'Viewing expiring policies requires a Mid or Premium plan.',
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ExpiringPoliciesScreen(),
      ),
    );
  }

  void _openGlobalCelebrations() {
    if (_isBlocked()) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const GlobalCelebrationsScreen(),
      ),
    );
  }

  void _openAgentDiary() {
    if (_isBlocked()) return;

    if (ref.read(userProvider.notifier).isBasePlan) {
      UpgradeDialog.show(
        context: context,
        title: 'Premium Feature',
        message: 'Agent Diary requires a Mid or Premium plan.',
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DiaryScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for agent changes to reload data
    ref.listen(agentProvider, (previous, next) {
      if (previous?.selectedAgentId != next.selectedAgentId || 
          previous?.availableAgents.length != next.availableAgents.length) {
        _loadDashboard();
      }
    });

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: AppColors.primary,
      child: CustomScrollView(
        slivers: [
          // Hero header
          SliverToBoxAdapter(
            child: _buildHeader(context),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverToBoxAdapter(
              child: GestureDetector(
                onTap: _openAgentDiary,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.book_rounded, color: AppColors.primary, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'agent_diary'.tr(),
                              style: const TextStyle(
                                fontSize: 18, 
                                fontWeight: FontWeight.w800, 
                                color: AppColors.textPrimary
                              ),
                            ),
                            Text(
                              'track_visits_hint'.tr(),
                              style: const TextStyle(
                                fontSize: 13, 
                                color: AppColors.textSecondary
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Stats grid
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: _isLoading
                ? const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  )
                : _error != null
                    ? SliverToBoxAdapter(
                        child: EmptyState(
                          icon: Icons.error_outline_rounded,
                          title: 'Could not load dashboard',
                          subtitle: _error,
                          actionLabel: 'Retry',
                          onAction: _loadDashboard,
                        ),
                      )
                    : _buildStatsGrid(),
          ),

          // Recent uploads
          if (_summary != null)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _buildRecentUploads(context),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final name = user?.userMetadata?['full_name'] ??
        user?.email?.split('@').first ??
        'Agent';
    final screenW = MediaQuery.of(context).size.width;
    final isSmall = screenW < 360;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, isSmall ? 16 : 24),
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'hello'.tr(args: [name]),
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontSize: isSmall ? 18 : null,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () {
                          if (_months.isEmpty) return;
                          showModalBottomSheet(
                            context: context,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                            ),
                            builder: (ctx) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                     child: Text(
                                      'select_dashboard_month'.tr(),
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  Flexible(
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: _months.length,
                                      itemBuilder: (context, index) {
                                        final m = _months[index];
                                        return ListTile(
                                          title: Text(Formatters.dueMonth(m)),
                                          selected: m == _selectedMonth,
                                          selectedColor: AppColors.primary,
                                          trailing: m == _selectedMonth ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                                          onTap: () {
                                            Navigator.pop(ctx);
                                            setState(() => _selectedMonth = m);
                                            _loadDashboard();
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              Formatters.dueMonth(_selectedMonth),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.white70),
                            ),
                            if (_months.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.expand_more_rounded,
                                  size: 16, color: Colors.white70),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const AgentSwitcher(), // Added Agent Switcher
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_rounded, color: Colors.white),
                        ref.watch(unreadNotifCountProvider).when(
                              data: (count) => count > 0 
                                  ? Positioned(
                                      right: -4,
                                      top: -4,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: AppColors.error,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '$count',
                                          style: const TextStyle(color: Colors.white, fontSize: 8),
                                        ),
                                      ),
                                    ) 
                                  : const SizedBox.shrink(),
                              loading: () => const SizedBox.shrink(),
                              error: (_, __) => const SizedBox.shrink(),
                            ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Quick summary bar
            if (_summary != null)
              Container(
                padding: EdgeInsets.all(isSmall ? 6 : 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _QuickStat(
                      label: 'pending'.tr(),
                      value: Formatters.currency(
                        (_summary?['total_premium_pending'] as num?)
                                ?.toDouble() ??
                            0,
                      ),
                      color: AppColors.warningLight,
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: Colors.white24,
                    ),
                    _QuickStat(
                      label: 'collected'.tr(),
                      value: Formatters.currency(
                        (_summary?['total_premium_collected'] as num?)
                                ?.toDouble() ??
                            0,
                      ),
                      color: AppColors.successLight,
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: Colors.white24,
                    ),
                    _QuickStat(
                      label: 'commission'.tr(),
                      value: Formatters.currency(
                        (_summary?['commission_earned'] as num?)?.toDouble() ??
                            0,
                      ),
                      color: AppColors.secondaryLight,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final whatsappSent = _reminderCounts?['whatsapp_sent'] ?? 0;

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('business_overview'.tr(), Icons.assessment_outlined),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'total_clients'.tr(),
                  value: '${_summary?['total_clients'] ?? 0}',
                  icon: Icons.people_outline_rounded,
                  color: AppColors.primary,
                  onTap: () => HomeScreen.of(context)?.setTab(1),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: StatCard(
                  label: 'total_dues'.tr(),
                  value: '${_summary?['total_dues'] ?? 0}',
                  icon: Icons.receipt_outlined,
                  color: AppColors.info,
                  onTap: () => HomeScreen.of(context)?.setTab(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'paid'.tr(),
                  value: '${_summary?['paid_dues'] ?? 0}',
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.success,
                  onTap: () => HomeScreen.of(context)?.setTab(2, dueStatus: 'paid'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  label: 'pending_dues'.tr(),
                  value: '${_summary?['pending_dues'] ?? 0}',
                  icon: Icons.pending_outlined,
                  color: AppColors.warning,
                  onTap: () => HomeScreen.of(context)?.setTab(2, dueStatus: 'pending'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Responded Calls',
                  value: '${_callStats?['completed'] ?? 0}',
                  icon: Icons.phone_callback_rounded,
                  color: AppColors.success,
                  onTap: () => _showCallDetails(true),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: StatCard(
                  label: 'Failed Calls',
                  value: '${_callStats?['failed'] ?? 0}',
                  icon: Icons.phone_disabled_rounded,
                  color: AppColors.error,
                  onTap: () => _showCallDetails(false),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          _buildSectionHeader('immediate_actions'.tr(), Icons.bolt_rounded),
          StatCard(
            label: 'celebrations'.tr(),
            value: '$_todayCelebrationsCount',
            icon: Icons.cake_outlined,
            color: const Color(0xFFF43F5E), // Vibrant Rose/Pink
            isWide: true,
            subtitle: 'Wishes to send today',
            onTap: _openCelebrations,
          ),
          const SizedBox(height: 12),
          StatCard(
            label: 'expiring'.tr(),
            value: '$_expireCount',
            icon: Icons.hourglass_empty_rounded,
            color: AppColors.error,
            isWide: true,
            subtitle: 'Policies ending in 90 days',
            onTap: _openExpiringPolicies,
          ),
          const SizedBox(height: 12),
          StatCard(
            label: 'Global Celebrations',
            value: 'Share Wishes',
            icon: Icons.public_rounded,
            color: const Color(0xFF8B5CF6), // Violet
            isWide: true,
            subtitle: 'Festivals & Events',
            onTap: _openGlobalCelebrations,
          ),
          
          const SizedBox(height: 24),
          _buildSectionHeader('reach_analytics'.tr(), Icons.insights_rounded),
          StatCard(
            label: 'whatsapp_sent'.tr(),
            value: '$whatsappSent',
            icon: Icons.chat_bubble_outline_rounded,
            color: const Color(0xFF10B981), // Emerald Green
            isWide: true,
            subtitle: 'Reminders shared this month',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textTertiary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Divider(color: AppColors.border.withValues(alpha: 0.5), thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildRecentUploads(BuildContext context) {
    final uploads = _summary?['recent_uploads'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'recent_pdf_uploads'.tr(),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (uploads.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.upload_file_rounded,
                    color: AppColors.textTertiary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'no_pdfs_uploaded'.tr(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'upload_pdf_hint'.tr(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          ...uploads.map((u) {
            final upload = u as Map<String, dynamic>;
            
            // Try different possible keys for the file URL
            String? fileUrl = (upload['file_url'] ?? upload['url'] ?? upload['fileUrl'] ?? upload['signed_url'] ?? upload['public_url'])?.toString();
            final fileName = (upload['file_name'] ?? upload['name'] ?? upload['fileName'] ?? upload['path'])?.toString() ?? 'PDF File';
            final status = (upload['status'])?.toString() ?? 'uploaded';
            final records = upload['records_extracted'] ?? upload['count'] ?? 0;
            String? userId = (upload['user_id'] ?? upload['userId'] ?? upload['owner_id'])?.toString();

            // Reconstruct URL if missing but we have fileName and userId
            if ((fileUrl == null || fileUrl.isEmpty) && userId != null && fileName != 'PDF File') {
              fileUrl = '${SupabaseConfig.url}/storage/v1/object/public/${SupabaseConfig.pdfBucket}/$userId/$fileName';
              debugPrint('DASHBOARD_PDF: Reconstructed URL: $fileUrl');
            }
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      debugPrint('DASHBOARD_PDF_CLICK: Keys present: ${upload.keys}');
                      
                      // 1. If we have a URL, try it. If it fails, we fall through to the fetch logic.
                      if (fileUrl != null && fileUrl.isNotEmpty && fileUrl.startsWith('http')) {
                        // We check if it's the reconstructed one which might be wrong.
                        // For now, let's just use it first.
                        UrlLauncherHelper.openUrl(fileUrl!);
                        // If it fails (user sees 404), they might click again. 
                        // Let's also fetch the real record to be safe if they click again.
                      }

                      // 2. Fetch the full record from the database by ID to get the definitive URL and userId
                      final uploadId = upload['id']?.toString();
                      if (uploadId != null) {
                        try {
                          final dbResponse = await Supabase.instance.client
                              .from('pdf_uploads')
                              .select() // Get all columns including user_id, file_url, etc.
                              .eq('id', uploadId)
                              .maybeSingle();

                          if (dbResponse != null) {
                            final dbUrl = (dbResponse['file_url'] ?? dbResponse['url'] ?? dbResponse['signed_url'])?.toString();
                            final dbUserId = (dbResponse['user_id'] ?? dbResponse['userId'])?.toString();
                            final dbFileName = (dbResponse['file_name'] ?? dbResponse['name'])?.toString();
                            
                            debugPrint('DASHBOARD_PDF_CLICK: Fetched DB details: $dbResponse');

                            if (dbUrl != null && dbUrl.isNotEmpty && dbUrl.startsWith('http') && !dbUrl.contains('token=')) {
                              // If it's a public URL without a token, it might be the "invalid" one.
                              // Let's try to generate a signed URL for it on the fly.
                              try {
                                final signed = await Supabase.instance.client.storage
                                    .from(SupabaseConfig.pdfBucket)
                                    .createSignedUrl('$dbUserId/$dbFileName', 3600); // 1 hour is enough for opening
                                UrlLauncherHelper.openUrl(signed);
                                return;
                              } catch (e) {
                                debugPrint('DASHBOARD_PDF_CLICK: Signed URL fallback failed: $e');
                                // Fall back to the stored one
                                UrlLauncherHelper.openUrl(dbUrl);
                                return;
                              }
                            } else if (dbUrl != null && dbUrl.isNotEmpty) {
                              UrlLauncherHelper.openUrl(dbUrl);
                              return;
                            }

                            // If URL is missing in DB, construct a signed one
                            if (dbUserId != null && dbFileName != null) {
                              try {
                                final signed = await Supabase.instance.client.storage
                                    .from(SupabaseConfig.pdfBucket)
                                    .createSignedUrl('$dbUserId/$dbFileName', 3600);
                                UrlLauncherHelper.openUrl(signed);
                                return;
                              } catch (e) {
                                debugPrint('DASHBOARD_PDF_CLICK: Manual signed URL generation failed: $e');
                              }
                            }
                          }
                        } catch (e) {
                          debugPrint('DASHBOARD_PDF_CLICK: DB Fetch Error: $e');
                        }
                      }

                      // 3. Fallback to error message if all else fails
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Cannot open PDF: Link not available (ID: ${upload['id'] ?? 'unknown'})'),
                            backgroundColor: AppColors.error,
                            duration: const Duration(seconds: 3),
                            action: SnackBarAction(
                              label: 'Details',
                              textColor: Colors.white,
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Debug Info'),
                                    content: Text('Keys: ${upload.keys.join(', ')}\n\nValues: ${upload.toString()}'),
                                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }
                    },
                    splashColor: AppColors.primary.withValues(alpha: 0.1),
                    highlightColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: Icon(Icons.picture_as_pdf_rounded,
                                  color: AppColors.error, size: 26),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fileName,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (status.toLowerCase() == 'completed' || status.toLowerCase() == 'processed') 
                                            ? AppColors.success.withValues(alpha: 0.1) 
                                            : AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 9, 
                                          fontWeight: FontWeight.w800, 
                                          color: (status.toLowerCase() == 'completed' || status.toLowerCase() == 'processed') 
                                              ? AppColors.success 
                                              : AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$records records',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        fontSize: 11,
                                        color: AppColors.textTertiary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'view'.tr().toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 22),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _QuickStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
