import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'add_transaction_screen.dart';
import 'chat_screen.dart';
import 'budget_screen.dart';
import 'sms_settings_screen.dart';

class DashboardScreenNew extends StatefulWidget {
  const DashboardScreenNew({super.key});

  @override
  State<DashboardScreenNew> createState() => _DashboardScreenNewState();
}

class _DashboardScreenNewState extends State<DashboardScreenNew>
    with SingleTickerProviderStateMixin {
  final ApiService api = ApiService();
  late final AnimationController _floatController;

  Map<String, dynamic>? summary;
  Map<String, dynamic>? budgetSummary;
  Map<String, dynamic>? gamification;
  Map<String, dynamic>? aiWidgets;
  String dailyTip = 'Small steps compound into wealth.';
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
    Future.microtask(_loadSummary);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    if (!mounted) return;
    debugPrint('[DashboardNew] _loadSummary start');
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await api.getDashboardSummary();
      final budget = await api.getBudgetSummary();
      Map<String, dynamic> gami;
      Map<String, dynamic> ai;
      try {
        gami = await api.getGamification();
      } catch (_) {
        gami = {
          'xp': 0,
          'level': 1,
          'level_name': 'Starter',
          'saving_streak_days': 0,
          'no_spend_days_30d': 0,
          'badges': const [],
          'milestones': const [],
          'leaderboard': {'enabled': false, 'message': 'Leaderboard unavailable'}
        };
      }
      try {
        ai = await api.getAiWidgets();
      } catch (_) {
        ai = {
          'category_detection': {
            'predicted_category': 'uncategorized',
            'confidence': 0.0,
            'input_text': '',
          },
          'subscription_prediction': {'count': 0, 'items': []},
          'overspending_warning': {
            'level': 'low',
            'message': 'AI widgets are unavailable right now.',
            'projected_month_end_spend': 0,
          },
          'next_month_forecast': {'amount': 0, 'confidence': 0.0},
          'fraud_anomaly_alerts': {'count': 0, 'items': []},
          'smart_budget_recommendation': {'actions': ['AI budget recommendation unavailable.']},
        };
      }
      String tip;
      try {
        tip = await api.getDailyTip();
      } catch (_) {
        tip = data['dynamic_insight']?.toString() ??
            'Track every rupee. Consistency builds wealth.';
      }

      if (!mounted) return;
      setState(() {
        summary = data;
        budgetSummary = budget;
        gamification = gami;
        aiWidgets = ai;
        dailyTip = tip;
        loading = false;
      });
    } catch (e) {
      debugPrint('[DashboardNew] _loadSummary error: $e');
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    } finally {
      debugPrint('[DashboardNew] _loadSummary end');
    }
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  int _asInt(dynamic value) => _asDouble(value).round();

  String _currency(double value) => '₹${value.toStringAsFixed(0)}';

  String _displayName() {
    final auth = context.read<AuthProvider>();
    final rawName = auth.name?.trim();
    if (rawName != null && rawName.isNotEmpty) {
      return rawName.split(RegExp(r'\s+')).first;
    }

    final emailPrefix = auth.email?.split('@').first.trim();
    if (emailPrefix != null && emailPrefix.isNotEmpty) {
      return emailPrefix;
    }

    return 'Sree';
  }

  String _avatarInitials() {
    final auth = context.read<AuthProvider>();
    final rawName = auth.name?.trim();
    if (rawName != null && rawName.isNotEmpty) {
      final parts = rawName.split(RegExp(r'\s+'));
      if (parts.length == 1) return parts.first.substring(0, parts.first.length.clamp(0, 2)).toUpperCase();
      return '${parts.first.substring(0, 1)}${parts[1].substring(0, 1)}'.toUpperCase();
    }

    return 'S';
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

  Widget _sectionTitle(String title, {String? subtitle, Widget? action}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.62),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _badge({required IconData icon, required String label, Color? color}) {
    final badgeColor = color ?? AppTheme.mint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: badgeColor.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: badgeColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: badgeColor),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final firstName = _displayName();
    final streakDays = _asInt(gamification?['saving_streak_days']);
    final xp = _asInt(gamification?['xp']);
    final level = _asInt(gamification?['level']);
    final levelName = (gamification?['level_name'] ?? 'Saver').toString();
    final timeGreeting = () {
      final hour = DateTime.now().hour;
      if (hour < 12) return 'Good morning';
      if (hour < 17) return 'Good afternoon';
      return 'Good evening';
    }();

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello $firstName 👋',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.1),
              ),
              const SizedBox(height: 6),
              Text(
                '$timeGreeting · Your GenWealth dashboard is ready for the day.',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _badge(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Saving streak • $streakDays days',
                    color: AppTheme.purple,
                  ),
                  _badge(
                    icon: Icons.workspace_premium_rounded,
                    label: 'XP $xp • L$level $levelName',
                    color: AppTheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.purple, AppTheme.mint],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.18),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.15),
              border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.1),
            ),
            child: Center(
              child: Text(
                _avatarInitials(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNetWorthCard() {
    final balance = _asDouble(summary?['total_balance']);
    final income = _asDouble(summary?['total_income']);
    final expense = _asDouble(summary?['total_expense']);
    final savings = income - expense;
    final incomeShare = (income <= 0) ? 0.0 : (income / (income + expense + 1)).clamp(0.0, 1.0);
    final expenseShare = (income + expense) == 0 ? 0.0 : (expense / (income + expense)).clamp(0.0, 1.0);
    final savingsShare = (income + expense) == 0 ? 0.0 : (math.max(savings, 0) / (income + expense)).clamp(0.0, 1.0);

    return _glassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Net Worth',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Live wealth snapshot',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppTheme.dark),
                    ),
                  ],
                ),
              ),
              _badge(icon: Icons.trending_up_rounded, label: 'Growing', color: AppTheme.mint),
            ],
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: balance),
            duration: const Duration(milliseconds: 850),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => Text(
              _currency(value),
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, height: 1.0),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Income vs expense and savings split below',
            style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.62)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 72,
            child: CustomPaint(
              painter: _MiniGraphPainter(
                progress: _floatController.value,
                color: AppTheme.primary,
                accent: AppTheme.mint,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Row(
              children: [
                Expanded(
                  flex: (incomeShare * 100).round().clamp(1, 100),
                  child: Container(height: 10, color: AppTheme.mint),
                ),
                Expanded(
                  flex: (expenseShare * 100).round().clamp(1, 100),
                  child: Container(height: 10, color: Colors.redAccent),
                ),
                Expanded(
                  flex: (savingsShare * 100).round().clamp(1, 100),
                  child: Container(height: 10, color: AppTheme.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricPill(label: 'Income', value: _currency(income), color: AppTheme.mint),
              _MetricPill(label: 'Expense', value: _currency(expense), color: Colors.redAccent),
              _MetricPill(label: 'Savings', value: _currency(savings), color: AppTheme.primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Quick Actions', subtitle: 'Fast access to your most-used tools'),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 420 ? 4 : 2;
            final items = [
              _QuickActionData(
                icon: Icons.add_circle_outline,
                title: '+ Add Expense',
                gradient: const [AppTheme.primary, AppTheme.purple],
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
                  );
                  if (!mounted) return;
                  _loadSummary();
                },
              ),
              _QuickActionData(
                icon: Icons.document_scanner_outlined,
                title: 'Scan Bill',
                gradient: const [AppTheme.mint, AppTheme.primary],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SmsSettingsScreen()),
                  );
                },
              ),
              _QuickActionData(
                icon: Icons.flag_outlined,
                title: 'Set Goal',
                gradient: const [AppTheme.purple, AppTheme.mint],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => BudgetScreen()),
                  );
                },
              ),
              _QuickActionData(
                icon: Icons.psychology_outlined,
                title: 'Ask AI',
                gradient: const [AppTheme.primary, AppTheme.mint],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatScreen()),
                  );
                },
              ),
            ];

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.1,
              ),
              itemBuilder: (_, index) => _QuickActionTile(data: items[index]),
            );
          },
        ),
      ],
    );
  }

  IconData _badgeIcon(String id) {
    switch (id) {
      case 'budget_ninja':
        return Icons.sports_martial_arts_rounded;
      case 'debt_slayer':
        return Icons.shield_moon_rounded;
      case 'investor_starter':
        return Icons.trending_up_rounded;
      default:
        return Icons.military_tech_rounded;
    }
  }

  Widget _buildGamificationSection() {
    final data = gamification ?? const <String, dynamic>{};
    final noSpend = _asInt(data['no_spend_days_30d']);
    final streak = _asInt(data['saving_streak_days']);
    final badges = (data['badges'] as List?) ?? const [];
    final milestones = (data['milestones'] as List?) ?? const [];
    final leaderboard = (data['leaderboard'] as Map?) ?? const {'enabled': false};

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Gamification', subtitle: 'XP, streaks, and milestone unlocks'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricPill(label: 'No-spend (30d)', value: '$noSpend days', color: AppTheme.mint),
              _MetricPill(label: 'Saving streak', value: '$streak days', color: AppTheme.purple),
              _MetricPill(label: 'XP', value: '${_asInt(data['xp'])}', color: AppTheme.primary),
            ],
          ),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Badges', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: badges.map((b) {
                final unlocked = (b['unlocked'] ?? false) == true;
                final name = (b['name'] ?? 'Badge').toString();
                final progress = _asDouble(b['progress']);
                final id = (b['id'] ?? '').toString();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: unlocked
                        ? AppTheme.mint.withOpacity(0.14)
                        : Colors.grey.shade200.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: unlocked
                          ? AppTheme.mint.withOpacity(0.25)
                          : Colors.grey.shade400.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _badgeIcon(id),
                        size: 16,
                        color: unlocked ? AppTheme.mint : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        unlocked ? name : '$name (${progress.toStringAsFixed(0)}%)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: unlocked ? AppTheme.dark : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          if (milestones.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Milestone unlock cards', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: milestones.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final m = milestones[i] as Map;
                  return _MilestoneUnlockCard(
                    title: (m['title'] ?? 'Milestone').toString(),
                    reward: (m['reward'] ?? '').toString(),
                    xpRequired: _asInt(m['xp_required']),
                    unlocked: (m['unlocked'] ?? false) == true,
                  );
                },
              ),
            ),
          ],
          if ((leaderboard['enabled'] ?? false) != true) ...[
            const SizedBox(height: 10),
            Text(
              (leaderboard['message'] ?? 'Leaderboard optional').toString(),
              style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBudgetProgress() {
    final budgets = (budgetSummary?['budgets'] as List?) ?? const [];
    if (budgets.isEmpty) return const SizedBox.shrink();

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Budget Progress', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ...budgets.take(3).map((b) {
            final percentage = _asDouble(b['percentage_used']).clamp(0, 120);
            final statusColor = percentage >= 100
                ? Colors.redAccent
                : percentage >= 80
                    ? Colors.orange
                    : AppTheme.mint;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        (b['category'] ?? 'Category').toString().toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                      Text('${percentage.toStringAsFixed(0)}%'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: percentage / 100),
                    duration: const Duration(milliseconds: 700),
                    builder: (_, value, __) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: value.clamp(0, 1),
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
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

  Widget _buildUpcomingBills() {
    final bills = (summary?['upcoming_bills'] as List?) ?? const [];
    if (bills.isEmpty) return const SizedBox.shrink();

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Upcoming Bills', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          Text(
            'Stay ahead of your due dates',
            style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
          ),
          const SizedBox(height: 8),
          ...bills.take(3).map((bill) {
            final amount = _asDouble(bill['amount']);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.45),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.purple.withOpacity(0.12),
                    child: const Icon(Icons.receipt_long_rounded, color: AppTheme.purple),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((bill['name'] ?? 'Bill').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(
                          'Due ${bill['due_date']?.toString().substring(0, 10) ?? 'N/A'}',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _currency(amount),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAiTip() {
    return _glassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Tip of the Day', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  dailyTip,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _severityColor(String level) {
    switch (level.toLowerCase()) {
      case 'high':
        return Colors.redAccent;
      case 'medium':
        return Colors.orange;
      default:
        return AppTheme.mint;
    }
  }

  Widget _buildMlWidgetsSection() {
    final data = aiWidgets ?? const <String, dynamic>{};
    final categoryDetection = (data['category_detection'] as Map?) ?? const {};
    final subscriptions = ((data['subscription_prediction'] as Map?)?['items'] as List?) ?? const [];
    final overspending = (data['overspending_warning'] as Map?) ?? const {};
    final forecast = (data['next_month_forecast'] as Map?) ?? const {};
    final anomalies = ((data['fraud_anomaly_alerts'] as Map?)?['items'] as List?) ?? const [];
    final budgetRec = (data['smart_budget_recommendation'] as Map?) ?? const {};
    final budgetActions = (budgetRec['actions'] as List?)?.map((e) => e.toString()).toList() ?? const [];

    final categoryName = (categoryDetection['predicted_category'] ?? 'uncategorized').toString();
    final categoryConfidence = (_asDouble(categoryDetection['confidence']) * 100).clamp(0, 100);
    final projectedSpend = _asDouble(overspending['projected_month_end_spend']);
    final forecastAmount = _asDouble(forecast['amount']);
    final forecastConfidence = (_asDouble(forecast['confidence']) * 100).clamp(0, 100);
    final overspendLevel = (overspending['level'] ?? 'low').toString();

    final topSubscription = subscriptions.isNotEmpty ? subscriptions.first as Map : const {};
    final topAnomaly = anomalies.isNotEmpty ? anomalies.first as Map : const {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('ML Finance Widgets', subtitle: 'AI-powered predictions and alerts'),
        const SizedBox(height: 2),
        SizedBox(
          height: 168,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _AiInsightCard(
                icon: Icons.category_rounded,
                title: 'Auto Category',
                gradient: const [AppTheme.primary, AppTheme.purple],
                value: categoryName.toUpperCase(),
                subtitle: 'Confidence ${categoryConfidence.toStringAsFixed(0)}%',
              ),
              const SizedBox(width: 10),
              _AiInsightCard(
                icon: Icons.subscriptions_rounded,
                title: 'Subscription Prediction',
                gradient: const [AppTheme.purple, AppTheme.mint],
                value: '${subscriptions.length} recurring',
                subtitle: topSubscription.isNotEmpty
                    ? '${(topSubscription['name'] ?? 'Upcoming').toString()} · ${_currency(_asDouble(topSubscription['amount']))}'
                    : 'No recurring patterns yet',
              ),
              const SizedBox(width: 10),
              _AiInsightCard(
                icon: Icons.warning_amber_rounded,
                title: 'Overspending Warning',
                gradient: [
                  _severityColor(overspendLevel),
                  _severityColor(overspendLevel).withOpacity(0.75),
                ],
                value: _currency(projectedSpend),
                subtitle: (overspending['message'] ?? 'No warning').toString(),
              ),
              const SizedBox(width: 10),
              _AiInsightCard(
                icon: Icons.auto_graph_rounded,
                title: 'Next-Month Forecast',
                gradient: const [AppTheme.mint, AppTheme.primary],
                value: _currency(forecastAmount),
                subtitle: 'Forecast confidence ${forecastConfidence.toStringAsFixed(0)}%',
              ),
              const SizedBox(width: 10),
              _AiInsightCard(
                icon: Icons.gpp_maybe_rounded,
                title: 'Fraud Anomaly Alerts',
                gradient: const [Colors.redAccent, AppTheme.purple],
                value: '${anomalies.length} alert(s)',
                subtitle: topAnomaly.isNotEmpty
                    ? '${(topAnomaly['merchant'] ?? 'Unknown').toString()} · ${_currency(_asDouble(topAnomaly['amount']))}'
                    : 'No anomalies in recent activity',
              ),
              const SizedBox(width: 10),
              _AiInsightCard(
                icon: Icons.tips_and_updates_rounded,
                title: 'Smart Budget Recommendation',
                gradient: const [AppTheme.primary, AppTheme.mint],
                value: (budgetRec['top_spend_category'] ?? 'Balanced').toString().toUpperCase(),
                subtitle: budgetActions.isNotEmpty ? budgetActions.first : 'Budget looks healthy',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTransactionsCarousel() {
    final txns = (summary?['recent_transactions'] as List?) ?? const [];
    if (txns.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Recent Transactions', subtitle: 'Swipe through the latest activity'),
        const SizedBox(height: 2),
        SizedBox(
          height: 152,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: txns.length.clamp(0, 8),
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final txn = txns[i];
              final isIncome = (txn['type'] ?? 'expense') == 'income';
              final color = isIncome ? Colors.green : Colors.redAccent;
              return SizedBox(
                width: 220,
                child: _glassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: color.withOpacity(0.14),
                            child: Icon(
                              isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
                              color: color,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (txn['merchant'] ?? 'Unknown').toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        _currency(_asDouble(txn['amount'])),
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${txn['category'] ?? 'uncategorized'} • ${(txn['transaction_date'] as String?)?.substring(0, 10) ?? 'Unknown'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: _loadSummary,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : summary == null
                        ? const Center(child: Text('No data available'))
                        : RefreshIndicator(
                            onRefresh: _loadSummary,
                            child: AnimatedBuilder(
                              animation: _floatController,
                              builder: (_, __) {
                                final offset = math.sin(_floatController.value * math.pi * 2) * 8;
                                return SingleChildScrollView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                                  child: SafeArea(
                                    child: Transform.translate(
                                      offset: Offset(0, offset * 0.08),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 2),
                                          _buildHeader(),
                                          const SizedBox(height: 16),

                                          _buildNetWorthCard(),
                                          const SizedBox(height: 16),
                                          _buildQuickActions(),
                                          const SizedBox(height: 16),
                                          if ((budgetSummary?['budgets'] as List?)?.isNotEmpty ?? false) _buildBudgetProgress(),
                                          if ((budgetSummary?['budgets'] as List?)?.isNotEmpty ?? false) const SizedBox(height: 16),
                                          if (((summary?['upcoming_bills'] as List?) ?? const []).isNotEmpty) _buildUpcomingBills(),
                                          if (((summary?['upcoming_bills'] as List?) ?? const []).isNotEmpty) const SizedBox(height: 16),
                                          _buildAiTip(),
                                          const SizedBox(height: 16),
                                          _buildRecentTransactionsCarousel(),
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

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

class _MilestoneUnlockCard extends StatelessWidget {
  const _MilestoneUnlockCard({
    required this.title,
    required this.reward,
    required this.xpRequired,
    required this.unlocked,
  });

  final String title;
  final String reward;
  final int xpRequired;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.96, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: unlocked
                ? [AppTheme.mint.withOpacity(0.22), AppTheme.primary.withOpacity(0.14)]
                : [Colors.grey.shade200.withOpacity(0.75), Colors.white.withOpacity(0.78)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: unlocked
                ? AppTheme.mint.withOpacity(0.3)
                : Colors.grey.shade400.withOpacity(0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: unlocked
                        ? AppTheme.mint.withOpacity(0.2)
                        : Colors.grey.shade400.withOpacity(0.2),
                  ),
                  child: Icon(
                    unlocked ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
                    size: 18,
                    color: unlocked ? AppTheme.mint : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    unlocked ? 'Unlocked' : 'Locked',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: unlocked ? AppTheme.mint : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
            const SizedBox(height: 5),
            Text(
              reward,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.66)),
            ),
            const Spacer(),
            Text(
              'Requires $xpRequired XP',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.64)),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionData {
  const _QuickActionData({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.gradient,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final List<Color> gradient;
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.data});

  final _QuickActionData data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: data.onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                data.gradient.first.withOpacity(0.16),
                data.gradient.last.withOpacity(0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: data.gradient.first.withOpacity(0.12)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: data.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(data.icon, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                data.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiInsightCard extends StatelessWidget {
  const _AiInsightCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.gradient,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gradient.first.withOpacity(0.2),
            gradient.last.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: gradient.first.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: gradient),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, height: 1.0),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
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

class _MiniGraphPainter extends CustomPainter {
  _MiniGraphPainter({
    required this.progress,
    required this.color,
    required this.accent,
  });

  final double progress;
  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final points = <Offset>[];
    final p = [0.15, 0.38, 0.31, 0.57, 0.49, 0.73, 0.68, 0.62, 0.86, 0.84];

    for (int i = 0; i < p.length ~/ 2; i++) {
      final x = p[i * 2] * size.width;
      final yWave = math.sin((progress * 2 * math.pi) + i) * 3;
      final y = size.height - (p[i * 2 + 1] * size.height) + yWave;
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final c1 = Offset((prev.dx + curr.dx) / 2, prev.dy);
      final c2 = Offset((prev.dx + curr.dx) / 2, curr.dy);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, curr.dx, curr.dy);
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..shader = LinearGradient(colors: [color, accent]).createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      )
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, stroke);

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.25), color.withOpacity(0.02)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fill);
  }

  @override
  bool shouldRepaint(covariant _MiniGraphPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}