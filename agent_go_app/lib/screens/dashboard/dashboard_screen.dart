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
import '../notifications/notification_screen.dart';
import '../diary/diary_screen.dart';

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
  List<ClientModel> _expiringPolicies = [];
  List<String> _months = [];
  int _expireCount = 0;
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
        ClientService(Supabase.instance.client, targetUserIds: targetUserIds).getExpiringPolicies()
      ]);
      if (mounted) {
        setState(() {
          _summary = results[0] as Map<String, dynamic>;
          _reminderCounts = results[1] as Map<String, dynamic>;
          _expiringPolicies = results[2] as List<ClientModel>;
          
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

  void _openCelebrations() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CelebrationsScreen(),
      ),
    );
  }

  void _openExpiringPolicies() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ExpiringPoliciesScreen(),
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

          // Agent Diary Quick Access
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DiaryScreen()));
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.book_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'agent_diary'.tr(),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                            Text(
                              'track_visits_hint'.tr(),
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
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
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(
                      themeNotifier.value == ThemeMode.dark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      if (themeNotifier.value == ThemeMode.dark) {
                        themeNotifier.value = ThemeMode.light;
                      } else {
                        themeNotifier.value = ThemeMode.dark;
                      }
                      // Note: Because this header is not listening to ValueListenableBuilder inside this widget itself, we call setState to update the icon
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quick summary bar
            if (_summary != null)
              Container(
                padding: EdgeInsets.all(isSmall ? 10 : 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
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
                      height: 30,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
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
                      height: 30,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
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
    final screenW = MediaQuery.of(context).size.width;
    final aspectRatio = screenW < 360 ? 1.1 : 1.25;

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: aspectRatio,
      ),
      delegate: SliverChildListDelegate([
        StatCard(
          label: 'total_clients'.tr(),
          value: '${_summary?['total_clients'] ?? 0}',
          icon: Icons.people_rounded,
          color: AppColors.primary,
          onTap: () {
            HomeScreen.of(context)?.setTab(1);
          },
        ),
        StatCard(
          label: 'pending_dues'.tr(),
          value: '${_summary?['pending_dues'] ?? 0}',
          icon: Icons.pending_actions_rounded,
          color: AppColors.warning,
          onTap: () {
            HomeScreen.of(context)?.setTab(2, dueStatus: 'pending');
          },
        ),
        StatCard(
          label: 'whatsapp_sent'.tr(),
          value: '$whatsappSent',
          icon: Icons.chat_rounded,
          color: const Color(0xFF25D366),
        ),
        StatCard(
          label: 'paid'.tr(),
          value: '${_summary?['paid_dues'] ?? 0}',
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
          onTap: () {
            HomeScreen.of(context)?.setTab(2, dueStatus: 'paid');
          },
        ),
        StatCard(
          label: 'total_dues'.tr(),
          value: '${_summary?['total_dues'] ?? 0}',
          icon: Icons.receipt_long_rounded,
          color: AppColors.info,
          onTap: () {
            HomeScreen.of(context)?.setTab(2, dueStatus: null);
          },
        ),
        StatCard(
          label: '⏳ ' + 'expiring'.tr(),
          value: '$_expireCount',
          icon: Icons.event_busy_rounded,
          color: AppColors.error,
          onTap: _openExpiringPolicies,
        ),
        StatCard(
          label: '🎂 ' + 'celebrations'.tr(),
          value: 'more'.tr(),
          icon: Icons.cake_rounded,
          color: const Color(0xFFEC4899),
          onTap: _openCelebrations,
        ),
      ]),
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
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_rounded,
                      color: AppColors.error, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          upload['file_name']?.toString() ?? 'PDF File',
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${upload['records_extracted'] ?? 0} records • ${upload['status']}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
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
