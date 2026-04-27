// lib/screens/chat_screen.dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService api = ApiService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> messages = [];
  final List<String> _suggestedPrompts = const [
    'How can I save ₹5000?',
    'Where am I overspending?',
    'Best SIP for beginner?',
    'Can I afford a trip?',
  ];

  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _insights;
  List<dynamic> _transactions = [];

  bool _loadingInsights = true;
  bool isLoading = false;
  bool _isListening = false;
  bool _attachmentAdded = false;

  @override
  void initState() {
    super.initState();
    _loadUserInsights();
    messages.add({
      'type': 'bot',
      'text': 'Hi! I\'m your AI Wealth Coach 🤖\nAsk me anything about savings, risk, spending, or goals.',
      'timestamp': DateTime.now(),
    });
  }

  Future<void> _loadUserInsights() async {
    final summary = await _safeFetch(api.getDashboardSummary());
    final insights = await _safeFetch(api.getInsights());
    final transactions = await _safeFetch(api.getTransactions(limit: 80));

    if (!mounted) return;
    setState(() {
      _summary = summary;
      _insights = insights;
      _transactions = transactions ?? [];
      _loadingInsights = false;
    });
  }

  Future<T?> _safeFetch<T>(Future<T> request) async {
    try {
      return await request;
    } catch (_) {
      return null;
    }
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  String _buildContextSnippet() {
    final balance = _asDouble(_summary?['total_balance']);
    final income = _asDouble(_summary?['total_income']);
    final expense = _asDouble(_summary?['total_expense']);
    final categories = (_summary?['top_categories'] as List?) ?? const [];
    final topCategories = categories
        .take(3)
        .map((c) => '${c['category']}: ₹${_asDouble(c['spent']).toStringAsFixed(0)}')
        .join(', ');

    return 'Balance: ₹${balance.toStringAsFixed(0)}, Income: ₹${income.toStringAsFixed(0)}, Expense: ₹${expense.toStringAsFixed(0)}'
        '${topCategories.isNotEmpty ? ', Top categories: $topCategories' : ''}';
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      messages.add({
        'type': 'user',
        'text': text,
        'timestamp': DateTime.now(),
      });
      isLoading = true;
    });

    _controller.clear();
    _scrollToBottom();

    try {
      final promptWithContext = '$text\n\nUser Finance Context: ${_buildContextSnippet()}';
      final response = await api.chat(promptWithContext);
      setState(() {
        messages.add({
          'type': 'bot',
          'text': response['response'],
          'timestamp': DateTime.now(),
        });
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        messages.add({
          'type': 'bot',
          'text': 'Sorry, I couldn\'t process your request. Please try again.',
          'timestamp': DateTime.now(),
        });
        isLoading = false;
      });
    }

    _scrollToBottom();
  }

  Future<void> _toggleVoiceInput() async {
    setState(() => _isListening = !_isListening);
    if (_isListening) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice mode started. Speak your finance question.')),
      );
    }
  }

  Future<void> _toggleAttachment() async {
    setState(() => _attachmentAdded = !_attachmentAdded);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_attachmentAdded ? 'Attachment added for context' : 'Attachment removed'),
      ),
    );
  }

  Widget _glassContainer({required Widget child, EdgeInsetsGeometry? padding}) {
    final glass = Theme.of(context).extension<AppGlassTheme>() ?? AppGlassTheme.light;
    final container = Container(
      padding: padding ?? const EdgeInsets.all(14),
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
              child: container,
            )
          : container,
    );
  }

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary, AppTheme.purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'AI Wealth Coach 🤖',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightStrip() {
    if (_loadingInsights) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: _glassContainer(
          child: const SizedBox(
            height: 58,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      );
    }

    final insightsList = (_insights?['insights'] as List?) ?? const [];
    final topInsight = insightsList.isNotEmpty
        ? insightsList.first.toString()
        : (_summary?['dynamic_insight']?.toString() ?? 'Insights will appear once more transaction data is available.');

    final spend = _asDouble(_summary?['total_expense']);
    final income = _asDouble(_summary?['total_income']);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: _glassContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Live insights from your data', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              topInsight,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.72)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pill('Income ₹${income.toStringAsFixed(0)}', AppTheme.mint),
                _pill('Expense ₹${spend.toStringAsFixed(0)}', Colors.redAccent),
                _pill('Transactions ${_transactions.length}', AppTheme.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  Widget _buildPromptChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _suggestedPrompts.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final prompt = _suggestedPrompts[i];
            return ActionChip(
              onPressed: () => _sendMessage(prompt),
              label: Text(prompt),
              backgroundColor: Colors.white.withOpacity(0.82),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: BorderSide(color: AppTheme.primary.withOpacity(0.2)),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _typingBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.purple]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }

  Widget _chatBubble(Map<String, dynamic> message) {
    final isUser = message['type'] == 'user';
    final text = (message['text'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.purple]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(colors: [AppTheme.primary, AppTheme.purple])
                    : null,
                color: isUser ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 6),
                  bottomRight: Radius.circular(isUser ? 6 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isUser ? Colors.white : Theme.of(context).colorScheme.onSurface,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 17,
              backgroundColor: AppTheme.dark.withOpacity(0.76),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: _glassContainer(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            IconButton(
              onPressed: _toggleAttachment,
              icon: Icon(
                _attachmentAdded ? Icons.attach_file_rounded : Icons.add_circle_outline_rounded,
                color: _attachmentAdded ? AppTheme.mint : AppTheme.primary,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: _isListening ? 'Listening... ask your question' : 'Ask your AI Wealth Coach...',
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    borderSide: BorderSide(color: AppTheme.primary, width: 1.2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onSubmitted: _sendMessage,
              ),
            ),
            IconButton(
              onPressed: _toggleVoiceInput,
              icon: Icon(
                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: _isListening ? Colors.redAccent : AppTheme.primary,
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.purple]),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: isLoading ? null : () => _sendMessage(_controller.text),
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7FBFF), Color(0xFFF4F8FF), Color(0xFFF6FFFD)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -70,
              right: -50,
              child: _GlowBlob(color: AppTheme.purple.withOpacity(0.17), size: 180),
            ),
            Positioned(
              top: 140,
              left: -65,
              child: _GlowBlob(color: AppTheme.mint.withOpacity(0.16), size: 165),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildTopHeader(),
                  _buildInsightStrip(),
                  _buildPromptChips(),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      itemCount: messages.length + (isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.length && isLoading) {
                          return _typingBubble();
                        }
                        return _chatBubble(messages[index]);
                      },
                    ),
                  ),
                  _buildComposer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final t = _controller.value * math.pi * 2;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final opacity = 0.35 + (math.sin(t + i) + 1) * 0.3;
            return Container(
              width: 8,
              height: 8,
              margin: EdgeInsets.only(right: i == 2 ? 0 : 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(opacity.clamp(0, 1)),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
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