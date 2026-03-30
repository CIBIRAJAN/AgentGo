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
              child: PopupMenuButton<int>(
                initialValue: _selectedYear,
                color: AppColors.surface,
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                position: PopupMenuPosition.under,
                onSelected: (val) {
                  setState(() => _selectedYear = val);
                },
                itemBuilder: (context) {
                  return _availableYears.map((y) {
                    return PopupMenuItem<int>(
                      value: y,
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 16, color: y == _selectedYear ? AppColors.secondary : AppColors.textTertiary),
                          const SizedBox(width: 12),
                          Text(
                            '$y',
                            style: TextStyle(
                              fontWeight: y == _selectedYear ? FontWeight.w900 : FontWeight.w500,
                              color: y == _selectedYear ? AppColors.secondary : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.secondary),
                      const SizedBox(width: 6),
                      Text(
                        '$_selectedYear',
                        style: const TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.secondary),
                    ],
                  ),
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
          AgentSwitcher(isLight: true),
          const SizedBox(height: 16),
          
          // Premium Hero Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Expected Commission',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$_selectedYear', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  Formatters.currency(totalCommission),
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Earned', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text(
                              Formatters.currency(earnedCommission),
                              style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Pending', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text(
                              Formatters.currency(totalCommission - earnedCommission),
                              style: const TextStyle(color: Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 36),
          Row(
            children: [
              const Icon(Icons.show_chart_rounded, color: AppColors.secondary, size: 24),
              const SizedBox(width: 8),
              Text('Commission Trend', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, fontSize: 20)),
            ],
          ),
          const SizedBox(height: 20),
          
          // Wave Graph
          Container(
            height: 260,
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: intervalValue,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppColors.borderLight,
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
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                              months[index],
                              style: const TextStyle(fontSize: 10, color: AppColors.textTertiary, fontWeight: FontWeight.w700),
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
                            style: const TextStyle(fontSize: 10, color: AppColors.textTertiary, fontWeight: FontWeight.w600),
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
                    curveSmoothness: 0.35,
                    color: AppColors.secondary,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.secondary.withValues(alpha: 0.3),
                          AppColors.secondary.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 36),
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded, color: AppColors.secondary, size: 24),
              const SizedBox(width: 8),
              Text('Monthly Breakdown', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, fontSize: 20)),
            ],
          ),
          const SizedBox(height: 20),

          // Monthly breakdown list
          ...yearlyData.reversed.map((row) {
            final month = row['due_month']?.toString() ?? '';
            final total = (row['total_policies'] as num?)?.toInt() ?? 0;
            final paid = (row['paid_policies'] as num?)?.toInt() ?? 0;
            final totalPremium = (row['total_premium'] as num?)?.toDouble() ?? 0;
            final collected = (row['collected_premium'] as num?)?.toDouble() ?? 0;
            final commission = (row['earned_commission'] as num?)?.toDouble() ?? 0;
            
            final double progress = total > 0 ? (paid / total) : 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLight, width: 1.5),
                boxShadow: const [
                  BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.monetization_on_rounded, color: AppColors.secondary, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                Formatters.dueMonth(month),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$paid of $total policies paid',
                                style: const TextStyle(color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Commission', style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              Formatters.currency(commission),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.secondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${(progress * 100).toInt()}% Collected',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    '${Formatters.currency(collected)} / ${Formatters.currency(totalPremium)}',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: AppColors.borderLight,
                                  color: progress == 1 ? AppColors.success : AppColors.primary,
                                  minHeight: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
