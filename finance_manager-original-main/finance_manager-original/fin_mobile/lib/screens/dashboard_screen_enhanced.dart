// lib/screens/dashboard_screen_enhanced.dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../theme.dart';

class DashboardScreenEnhanced extends StatefulWidget {
  const DashboardScreenEnhanced({super.key});

  @override
  State<DashboardScreenEnhanced> createState() => _DashboardScreenEnhancedState();
}

class _DashboardScreenEnhancedState extends State<DashboardScreenEnhanced>
    with SingleTickerProviderStateMixin {
  final ApiService api = ApiService();
  late final AnimationController _floatController;

  Map<String, dynamic>? healthScore;
  Map<String, dynamic>? riskData;
  Map<String, dynamic>? insights;
  List<dynamic> transactions = [];
  String dailyTip = 'Consistency beats intensity in wealth building.';

  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    Future.microtask(_loadDashboardData);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  Future<T?> _safeFetch<T>(Future<T> request) async {
    try {
      return await request;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    debugPrint('[DashboardEnhanced] _loadDashboardData start');
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final fetchedHealth = await _safeFetch(api.getHealthScore());
      final fetchedRisk = await _safeFetch(api.getRiskAssessment());
      final fetchedInsights = await _safeFetch(api.getInsights());
      final fetchedTransactions = await _safeFetch(api.getTransactions(limit: 240));
      final fetchedTip = await _safeFetch(api.getDailyTip());

      if (!mounted) return;
      setState(() {
        healthScore =
            fetchedHealth ?? {'score': 0, 'grade': 'Set monthly income'};
        riskData = fetchedRisk ?? {'default_risk_percentage': 0, 'risk_level': 'Unknown'};
        insights = fetchedInsights ?? {'insights': [], 'patterns': {}};
        transactions = fetchedTransactions ?? [];
        dailyTip = fetchedTip ?? dailyTip;
        loading = false;
      });
    } catch (e) {
      debugPrint('[DashboardEnhanced] _loadDashboardData error: $e');
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    } finally {
      debugPrint('[DashboardEnhanced] _loadDashboardData end');
    }
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  String _rupee(double value) => '₹${value.toStringAsFixed(0)}';

  DateTime? _txnDate(dynamic txn) {
    final raw = txn['transaction_date']?.toString();
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }

  Widget _glassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    final glass = Theme.of(context).extension<AppGlassTheme>() ?? AppGlassTheme.light;
    final card = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: glass.color,
        border: glass.border,
        borderRadius: BorderRadius.circular(24),
        boxShadow: glass.shadow,
      ),
      child: child,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: kIsWeb && glass.blurSigma > 0
          ? BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: glass.blurSigma,
                sigmaY: glass.blurSigma,
              ),
              child: card,
            )
          : card,
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12.5,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.62),
            ),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return AppTheme.primary;
    if (score >= 40) return Colors.orange;
    return Colors.redAccent;
  }

  Color _riskColor(double riskPercent) {
    if (riskPercent >= 70) return Colors.redAccent;
    if (riskPercent >= 40) return Colors.orange;
    return AppTheme.mint;
  }

  double _healthScore() => _asDouble(healthScore?['score']).clamp(0, 100);

  double _riskPercent() =>
      _asDouble(riskData?['default_risk_percentage']).clamp(0, 100);

  String _riskLevel() =>
      (riskData?['risk_level'] ?? 'Unknown').toString();

  List<FlSpot> _monthlySpendSpots() {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final buckets = List<double>.filled(daysInMonth, 0);

    for (final txn in transactions) {
      final date = _txnDate(txn);
      if (date == null || date.month != now.month || date.year != now.year) continue;
      final type = (txn['type'] ?? 'expense').toString().toLowerCase();
      if (type != 'expense') continue;
      buckets[date.day - 1] += _asDouble(txn['amount']).abs();
    }

    final endDay = now.day;
    final spots = <FlSpot>[];
    for (int i = 0; i < endDay; i++) {
      spots.add(FlSpot(i.toDouble(), buckets[i]));
    }

    if (spots.every((s) => s.y == 0)) {
      return [
        const FlSpot(0, 0),
        const FlSpot(1, 0),
      ];
    }
    return spots;
  }

  List<_MonthLedger> _lastSixMonthLedger() {
    final now = DateTime.now();
    final months = <DateTime>[];
    for (int i = 5; i >= 0; i--) {
      months.add(DateTime(now.year, now.month - i, 1));
    }

    final ledger = {
      for (final month in months)
        DateFormat('yyyy-MM').format(month): _MonthLedger(
          label: DateFormat('MMM').format(month),
          income: 0,
          expense: 0,
        ),
    };

    for (final txn in transactions) {
      final date = _txnDate(txn);
      if (date == null) continue;
      final key = DateFormat('yyyy-MM').format(DateTime(date.year, date.month, 1));
      final bucket = ledger[key];
      if (bucket == null) continue;

      final amount = _asDouble(txn['amount']).abs();
      final type = (txn['type'] ?? 'expense').toString().toLowerCase();
      if (type == 'income') {
        bucket.income += amount;
      } else {
        bucket.expense += amount;
      }
    }

    return ledger.values.toList();
  }

  List<BarChartGroupData> _incomeExpenseBars(List<_MonthLedger> ledger) {
    return List<BarChartGroupData>.generate(ledger.length, (index) {
      final item = ledger[index];
      return BarChartGroupData(
        x: index,
        barsSpace: 5,
        barRods: [
          BarChartRodData(
            toY: item.income,
            width: 8,
            gradient: const LinearGradient(colors: [AppTheme.mint, Color(0xFF0EA5A4)]),
            borderRadius: BorderRadius.circular(4),
          ),
          BarChartRodData(
            toY: item.expense,
            width: 8,
            gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEF4444)]),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });
  }

  List<FlSpot> _savingsTrendSpots(List<_MonthLedger> ledger) {
    if (ledger.isEmpty) return [const FlSpot(0, 0)];
    return List<FlSpot>.generate(
      ledger.length,
      (i) => FlSpot(i.toDouble(), ledger[i].income - ledger[i].expense),
    );
  }

  List<PieChartSectionData> _categoryDonutSections() {
    final pattern = insights?['patterns'];
    final rawMap = pattern is Map ? pattern['category_spending'] : null;

    final aggregate = <String, double>{};
    if (rawMap is Map) {
      rawMap.forEach((k, v) {
        aggregate[k.toString()] = _asDouble(v).abs();
      });
    }

    if (aggregate.isEmpty) {
      for (final txn in transactions) {
        final type = (txn['type'] ?? 'expense').toString().toLowerCase();
        if (type != 'expense') continue;
        final category = (txn['category'] ?? 'Other').toString();
        aggregate[category] = (aggregate[category] ?? 0) + _asDouble(txn['amount']).abs();
      }
    }

    if (aggregate.isEmpty) {
      return [
        PieChartSectionData(
          value: 100,
          color: Colors.grey.shade300,
          radius: 40,
          title: 'No Data',
          titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ];
    }

    final entries = aggregate.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      AppTheme.primary,
      AppTheme.mint,
      AppTheme.purple,
      Colors.orange,
      Colors.pink,
      Colors.teal,
    ];

    return entries.take(6).toList().asMap().entries.map((entry) {
      final i = entry.key;
      final e = entry.value;
      return PieChartSectionData(
        value: e.value,
        radius: 44,
        color: colors[i % colors.length],
        title: e.key.length > 10 ? '${e.key.substring(0, 10)}…' : e.key,
        titleStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white),
      );
    }).toList();
  }

  Widget _buildHealthScoreRing() {
    final score = _healthScore();
    final grade = (healthScore?['grade'] ?? 'N/A').toString();
    final color = _scoreColor(score);

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('1. Financial Health Score', 'Your overall money wellness index'),
          const SizedBox(height: 2),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 148,
                        height: 148,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: score / 100),
                          duration: const Duration(milliseconds: 900),
                          builder: (_, value, __) => CircularProgressIndicator(
                            value: value,
                            strokeWidth: 14,
                            backgroundColor: color.withOpacity(0.16),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(score.toStringAsFixed(0), style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900)),
                          Text(grade, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.62), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _smallStat('Savings', _asDouble(healthScore?['factors']?['savings']?['score']).toStringAsFixed(0)),
                      _smallStat('Debt', _asDouble(healthScore?['factors']?['debt']?['score']).toStringAsFixed(0)),
                      _smallStat('Stability', _asDouble(healthScore?['factors']?['emergency_fund']?['score']).toStringAsFixed(0)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallStat(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildMonthlySpendLine() {
    final spots = _monthlySpendSpots();
    final maxY = spots.map((e) => e.y).fold<double>(0, math.max);

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('2. Monthly Spend Trend', 'Animated daily expense line for this month'),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: (maxY * 1.25).clamp(1, double.infinity),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withOpacity(0.55),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(handleBuiltInTouches: true),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: math.max(1, (spots.length / 5).floor()).toDouble(),
                      getTitlesWidget: (value, _) => Text(
                        '${value.toInt() + 1}',
                        style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: maxY <= 0 ? 1 : math.max(1, (maxY / 3).floor()).toDouble(),
                      getTitlesWidget: (value, _) => Text(
                        '₹${value.toInt()}',
                        style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                      ),
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    barWidth: 3.5,
                    gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.purple]),
                    dotData: FlDotData(
                      show: spots.length <= 20,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 3,
                        color: Colors.white,
                        strokeColor: AppTheme.primary,
                        strokeWidth: 2,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.primary.withOpacity(0.24),
                          AppTheme.purple.withOpacity(0.03),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeExpenseBars(List<_MonthLedger> ledger) {
    final groups = _incomeExpenseBars(ledger);
    final maxY = ledger.fold<double>(0, (prev, e) => math.max(prev, math.max(e.income, e.expense)));

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('3. Income vs Expense', 'Six-month cashflow comparison'),
          const SizedBox(height: 4),
          const Row(
            children: [
              _Legend(color: AppTheme.mint, label: 'Income'),
              SizedBox(width: 12),
              _Legend(color: Color(0xFFEF4444), label: 'Expense'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 230,
            child: BarChart(
              BarChartData(
                maxY: (maxY * 1.2).clamp(1, double.infinity),
                barGroups: groups,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withOpacity(0.55), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) {
                        final i = value.toInt();
                        if (i < 0 || i >= ledger.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(ledger[i].label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: maxY <= 0 ? 1 : math.max(1, (maxY / 3).floor()).toDouble(),
                      getTitlesWidget: (value, _) => Text(
                        '₹${value.toInt()}',
                        style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDonut() {
    final sections = _categoryDonutSections();

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('4. Category Donut', 'Top spend buckets by amount'),
          SizedBox(
            height: 250,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 56,
                sectionsSpace: 2,
                startDegreeOffset: -90,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsTrend(List<_MonthLedger> ledger) {
    final spots = _savingsTrendSpots(ledger);
    double minY = 0;
    double maxY = 0;
    for (final s in spots) {
      minY = math.min(minY, s.y);
      maxY = math.max(maxY, s.y);
    }
    final range = (maxY - minY).abs();

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('5. Savings Trend', 'Monthly net savings over the last six months'),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: minY - (range * 0.15),
                maxY: maxY + (range * 0.15) + 1,
                lineTouchData: const LineTouchData(enabled: true),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: value == 0 ? Colors.redAccent.withOpacity(0.28) : Colors.white.withOpacity(0.55),
                    strokeWidth: value == 0 ? 1.4 : 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) {
                        final i = value.toInt();
                        if (i < 0 || i >= ledger.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(ledger[i].label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: range <= 0 ? 1 : math.max(1, (range / 3).floor()).toDouble(),
                      getTitlesWidget: (value, _) => Text(
                        '₹${value.toInt()}',
                        style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                      ),
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    barWidth: 3,
                    gradient: const LinearGradient(colors: [AppTheme.mint, AppTheme.primary]),
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.mint.withOpacity(0.2),
                          AppTheme.primary.withOpacity(0.02),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiInsightsCards() {
    final insightsList = (insights?['insights'] as List?) ?? const [];
    final cards = <String>[
      if (dailyTip.trim().isNotEmpty) dailyTip,
      ...insightsList.map((e) => e.toString()),
    ];

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('6. AI Insights', 'Smart recommendations and money signals'),
          if (cards.isEmpty)
            Text(
              'No AI insights available right now.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.62)),
            )
          else
            ...cards.take(4).toList().asMap().entries.map((entry) {
              final i = entry.key;
              final text = entry.value;
              final gradients = [
                [AppTheme.primary.withOpacity(0.18), AppTheme.purple.withOpacity(0.12)],
                [AppTheme.mint.withOpacity(0.2), AppTheme.primary.withOpacity(0.12)],
                [AppTheme.purple.withOpacity(0.2), AppTheme.mint.withOpacity(0.12)],
                [Colors.orange.withOpacity(0.2), AppTheme.primary.withOpacity(0.12)],
              ];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradients[i % gradients.length]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        text,
                        style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRiskScoreMeter() {
    final riskPercent = _riskPercent();
    final riskLevel = _riskLevel();
    final color = _riskColor(riskPercent);

    final safeSlice = (100 - riskPercent).clamp(0.0, 100.0).toDouble();

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('7. Risk Score Meter', 'Probability of financial stress exposure'),
          SizedBox(
            height: 210,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    startDegreeOffset: 180,
                    sectionsSpace: 0,
                    centerSpaceRadius: 62,
                    sections: [
                      PieChartSectionData(
                        value: riskPercent,
                        radius: 26,
                        color: color,
                        title: '',
                      ),
                      PieChartSectionData(
                        value: safeSlice,
                        radius: 26,
                        color: Colors.grey.shade300,
                        title: '',
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 78,
                  child: Column(
                    children: [
                      Text('${riskPercent.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          riskLevel,
                          style: TextStyle(color: color, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ledger = _lastSixMonthLedger();

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Stack(
          children: [
            loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Error: $error'),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadDashboardData, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadDashboardData,
                        child: AnimatedBuilder(
                          animation: _floatController,
                          builder: (_, __) {
                            final y = math.sin(_floatController.value * math.pi * 2) * 6;
                            return SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                              child: SafeArea(
                                child: Transform.translate(
                                  offset: Offset(0, y * 0.07),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Expanded(
                                            child: Text(
                                              'Analytics',
                                              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: _loadDashboardData,
                                            icon: const Icon(Icons.refresh_rounded),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      _buildHealthScoreRing(),
                                      const SizedBox(height: 12),
                                      _buildMonthlySpendLine(),
                                      const SizedBox(height: 12),
                                      _buildIncomeExpenseBars(ledger),
                                      const SizedBox(height: 12),
                                      _buildCategoryDonut(),
                                      const SizedBox(height: 12),
                                      _buildSavingsTrend(ledger),
                                      const SizedBox(height: 12),
                                      _buildAiInsightsCards(),
                                      const SizedBox(height: 12),
                                      _buildRiskScoreMeter(),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _MonthLedger {
  _MonthLedger({required this.label, required this.income, required this.expense});

  final String label;
  double income;
  double expense;
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withOpacity(0.0)],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}