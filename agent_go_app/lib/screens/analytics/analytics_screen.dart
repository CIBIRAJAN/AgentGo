import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme/app_colors.dart';
import '../../services/analytics_service.dart';
import '../../utils/formatters.dart';
import '../../components/common/empty_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/agent_provider.dart';
import '../../components/common/agent_switcher.dart';

/// Analytics screen displaying commission trends.
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  late final AnalyticsService _analyticsService;

  List<Map<String, dynamic>> _allData = [];
  bool _isLoading = true;

  int _selectedYear = DateTime.now().year;
  List<int> _availableYears = [];

  @override
  void initState() {
    super.initState();
    // Use targetUserIds from provider
    final targetUserIds = ref.read(agentProvider).targetUserIds;
    _analyticsService = AnalyticsService(Supabase.instance.client, targetUserIds: targetUserIds);
    _availableYears = [_selectedYear];
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch up to 60 months of data so we can filter by year purely client-side
      final data = await _analyticsService.getCommissionAnalytics(months: 60);
      if (mounted) {
        setState(() {
          _allData = data;
          
          // Extract unique years from the data to populate the filter
          final years = <int>{};
          for (final row in _allData) {
            final monthStr = row['due_month']?.toString() ?? '';
            if (monthStr.length >= 4) {
              final yr = int.tryParse(monthStr.substring(0, 4));
              if (yr != null) years.add(yr);
            }
          }
          if (!years.contains(_selectedYear)) years.add(_selectedYear);
          
          _availableYears = years.toList()..sort((a, b) => b.compareTo(a)); // Descending
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for agent changes
    ref.listen<AgentState>(agentProvider, (previous, next) {
      if (previous?.targetUserIds != next.targetUserIds) {
        _analyticsService = AnalyticsService(Supabase.instance.client, targetUserIds: next.targetUserIds);
        _loadData();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Commission Analytics'),
        actions: [
          if (!_isLoading && _availableYears.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedYear,
                  dropdownColor: AppColors.surface,
                  icon: const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  items: _availableYears.map((y) {
                    return DropdownMenuItem<int>(
                      value: y,
                      child: Text('$y'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedYear = val);
                  },
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final yearlyData = _allData.where((row) {
      final monthStr = row['due_month']?.toString() ?? '';
      return monthStr.startsWith('$_selectedYear-');
    }).toList();

    // The data comes from the server usually ordered. We should ensure it's ordered by month ascending to chart property left-to-right.
    yearlyData.sort((a, b) {
        final aStr = a['due_month']?.toString() ?? '';
        final bStr = b['due_month']?.toString() ?? '';
        return aStr.compareTo(bStr);
    });

    if (yearlyData.isEmpty) {
      return const EmptyState(
        icon: Icons.analytics_rounded,
        title: 'No commission data',
        subtitle: 'No records found for the selected year.',
      );
    }

    // Calculate totals for the selected year
    double totalCommission = 0;
    double earnedCommission = 0;
    for (final row in yearlyData) {
      totalCommission += (row['total_commission'] as num?)?.toDouble() ?? 0;
      earnedCommission += (row['earned_commission'] as num?)?.toDouble() ?? 0;
    }

    // Prepare chart spots
    final List<FlSpot> spots = [];
    double maxEarned = 0;
    
    // Fill the 12 months (0 to 11)
    for (int i = 0; i < 12; i++) {
        final monthPrefix = '$_selectedYear-${(i + 1).toString().padLeft(2, '0')}';
        final row = yearlyData.firstWhere(
            (r) => (r['due_month']?.toString() ?? '') == monthPrefix,
            orElse: () => <String, dynamic>{}, // Return empty map if not found
        );
        
        final earned = (row['earned_commission'] as num?)?.toDouble() ?? 0.0;
        if (earned > maxEarned) maxEarned = earned;
        spots.add(FlSpot(i.toDouble(), earned));
    }
    
    // Add some padding to maxY so wave doesn't touch the immediate roof
    final double effectiveMaxY = maxEarned > 0 ? maxEarned * 1.2 : 1000;
    final double intervalValue = (effectiveMaxY / 5).clamp(1.0, double.infinity);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const AgentSwitcher(isLight: true),
          const SizedBox(height: 16),
          // Summary cards
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Total Commission',
                  value: Formatters.currency(totalCommission),
                  color: AppColors.secondary,
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  label: 'Earned',
                  value: Formatters.currency(earnedCommission),
                  color: AppColors.success,
                  icon: Icons.trending_up_rounded,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          Text('Commission Trend', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          
          // Wave Graph
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: intervalValue,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppColors.border,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                        final int index = value.toInt();
                        if (index < 0 || index >= months.length) return const SizedBox.shrink();
                        // Show every other month if screen is tight, but usually 12 letters is fine
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                              months[index],
                              style: const TextStyle(fontSize: 10, color: AppColors.textTertiary, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: intervalValue,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(
                            Formatters.compactCurrency(value),
                            style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 11,
                minY: 0,
                maxY: effectiveMaxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: AppColors.primary,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          Text('Monthly Breakdown', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),

          // Monthly breakdown list
          ...yearlyData.reversed.map((row) {
            final month = row['due_month']?.toString() ?? '';
            final total = (row['total_policies'] as num?)?.toInt() ?? 0;
            final paid = (row['paid_policies'] as num?)?.toInt() ?? 0;
            final totalPremium = (row['total_premium'] as num?)?.toDouble() ?? 0;
            final collected = (row['collected_premium'] as num?)?.toDouble() ?? 0;
            final commission = (row['earned_commission'] as num?)?.toDouble() ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        Formatters.dueMonth(month),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      Text(
                        '$paid/$total paid',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total > 0 ? paid / total : 0,
                      backgroundColor: AppColors.surfaceVariant,
                      color: AppColors.success,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      _MiniStat(label: 'Premium', value: Formatters.currency(totalPremium)),
                      _MiniStat(label: 'Collected', value: Formatters.currency(collected)),
                      _MiniStat(label: 'Commission', value: Formatters.currency(commission), color: AppColors.secondary),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _MiniStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
