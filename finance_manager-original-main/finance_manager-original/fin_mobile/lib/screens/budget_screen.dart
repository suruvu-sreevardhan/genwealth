// lib/screens/budget_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/category_utils.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  _BudgetScreenState createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final api = ApiService();
  
  List<dynamic> budgets = [];
  bool loading = true;
  String? selectedMonth;

  @override
  void initState() {
    super.initState();
    // Default to current month
    final now = DateTime.now();
    selectedMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _loadBudgets();
  }

  Future<void> _loadBudgets() async {
    if (!mounted) return;
    setState(() => loading = true);

    try {
      final data = await api.getBudgets(month: selectedMonth);
      if (!mounted) return;
      setState(() {
        budgets = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() => loading = false);
    }
  }

  Future<bool> _confirmDeleteBudget(dynamic budget) async {
    final category = toDisplayCategory(budget['category']?.toString());
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Budget'),
        content: Text('Delete "$category" budget for $selectedMonth?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteBudget(dynamic budget) async {
    try {
      await api.deleteBudget((budget['id'] as num).toInt());
      if (!mounted) return;
      await _loadBudgets();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Budget deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete budget: $e')),
      );
    }
  }

  void _showAddBudgetDialog() {
    String selectedCategory = displayCategoriesForBudget.first;
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Add Budget'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: displayCategoriesForBudget
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedCategory = value);
                  }
                },
              ),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Limit Amount'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await api.createBudget(
                    toCanonicalCategory(selectedCategory),
                    double.parse(amountController.text),
                    selectedMonth!,
                  );
                  if (!dialogCtx.mounted) return;
                  Navigator.pop(dialogCtx);
                  _loadBudgets();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Budget created!')),
                    );
                  }
                } catch (e) {
                  if (!dialogCtx.mounted) return;
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'exceeded':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'on_track':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'exceeded':
        return Icons.error;
      case 'warning':
        return Icons.warning;
      case 'on_track':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBudgets,
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Month Selector
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text('Month:', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButton<String>(
                          value: selectedMonth,
                          isExpanded: true,
                          items: _generateMonthsList()
                              .map((month) => DropdownMenuItem(
                                    value: month,
                                    child: Text(month),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() => selectedMonth = value);
                            _loadBudgets();
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Budget List
                Expanded(
                  child: budgets.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.account_balance_wallet, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text('No budgets for this month'),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _showAddBudgetDialog,
                                child: const Text('Create Budget'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: budgets.length,
                          itemBuilder: (context, index) {
                            final budget = budgets[index];
                            final percentage = budget['percentage_used'] ?? 0;
                            
                            return GestureDetector(
                              onLongPress: () async {
                                final confirmed = await _confirmDeleteBudget(budget);
                                if (confirmed) {
                                  _deleteBudget(budget);
                                }
                              },
                              child: Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              _getStatusIcon(budget['status']),
                                              color: _getStatusColor(budget['status']),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              toDisplayCategory(budget['category']?.toString()).toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '${percentage.toStringAsFixed(0)}%',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: _getStatusColor(budget['status']),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    LinearProgressIndicator(
                                      value: percentage / 100,
                                      backgroundColor: Colors.grey[200],
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        _getStatusColor(budget['status']),
                                      ),
                                      minHeight: 8,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Spent: ₹${budget['spent'].toStringAsFixed(2)}'),
                                            Text('Limit: ₹${budget['limit_amount'].toStringAsFixed(2)}'),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            const Text(
                                              'Remaining',
                                              style: TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                            Text(
                                              '₹${budget['remaining'].toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: budget['remaining'] > 0 ? Colors.green : Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBudgetDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  List<String> _generateMonthsList() {
    final now = DateTime.now();
    List<String> months = [];
    
    for (int i = 0; i < 12; i++) {
      final date = DateTime(now.year, now.month - i, 1);
      months.add('${date.year}-${date.month.toString().padLeft(2, '0')}');
    }
    
    return months;
  }
}
