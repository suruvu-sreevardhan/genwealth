// lib/screens/home_screen.dart
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'add_transaction_screen.dart';
import 'dashboard_screen_new.dart';
import 'dashboard_screen_enhanced.dart';
import 'sms_settings_screen.dart';
import 'profile_screen.dart';
import 'coach_screen.dart';
import '../theme.dart';
import '../utils/category_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService api = ApiService();
  late final PageController _pageController;

  List transactions = [];
  List _filteredTransactions = [];
  bool loading = false;
  int _selectedIndex = 0;
  String _selectedCategoryFilter = 'All';
  String _searchQuery = '';
  DateTime? _selectedDateFilter;
  double? _minAmountFilter;
  double? _maxAmountFilter;

  static final List<String> _filterCategories = [
    'All',
    ...displayCategoriesForInput,
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    Future.microtask(_loadTxns);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildTab(BuildContext context, int index) {
    switch (index) {
      case 0:
        return const DashboardScreenNew();
      case 1:
        return _buildTransactionsScreen();
      case 2:
        return const DashboardScreenEnhanced();
      case 3:
        return const CoachScreen();
      case 4:
        return const ProfileScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _loadTxns() async {
    if (!mounted) return;
    debugPrint('[Home] _loadTxns start');
    setState(() => loading = true);
    try {
      final res = await api.get('/api/transactions/', auth: true);
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          transactions = jsonDecode(res.body);
          _applyFilter();
        });
      } else {
        final map = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(map['error'] ?? 'Failed to load transactions')),
        );
      }
    } catch (e) {
      debugPrint('[Home] _loadTxns error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
      debugPrint('[Home] _loadTxns end');
    }
  }

  void _applyFilter() {
    _filteredTransactions = transactions.where((t) {
      final amount = (t['amount'] as num?)?.toDouble().abs() ?? 0;
      final merchant = (t['merchant'] ?? '').toString().toLowerCase();
      final notes = (t['notes'] ?? '').toString().toLowerCase();
      final category = toCanonicalCategory((t['category'] ?? '').toString());
      final txnDateRaw = (t['transaction_date'] ?? '').toString();

      final queryOk = _searchQuery.trim().isEmpty ||
          merchant.contains(_searchQuery.toLowerCase()) ||
          notes.contains(_searchQuery.toLowerCase());

      final categoryOk = _selectedCategoryFilter == 'All' ||
          category == toCanonicalCategory(_selectedCategoryFilter);

      bool dateOk = true;
      if (_selectedDateFilter != null && txnDateRaw.isNotEmpty) {
        try {
          final date = DateTime.parse(txnDateRaw).toLocal();
          dateOk = date.year == _selectedDateFilter!.year &&
              date.month == _selectedDateFilter!.month &&
              date.day == _selectedDateFilter!.day;
        } catch (_) {
          dateOk = false;
        }
      }

      final minOk = _minAmountFilter == null || amount >= _minAmountFilter!;
      final maxOk = _maxAmountFilter == null || amount <= _maxAmountFilter!;

      return queryOk && categoryOk && dateOk && minOk && maxOk;
    }).toList();
  }

  DateTime? _parseTxnDate(dynamic txn) {
    final raw = (txn['transaction_date'] ?? '').toString();
    if (raw.isEmpty) return null;
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _sectionForTransaction(dynamic txn) {
    final date = _parseTxnDate(txn);
    if (date == null) return 'Earlier';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final txnDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(txnDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (date.year == now.year && date.month == now.month) return 'This Month';
    return DateFormat('MMMM yyyy').format(date);
  }

  String _txnTimeLabel(dynamic txn) {
    final date = _parseTxnDate(txn);
    if (date == null) return 'Unknown time';
    return DateFormat('h:mm a').format(date);
  }

  String _txnDateLabel(dynamic txn) {
    final date = _parseTxnDate(txn);
    if (date == null) return 'Unknown date';
    return DateFormat('EEE, d MMM y').format(date);
  }

  String _merchantAvatarText(String merchant) {
    final trimmed = merchant.trim();
    if (trimmed.isEmpty) return 'TX';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return trimmed.substring(0, trimmed.length.clamp(0, 2)).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts[1].substring(0, 1)}'.toUpperCase();
  }

  String _categoryEmoji(String? rawCategory) {
    switch (toCanonicalCategory(rawCategory)) {
      case 'food':
        return '🍔';
      case 'transport':
        return '🚗';
      case 'shopping':
        return '🛍';
      case 'utilities':
        return '💡';
      case 'rent':
        return '🏠';
      case 'grocery':
        return '🧺';
      case 'fuel':
        return '⛽';
      case 'salary':
      case 'income':
        return '💰';
      case 'emi':
        return '📄';
      case 'education':
        return '🎓';
      case 'healthcare':
        return '💊';
      case 'entertainment':
        return '🎬';
      default:
        return '✨';
    }
  }

  Color _categoryTone(String? rawCategory) {
    switch (toCanonicalCategory(rawCategory)) {
      case 'food':
        return Colors.orange;
      case 'transport':
        return Colors.blue;
      case 'shopping':
        return Colors.purple;
      case 'utilities':
        return Colors.indigo;
      case 'rent':
        return Colors.teal;
      case 'grocery':
        return Colors.green;
      case 'fuel':
        return Colors.redAccent;
      case 'salary':
      case 'income':
        return Colors.green;
      case 'emi':
        return Colors.deepPurple;
      case 'education':
        return Colors.brown;
      case 'healthcare':
        return Colors.cyan;
      case 'entertainment':
        return Colors.pink;
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> _showTransactionDetails(dynamic txn) async {
    final amount = (txn['amount'] as num?)?.toDouble() ?? 0;
    final isIncome = (txn['type']?.toString().toLowerCase() ?? 'expense') == 'income';
    final tone = _categoryTone(txn['category']?.toString());

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.62,
          minChildSize: 0.48,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [tone.withOpacity(0.95), AppTheme.primary.withOpacity(0.9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Center(
                          child: Text(
                            _merchantAvatarText((txn['merchant'] ?? 'TX').toString()),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (txn['merchant'] ?? 'Unknown merchant').toString(),
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_categoryEmoji(txn['category']?.toString())} ${toDisplayCategory(txn['category']?.toString())}',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.62), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primary.withOpacity(0.14), AppTheme.mint.withOpacity(0.12)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isIncome ? 'Income' : 'Expense',
                          style: TextStyle(color: tone, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '₹${amount.abs().toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _detailRow('Date', _txnDateLabel(txn)),
                  _detailRow('Time', _txnTimeLabel(txn)),
                  _detailRow('Type', (txn['type'] ?? 'expense').toString()),
                  _detailRow('Category', toDisplayCategory(txn['category']?.toString())),
                  _detailRow('Notes', (txn['notes'] ?? 'No notes').toString()),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            _showEditSheet(txn);
                          },
                          icon: const Icon(Icons.edit_rounded),
                          label: const Text('Edit'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(sheetCtx);
                            final confirmed = await _confirmDelete(txn);
                            if (confirmed && mounted) _deleteTransaction(txn);
                          },
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Delete'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.62))),
          const Spacer(),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    final activeCount = _filteredTransactions.length;
    final categories = ['All', ...displayCategoriesForInput];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white.withOpacity(0.92), Colors.white.withOpacity(0.76)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.8)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.dark.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: 'Search merchant, notes, category',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                          borderSide: BorderSide(color: AppTheme.primary, width: 1.3),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                          _applyFilter();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showAdvancedFilters,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.purple]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.tune_rounded, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    '$activeCount transactions',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _selectedCategoryFilter = 'All';
                        _selectedDateFilter = null;
                        _minAmountFilter = null;
                        _maxAmountFilter = null;
                        _applyFilter();
                      });
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final cat = categories[index];
                    final selected = cat == _selectedCategoryFilter;
                    return FilterChip(
                      selected: selected,
                      label: Text(cat),
                      onSelected: (_) {
                        setState(() {
                          _selectedCategoryFilter = cat;
                          _applyFilter();
                        });
                      },
                      backgroundColor: Colors.white,
                      selectedColor: AppTheme.primary.withOpacity(0.12),
                      checkmarkColor: AppTheme.primary,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected ? AppTheme.primary : Theme.of(context).colorScheme.onSurface,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<_TxnSection> _groupFilteredTransactions() {
    final groups = <String, List<dynamic>>{};
    for (final txn in _filteredTransactions) {
      final label = _sectionForTransaction(txn);
      groups.putIfAbsent(label, () => []).add(txn);
    }

    final ordered = <_TxnSection>[];
    for (final name in ['Today', 'Yesterday', 'This Month']) {
      if (groups.containsKey(name)) {
        ordered.add(_TxnSection(name, groups.remove(name)!));
      }
    }

    final restKeys = groups.keys.toList();
    restKeys.sort((a, b) => b.compareTo(a));
    for (final key in restKeys) {
      ordered.add(_TxnSection(key, groups[key]!));
    }

    return ordered;
  }

  Widget _buildPremiumTransactionCard(dynamic txn) {
    final amount = (txn['amount'] as num?)?.toDouble() ?? 0;
    final isIncome = (txn['type']?.toString().toLowerCase() ?? 'expense') == 'income';
    final tone = _categoryTone(txn['category']?.toString());
    final gradient = isIncome
        ? [Colors.green.shade400, Colors.green.shade700]
        : [tone.withOpacity(0.92), AppTheme.purple.withOpacity(0.8)];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.96, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Dismissible(
        key: ValueKey(txn['id']),
        direction: DismissDirection.horizontal,
        background: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.purple]),
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          child: const Icon(Icons.edit_rounded, color: Colors.white, size: 28),
        ),
        secondaryBackground: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.red.shade300, Colors.red.shade700]),
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            await _showEditSheet(txn);
            return false;
          }
          return _confirmDelete(txn);
        },
        onDismissed: (_) => _deleteTransaction(txn),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => _showTransactionDetails(txn),
              onLongPress: () => _showActionSheet(txn),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.78),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.9)),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.dark.withOpacity(0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: gradient),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Text(
                          _merchantAvatarText((txn['merchant'] ?? 'TX').toString()),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (txn['merchant'] ?? '—').toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isIncome ? 'Income' : 'Expense',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isIncome ? Colors.green : Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                '${_categoryEmoji(txn['category']?.toString())} ${toDisplayCategory(txn['category']?.toString())}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.66),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(color: Colors.black.withOpacity(0.18), shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _txnTimeLabel(txn),
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55), fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${amount.abs().toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isIncome ? Colors.green : Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _txnDateLabel(txn),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.52),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAdvancedFilters() async {
    final minCtrl = TextEditingController(text: _minAmountFilter?.toString() ?? '');
    final maxCtrl = TextEditingController(text: _maxAmountFilter?.toString() ?? '');
    DateTime? draftDate = _selectedDateFilter;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (_, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Filters', style: Theme.of(sheetCtx).textTheme.titleLarge),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Min Amount'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: maxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Max Amount'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: sheetCtx,
                    initialDate: draftDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setSheetState(() => draftDate = picked);
                  }
                },
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  draftDate == null
                      ? 'Filter by Date'
                      : 'Date: ${draftDate!.toIso8601String().substring(0, 10)}',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedDateFilter = null;
                          _minAmountFilter = null;
                          _maxAmountFilter = null;
                          _applyFilter();
                        });
                        Navigator.pop(sheetCtx);
                      },
                      child: const Text('Clear'),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedDateFilter = draftDate;
                          _minAmountFilter = double.tryParse(minCtrl.text.trim());
                          _maxAmountFilter = double.tryParse(maxCtrl.text.trim());
                          _applyFilter();
                        });
                        Navigator.pop(sheetCtx);
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    minCtrl.dispose();
    maxCtrl.dispose();
  }

  List<Widget> _buildGroupedTransactionTiles() {
    if (_filteredTransactions.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text(
              _selectedCategoryFilter == 'All'
                  ? 'No transactions found.'
                  : 'No transactions in "$_selectedCategoryFilter".',
            ),
          ),
        )
      ];
    }

    final grouped = <String, List<dynamic>>{};
    for (final t in _filteredTransactions) {
      final dateStr = (t['transaction_date'] ?? '').toString();
      final shortDate = dateStr.length >= 10 ? dateStr.substring(0, 10) : 'Unknown Date';
      grouped.putIfAbsent(shortDate, () => []).add(t);
    }

    final dateKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final widgets = <Widget>[];

    for (final dateKey in dateKeys) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(
            dateKey,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      );

      final items = grouped[dateKey] ?? [];
      for (final t in items) {
        final amount = (t['amount'] as num).toDouble();
        final isDebit = (t['type']?.toString().toLowerCase() ?? 'expense') == 'expense';
        widgets.add(
          Dismissible(
            key: ValueKey(t['id']),
            direction: DismissDirection.horizontal,
            background: Container(
              color: Colors.blue.shade400,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              child: const Icon(Icons.edit_outlined, color: Colors.white, size: 28),
            ),
            secondaryBackground: Container(
              color: Colors.red.shade400,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
            ),
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                await _showEditSheet(t);
                return false;
              }
              return _confirmDelete(t);
            },
            onDismissed: (_) => _deleteTransaction(t),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CircleAvatar(
                backgroundColor: _categoryIconColor(t['category']?.toString()).withOpacity(0.12),
                child: SvgPicture.asset(
                  _iconAssetForCategory(t['category']?.toString()),
                  width: 18,
                  height: 18,
                  colorFilter: ColorFilter.mode(
                    _categoryIconColor(t['category']?.toString()),
                    BlendMode.srcIn,
                  ),
                ),
              ),
              title: Text(t['merchant'] ?? '—'),
              subtitle: Text('${toDisplayCategory(t['category']?.toString())} • ${t['type'] ?? 'expense'}'),
              trailing: Text(
                '₹${amount.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  color: isDebit ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onLongPress: () => _showActionSheet(t),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  /// Shows a confirmation dialog. Returns true if the user confirms.
  Future<bool> _confirmDelete(dynamic txn) async {
    final merchant = (txn['merchant'] ?? 'this transaction').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text('Delete "$merchant"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Optimistically removes the transaction from local state, then calls the
  /// backend. If the API call fails the list is refreshed from the server.
  Future<void> _deleteTransaction(dynamic txn) async {
    final id = (txn['id'] as num).toInt();

    // Optimistic removal — required so Dismissible doesn't throw an assertion.
    if (mounted) {
      setState(() {
        transactions.removeWhere((t) => (t['id'] as num).toInt() == id);
        _applyFilter();
      });
    }

    try {
      await api.deleteTransaction(id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
      // Restore the list from the server so the item reappears.
      _loadTxns();
    }
  }

  /// Calls PUT /transactions/{id}, then surgically replaces only that item
  /// in the local list without rebuilding the whole screen.
  Future<void> _editTransaction(int id, Map<String, dynamic> data) async {
    try {
      final updated = await api.updateTransaction(id, data);
      if (!mounted) return;
      setState(() {
        final idx =
            transactions.indexWhere((t) => (t['id'] as num).toInt() == id);
        if (idx != -1) transactions[idx] = updated;
        _applyFilter();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e')),
      );
    }
  }

  Future<void> _quickMapCategory(dynamic txn) async {
    String selectedCategory = displayCategoriesForBudget.first;

    final picked = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Map Transaction Category'),
          content: DropdownButtonFormField<String>(
            initialValue: selectedCategory,
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, selectedCategory),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (picked == null) return;

    final id = (txn['id'] as num).toInt();
    await _editTransaction(id, {'category': toCanonicalCategory(picked)});
  }

  /// Long-press action sheet — gives the user Edit and Delete choices.
  Future<void> _showActionSheet(dynamic txn) async {
    final isUncategorized =
        toCanonicalCategory(txn['category']?.toString()) == uncategorizedKey;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isUncategorized)
              ListTile(
                leading: const Icon(Icons.category, color: Colors.deepPurple),
                title: const Text('Map Category'),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await _quickMapCategory(txn);
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _showEditSheet(txn);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                final confirmed = await _confirmDelete(txn);
                if (confirmed && mounted) _deleteTransaction(txn);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Modal bottom sheet with pre-filled fields for editing a transaction.
  Future<void> _showEditSheet(dynamic txn) async {
    final id = (txn['id'] as num).toInt();
    final isDebit = (txn['type']?.toString().toLowerCase() ?? 'expense') == 'expense';
    final merchantCtrl =
        TextEditingController(text: txn['merchant'] ?? '');
    final amountCtrl = TextEditingController(
        text: (txn['amount'] as num).abs().toStringAsFixed(2));
    final notesCtrl =
        TextEditingController(text: txn['notes'] ?? '');

    // Guard: only accept a category value that actually exists in the list.
    // If the stored value is e.g. 'uncategorized' it won't be in the dropdown
    // and Flutter would throw a DropdownButton assertion.
    final validCategories = _filterCategories.where((c) => c != 'All').toList();
    final rawCategory = txn['category'] as String?;
    final existingDisplayCategory = toDisplayCategory(rawCategory);
    String? selectedCategory = validCategories.contains(existingDisplayCategory)
      ? existingDisplayCategory
      : null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true, // lets it expand above keyboard
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        // 'saving' lives outside StatefulBuilder so it persists across rebuilds.
        bool saving = false;
        return StatefulBuilder(
          builder: (_, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(sheetCtx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Edit Transaction',
                    style: Theme.of(sheetCtx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: merchantCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Merchant'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText:
                          isDebit ? '−₹ ' : '+₹ ',
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration:
                        const InputDecoration(labelText: 'Category'),
                    items: validCategories
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: saving
                        ? null
                        : (v) => setSheetState(() => selectedCategory = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Notes (optional)'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            final amt = double.tryParse(amountCtrl.text);
                            if (amt == null || amt <= 0) {
                              ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                const SnackBar(
                                    content: Text('Enter a valid amount')),
                              );
                              return;
                            }
                            setSheetState(() => saving = true);
                            final data = <String, dynamic>{
                              'merchant': merchantCtrl.text.trim(),
                              'amount': amt.abs(),
                              'type': isDebit ? 'expense' : 'income',
                              if (selectedCategory != null)
                                'category': toCanonicalCategory(selectedCategory),
                              'notes': notesCtrl.text.trim(),
                            };
                            await _editTransaction(id, data);
                            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                          },
                    child: saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save Changes'),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );

    // Dispose controllers once the sheet closes.
    merchantCtrl.dispose();
    amountCtrl.dispose();
    notesCtrl.dispose();
  }

  List<NavigationDestination> _buildDestinations() {
    return const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Home',
      ),
      NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long_rounded),
        label: 'Transactions',
      ),
      NavigationDestination(
        icon: Icon(Icons.query_stats_outlined),
        selectedIcon: Icon(Icons.query_stats_rounded),
        label: 'Analytics',
      ),
      NavigationDestination(
        icon: Icon(Icons.psychology_outlined),
        selectedIcon: Icon(Icons.psychology_rounded),
        label: 'AI Coach',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Profile',
      ),
    ];
  }

  String _iconAssetForCategory(String? rawCategory) {
    final canonical = toCanonicalCategory(rawCategory);
    switch (canonical) {
      case 'food':
        return 'assets/transaction_icons/food.svg';
      case 'shopping':
        return 'assets/transaction_icons/shopping.svg';
      case 'transport':
        return 'assets/transaction_icons/transport.svg';
      case 'entertainment':
        return 'assets/transaction_icons/entertainment.svg';
      case 'utilities':
        return 'assets/transaction_icons/utilities.svg';
      case 'healthcare':
        return 'assets/transaction_icons/healthcare.svg';
      case 'education':
        return 'assets/transaction_icons/education.svg';
      case 'grocery':
        return 'assets/transaction_icons/grocery.svg';
      case 'fuel':
        return 'assets/transaction_icons/fuel.svg';
      case 'rent':
        return 'assets/transaction_icons/rent.svg';
      case 'emi':
        return 'assets/transaction_icons/emi.svg';
      case 'salary':
      case 'income':
        return 'assets/transaction_icons/income.svg';
      default:
        return 'assets/transaction_icons/other.svg';
    }
  }

  Color _categoryIconColor(String? rawCategory) {
    final canonical = toCanonicalCategory(rawCategory);
    switch (canonical) {
      case 'food':
        return Colors.deepOrange;
      case 'shopping':
        return Colors.purple;
      case 'transport':
        return Colors.blue;
      case 'entertainment':
        return Colors.pink;
      case 'utilities':
        return Colors.indigo;
      case 'healthcare':
        return Colors.teal;
      case 'education':
        return Colors.brown;
      case 'grocery':
        return Colors.green;
      case 'fuel':
        return Colors.redAccent;
      case 'rent':
        return Colors.cyan;
      case 'emi':
        return Colors.deepPurple;
      case 'salary':
      case 'income':
        return Colors.green;
      default:
        return Colors.grey.shade700;
    }
  }

  Widget _buildTransactionsScreen() {
    final auth = Provider.of<AuthProvider>(context);
    final grouped = _groupFilteredTransactions();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            onPressed: _showAdvancedFilters,
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: 'Advanced filters',
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SmsSettingsScreen()),
              );
            },
            icon: const Icon(Icons.message_rounded),
            tooltip: 'SMS Auto-Tracking',
          ),
          IconButton(onPressed: _loadTxns, icon: const Icon(Icons.refresh_rounded)),
          IconButton(
            onPressed: () async {
              await auth.logout();
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTxns,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: _buildSearchAndFilters(),
                    ),
                  ),
                  if (_filteredTransactions.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                        child: Row(
                          children: [
                            Text(
                              'History',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const Spacer(),
                            Text(
                              '${_filteredTransactions.length} entries',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_filteredTransactions.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.purple]),
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 34),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'No transactions found',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _selectedCategoryFilter == 'All'
                                    ? 'Start tracking your spending with a new entry.'
                                    : 'Try a different filter or clear the search.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.62)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final section = grouped[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      children: [
                                        Text(
                                          section.title,
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            '${section.items.length}',
                                            style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...section.items.map(_buildPremiumTransactionCard),
                                ],
                              ),
                            );
                          },
                          childCount: grouped.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final r = await Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => const AddTransactionScreen()),
          );
          if (r == true) _loadTxns();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<AppGlassTheme>();

    return Scaffold(
      body: PageView.custom(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          if (_selectedIndex != index) {
            setState(() => _selectedIndex = index);
          }
        },
        childrenDelegate: SliverChildBuilderDelegate(
          _buildTab,
          childCount: 5,
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: glass?.color ?? Theme.of(context).colorScheme.surface.withOpacity(0.86),
            borderRadius: BorderRadius.circular(26),
            border: glass?.border,
            boxShadow: glass?.shadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onTabSelected,
              height: 70,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: _buildDestinations(),
            ),
          ),
        ),
      ),
    );
  }
}

class _TxnSection {
  const _TxnSection(this.title, this.items);

  final String title;
  final List<dynamic> items;
}
