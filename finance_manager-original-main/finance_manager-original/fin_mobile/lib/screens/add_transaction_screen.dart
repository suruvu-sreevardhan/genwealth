// lib/screens/add_transaction_screen.dart
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../theme.dart';
import '../utils/category_utils.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen>
    with SingleTickerProviderStateMixin {
  final _merchant = TextEditingController();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  final ApiService api = ApiService();

  late final AnimationController _pulseController;

  bool loading = false;
  String? _selectedCategory;
  String? _selectedPaymentMode;
  DateTime _selectedDate = DateTime.now();
  bool _voiceNoteEnabled = false;
  bool _receiptAttached = false;
  String? _receiptLabel;

  static const _categoryChoices = [
    ('🍔', 'Food & Dining'),
    ('🚗', 'Transport'),
    ('🛍', 'Shopping'),
    ('💡', 'Bills & Utilities'),
    ('🎯', 'Other'),
  ];

  static const _paymentModes = [
    (Icons.qr_code_2_rounded, 'UPI'),
    (Icons.credit_card_rounded, 'Card'),
    (Icons.payments_outlined, 'Cash'),
    (Icons.account_balance_wallet_rounded, 'Wallet'),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _merchant.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<String?> _askCorrectCategory() async {
    String? selected = displayCategoriesForBudget.first;

    return showDialog<String>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Select Correct Category'),
          content: DropdownButtonFormField<String>(
            value: selected,
            decoration: const InputDecoration(labelText: 'Category'),
            items: displayCategoriesForBudget
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (val) => setDialogState(() => selected = val),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, selected),
              child: const Text('Save Category'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.primary,
                  secondary: AppTheme.mint,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _toggleVoiceNote() async {
    setState(() => _voiceNoteEnabled = !_voiceNoteEnabled);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_voiceNoteEnabled ? 'Voice note mode enabled' : 'Voice note removed'),
      ),
    );
  }

  Future<void> _attachReceipt() async {
    setState(() {
      _receiptAttached = true;
      _receiptLabel = 'Receipt uploaded';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt attached')),
    );
  }

  void _removeReceipt() {
    setState(() {
      _receiptAttached = false;
      _receiptLabel = null;
    });
  }

  void _save() async {
    final amt = double.tryParse(_amount.text.trim());
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }

    if (_merchant.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter merchant name')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => loading = true);

    final body = <String, dynamic>{
      'amount': amt,
      'merchant': _merchant.text.trim(),
      'notes': _notes.text.trim(),
      'transaction_date': _selectedDate.toIso8601String(),
      if (_selectedCategory != null) 'category': toCanonicalCategory(_selectedCategory),
      if (_selectedPaymentMode != null) 'payment_mode': _selectedPaymentMode,
      'voice_note_enabled': _voiceNoteEnabled,
      'receipt_attached': _receiptAttached,
      if (_receiptLabel != null) 'receipt_label': _receiptLabel,
    };

    try {
      final res = await api.post('/api/transactions/', body, auth: true);
      if (!mounted) return;
      setState(() => loading = false);
      if (res.statusCode == 201) {
        final created = jsonDecode(res.body) as Map<String, dynamic>;
        final createdCategory = toCanonicalCategory(created['category']?.toString());

        if (createdCategory == uncategorizedKey && created['id'] != null) {
          final pickedDisplay = await _askCorrectCategory();
          if (pickedDisplay != null) {
            await api.updateTransaction(
              (created['id'] as num).toInt(),
              {'category': toCanonicalCategory(pickedDisplay)},
            );
          }
        }

        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else {
        final map = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(map['error'] ?? 'Failed to save transaction')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  String _formattedDate() => DateFormat('EEE, d MMM y').format(_selectedDate);

  String _amountHint() => '₹0';

  Widget _glassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    final glass = Theme.of(context).extension<AppGlassTheme>() ?? AppGlassTheme.light;
    final card = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: glass.color,
        border: glass.border,
        borderRadius: BorderRadius.circular(28),
        boxShadow: glass.shadow,
      ),
      child: child,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: kIsWeb && glass.blurSigma > 0
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: glass.blurSigma, sigmaY: glass.blurSigma),
              child: card,
            )
          : card,
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.62)),
        ),
      ],
    );
  }

  Widget _chip(
    String label, {
    required bool selected,
    required VoidCallback onTap,
    String? emoji,
  }) {
    return AnimatedScale(
      scale: selected ? 1.02 : 1,
      duration: const Duration(milliseconds: 180),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(colors: [AppTheme.primary, AppTheme.purple])
                : LinearGradient(
                    colors: [Colors.white.withOpacity(0.76), Colors.white.withOpacity(0.52)],
                  ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? Colors.transparent : Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null) ...[
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentModeTile(IconData icon, String label) {
    final selected = _selectedPaymentMode == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPaymentMode = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(colors: [AppTheme.primary, AppTheme.mint])
                : null,
            color: selected ? null : Colors.white.withOpacity(0.60),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? Colors.transparent : Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? Colors.white : AppTheme.primary, size: 26),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.65),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.purple]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.calendar_month_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Date', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    _formattedDate(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.62),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }

  Widget _attachmentCard() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: _toggleVoiceNote,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _voiceNoteEnabled ? AppTheme.primary.withOpacity(0.12) : Colors.white.withOpacity(0.58),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _voiceNoteEnabled ? AppTheme.primary.withOpacity(0.18) : Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic_rounded, color: _voiceNoteEnabled ? AppTheme.primary : AppTheme.dark),
                  const SizedBox(width: 8),
                  Text(
                    _voiceNoteEnabled ? 'Voice note on' : 'Voice note',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: _attachReceipt,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _receiptAttached ? AppTheme.mint.withOpacity(0.12) : Colors.white.withOpacity(0.58),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _receiptAttached ? AppTheme.mint.withOpacity(0.18) : Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_rounded, color: _receiptAttached ? AppTheme.mint : AppTheme.dark),
                  const SizedBox(width: 8),
                  Text(
                    _receiptAttached ? 'Receipt attached' : 'Receipt upload',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _receiptBanner() {
    if (!_receiptAttached || _receiptLabel == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.mint.withOpacity(0.12), AppTheme.primary.withOpacity(0.08)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.mint.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: AppTheme.mint, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(_receiptLabel!, style: const TextStyle(fontWeight: FontWeight.w700))),
          TextButton(
            onPressed: _removeReceipt,
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amountProgress = double.tryParse(_amount.text.trim()) != null ? 1.0 : 0.0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppTheme.background,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: _glassCard(
          padding: const EdgeInsets.all(12),
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_pulseController.value);
              return SizedBox(
                height: 58,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary,
                        Color.lerp(AppTheme.purple, AppTheme.mint, t) ?? AppTheme.mint,
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: loading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: loading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                          )
                        : const Text(
                            'Save Transaction',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF6FBFF), Color(0xFFF3F6FF), Color(0xFFF8FFFE)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: -70,
            right: -40,
            child: _GlowBlob(color: AppTheme.purple.withOpacity(0.18), size: 170),
          ),
          Positioned(
            top: 120,
            left: -60,
            child: _GlowBlob(color: AppTheme.mint.withOpacity(0.16), size: 160),
          ),
          SafeArea(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [AppTheme.primary, AppTheme.purple],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Icon(Icons.payments_rounded, color: Colors.white),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Add Transaction',
                                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, height: 1.05),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Premium entry flow with intelligent categorization',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.62),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _glassCard(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('Amount', 'Large numeric input with focus on the value'),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.70),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        '₹',
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _amount,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -0.6),
                                        decoration: InputDecoration(
                                          hintText: _amountHint(),
                                          hintStyle: TextStyle(
                                            fontSize: 34,
                                            fontWeight: FontWeight.w900,
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.25),
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Divider(height: 1),
                              const SizedBox(height: 14),
                              _sectionTitle('Merchant', 'Who did you pay or receive from?'),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _merchant,
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  hintText: 'e.g. Swiggy, Uber, Electricity Board',
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.70),
                                  prefixIcon: const Icon(Icons.storefront_rounded),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08)),
                                  ),
                                  focusedBorder: const OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(18)),
                                    borderSide: BorderSide(color: AppTheme.primary, width: 1.3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _glassCard(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('Category', 'Tap a chip for fast categorization'),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  for (final c in _categoryChoices)
                                    _chip(
                                      c.$2,
                                      emoji: c.$1,
                                      selected: _selectedCategory == c.$2,
                                      onTap: () => setState(() => _selectedCategory = c.$2),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Selected: ${_selectedCategory ?? 'Not selected'}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.72),
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => setState(() => _selectedCategory = null),
                                    child: const Text('Clear'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _glassCard(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('Payment Mode', 'Choose how the transaction was made'),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  for (int i = 0; i < _paymentModes.length; i++) ...[
                                    if (i > 0) const SizedBox(width: 10),
                                    _paymentModeTile(_paymentModes[i].$1, _paymentModes[i].$2),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _glassCard(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('Date & Attachments', 'Pick date, add voice note, and attach receipt'),
                              const SizedBox(height: 12),
                              _dateCard(),
                              const SizedBox(height: 12),
                              _attachmentCard(),
                              const SizedBox(height: 12),
                              _receiptBanner(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _glassCard(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('Notes', 'Optional memo for faster tracking'),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _notes,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText: 'Add a note, context, or reminder...',
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.70),
                                  alignLabelWithHint: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08)),
                                  ),
                                  focusedBorder: const OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(18)),
                                    borderSide: BorderSide(color: AppTheme.primary, width: 1.3),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _tinyStat('Amount set', amountProgress > 0 ? 'Yes' : 'No'),
                                  const SizedBox(width: 10),
                                  _tinyStat('Voice note', _voiceNoteEnabled ? 'On' : 'Off'),
                                  const SizedBox(width: 10),
                                  _tinyStat('Receipt', _receiptAttached ? 'Attached' : 'None'),
                                ],
                              ),
                            ],
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

  Widget _tinyStat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.58))),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
          ],
        ),
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