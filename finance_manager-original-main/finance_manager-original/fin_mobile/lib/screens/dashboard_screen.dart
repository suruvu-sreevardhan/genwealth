import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final api = ApiService();
  
  Map<String, dynamic>? healthScore;
  Map<String, dynamic>? riskData;
  Map<String, dynamic>? insights;
  List<dynamic>? notifications;
  String? dailyTip;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadDashboardData);
  }

  Future<T?> _safeFetch<T>(Future<T> future, String label) async {
    try {
      return await future;
    } catch (e) {
      debugPrint('Dashboard $label failed: $e');
      return null;
    }
  }

  Future<void> _loadDashboardData() async {
    debugPrint('[DashboardLegacy] _loadDashboardData start');
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final results = await Future.wait([
        _safeFetch(api.getHealthScore(), 'health score'),
        _safeFetch(api.getRiskAssessment(), 'risk assessment'),
        _safeFetch(api.getInsights(), 'insights'),
        _safeFetch(api.getCoachNotifications(), 'notifications'),
        _safeFetch(api.getDailyTip(), 'daily tip'),
      ]);

      setState(() {
        healthScore = results[0] as Map<String, dynamic>?;
        riskData = results[1] as Map<String, dynamic>?;
        insights = results[2] as Map<String, dynamic>?;
        notifications = results[3] as List<dynamic>?;
        dailyTip = results[4] as String?;
        loading = false;
      });
    } catch (e) {
      debugPrint('[DashboardLegacy] _loadDashboardData error: $e');
      setState(() {
        error = e.toString();
        loading = false;
      });
    } finally {
      debugPrint('[DashboardLegacy] _loadDashboardData end');
    }
  }

  Color _getHealthScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.blue;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $error'),
                      ElevatedButton(
                        onPressed: _loadDashboardData,
                        child: const Text('Retry'),
                      )
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDashboardData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Daily Tip Card
                        if (dailyTip != null)
                          Card(
                            color: Colors.blue[50],
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  const Icon(Icons.lightbulb, color: Colors.amber, size: 32),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      dailyTip!,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Financial Health Score
                        if (healthScore != null)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  const Text(
                                    'Financial Health Score',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _getHealthScoreColor(healthScore!['score']).withOpacity(0.2),
                                          border: Border.all(
                                            color: _getHealthScoreColor(healthScore!['score']),
                                            width: 4,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${healthScore!['score']}',
                                            style: TextStyle(
                                              fontSize: 36,
                                              fontWeight: FontWeight.bold,
                                              color: _getHealthScoreColor(healthScore!['score']),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Grade: ${healthScore!['grade']}',
                                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 8),
                                          if (healthScore!['factors'] != null) ...[
                                            Text('Savings: ${healthScore!['factors']['savings']['score']}/30'),
                                            Text('Budget: ${healthScore!['factors']['debt']['score']}/25'),
                                            Text('Stability: ${healthScore!['factors']['emergency_fund']['score']}/20'),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Risk Assessment
                        if (riskData != null)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Risk Assessment',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Default Risk:', style: TextStyle(fontSize: 16)),
                                      Chip(
                                        label: Text(
                                          '${riskData!['default_risk_percentage']}%',
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                        backgroundColor: riskData!['risk_level'] == 'High'
                                            ? Colors.red
                                            : riskData!['risk_level'] == 'Medium'
                                                ? Colors.orange
                                                : Colors.green,
                                      ),
                                    ],
                                  ),
                                  if (riskData!['debt_analysis'] != null) ...[
                                    const Divider(),
                                    Text('Total Outstanding: ₹${riskData!['debt_analysis']['total_outstanding'].toStringAsFixed(2)}'),
                                    Text('Monthly EMI: ₹${riskData!['debt_analysis']['total_monthly_emi'].toStringAsFixed(2)}'),
                                    Text('Active Loans: ${riskData!['debt_analysis']['active_loan_count']}'),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Insights
                        if (insights != null && insights!['insights'] != null)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Spending Insights',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 12),
                                  ...(insights!['insights'] as List).map((insight) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.arrow_right, size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(insight)),
                                          ],
                                        ),
                                      )),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Notifications
                        if (notifications != null && notifications!.isNotEmpty)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Notifications (${notifications!.length})',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 12),
                                  ...notifications!.take(5).map((notif) {
                                    IconData icon;
                                    Color color;
                                    switch (notif['severity']) {
                                      case 'critical':
                                        icon = Icons.error;
                                        color = Colors.red;
                                        break;
                                      case 'high':
                                        icon = Icons.warning;
                                        color = Colors.orange;
                                        break;
                                      case 'medium':
                                        icon = Icons.info;
                                        color = Colors.blue;
                                        break;
                                      default:
                                        icon = Icons.lightbulb;
                                        color = Colors.grey;
                                    }
                                    return ListTile(
                                      leading: Icon(icon, color: color),
                                      title: Text(notif['message']),
                                      dense: true,
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
