import 'package:flutter/material.dart';

import 'login_screen.dart';

class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  late final PageController _pageController;

  int _currentStep = 0;
  double _monthlyIncome = 60000;
  double _savingsGoalPercent = 25;
  double _spendingControl = 50;
  double _aiAutomationLevel = 70;

  static const int _stepsCount = 4;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep >= _stepsCount - 1) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LoginScreen(prefilledMonthlyIncome: _monthlyIncome),
        ),
      );
      return;
    }

    final next = _currentStep + 1;
    setState(() => _currentStep = next);
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  void _previousStep() {
    if (_currentStep == 0) return;
    final prev = _currentStep - 1;
    setState(() => _currentStep = prev);
    _pageController.animateToPage(
      prev,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildStep({
    required String emoji,
    required String title,
    required String subtitle,
    required List<Color> illustrationColors,
    required Widget input,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OnboardingIllustration(
            emoji: emoji,
            colors: illustrationColors,
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.68),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 22),
          Expanded(child: input),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentStep + 1) / _stepsCount;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Text(
                    'Step ${_currentStep + 1} of $_stepsCount',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => LoginScreen(
                            prefilledMonthlyIncome: _monthlyIncome,
                          ),
                        ),
                      );
                    },
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withOpacity(0.12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep(
                    emoji: '💸',
                    title: '1 Income setup',
                    subtitle: 'Set your monthly income for accurate wealth tracking.',
                    illustrationColors: const [
                      Color(0xFF2563EB),
                      Color(0xFF4F46E5),
                    ],
                    input: _SliderCard(
                      valueLabel: '₹${_monthlyIncome.toStringAsFixed(0)} / month',
                      hint: 'Move slider to set your monthly income.',
                      child: Slider(
                        value: _monthlyIncome,
                        min: 10000,
                        max: 300000,
                        divisions: 58,
                        label: _monthlyIncome.toStringAsFixed(0),
                        onChanged: (value) => setState(() => _monthlyIncome = value),
                      ),
                    ),
                  ),
                  _buildStep(
                    emoji: '🎯',
                    title: '2 Savings goals',
                    subtitle: 'Choose how much of your income you want to save each month.',
                    illustrationColors: const [
                      Color(0xFF14B8A6),
                      Color(0xFF22D3EE),
                    ],
                    input: _SliderCard(
                      valueLabel: '${_savingsGoalPercent.toStringAsFixed(0)}% savings target',
                      hint: 'A healthy target is often between 20% and 30%.',
                      child: Slider(
                        value: _savingsGoalPercent,
                        min: 5,
                        max: 60,
                        divisions: 55,
                        label: _savingsGoalPercent.toStringAsFixed(0),
                        onChanged: (value) => setState(() => _savingsGoalPercent = value),
                      ),
                    ),
                  ),
                  _buildStep(
                    emoji: '🧠',
                    title: '3 Spending habits',
                    subtitle: 'Tell us how much control you want over day-to-day expenses.',
                    illustrationColors: const [
                      Color(0xFF8B5CF6),
                      Color(0xFFA78BFA),
                    ],
                    input: _SliderCard(
                      valueLabel: '${_spendingControl.toStringAsFixed(0)}% spending control',
                      hint: 'Higher means tighter tracking and stricter budget nudges.',
                      child: Slider(
                        value: _spendingControl,
                        min: 0,
                        max: 100,
                        divisions: 100,
                        label: _spendingControl.toStringAsFixed(0),
                        onChanged: (value) => setState(() => _spendingControl = value),
                      ),
                    ),
                  ),
                  _buildStep(
                    emoji: '🤖',
                    title: '4 AI personalization',
                    subtitle: 'Decide how proactive GenWealth AI should be with insights and reminders.',
                    illustrationColors: const [
                      Color(0xFF0EA5E9),
                      Color(0xFF8B5CF6),
                    ],
                    input: _SliderCard(
                      valueLabel: '${_aiAutomationLevel.toStringAsFixed(0)}% AI assistance',
                      hint: 'Higher means more automation, nudges, and smart recommendations.',
                      child: Slider(
                        value: _aiAutomationLevel,
                        min: 0,
                        max: 100,
                        divisions: 100,
                        label: _aiAutomationLevel.toStringAsFixed(0),
                        onChanged: (value) => setState(() => _aiAutomationLevel = value),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousStep,
                        child: const Text('Back'),
                      ),
                    )
                  else
                    const Spacer(),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _nextStep,
                      child: Text(_currentStep == _stepsCount - 1 ? 'Get Started' : 'Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingIllustration extends StatelessWidget {
  const _OnboardingIllustration({
    required this.emoji,
    required this.colors,
  });

  final String emoji;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -14,
            right: -10,
            child: CircleAvatar(
              radius: 42,
              backgroundColor: Colors.white.withOpacity(0.2),
            ),
          ),
          Positioned(
            bottom: -8,
            left: -6,
            child: CircleAvatar(
              radius: 34,
              backgroundColor: Colors.white.withOpacity(0.14),
            ),
          ),
          Center(
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 74),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderCard extends StatelessWidget {
  const _SliderCard({
    required this.valueLabel,
    required this.hint,
    required this.child,
  });

  final String valueLabel;
  final String hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            valueLabel,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hint,
            style: TextStyle(
              fontSize: 13.5,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.62),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}