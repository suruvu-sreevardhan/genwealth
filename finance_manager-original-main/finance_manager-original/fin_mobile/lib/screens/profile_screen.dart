// lib/screens/profile_screen.dart
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  final TextEditingController _incomeController = TextEditingController();
  final TextEditingController _emergencyFundController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _darkModeEnabled = false;
  bool _notificationsEnabled = true;

  String? _email;
  String _errorMessage = '';
  String _successMessage = '';

  int _notificationsCount = 0;
  int _subscriptionCount = 0;
  int _goalsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<T?> _safeFetch<T>(Future<T> request) async {
    try {
      return await request;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      final profile = await _safeFetch(_api.getProfile());
      final notifications = await _safeFetch(_api.getNotifications());
      final subscriptions = await _safeFetch(_api.getSubscriptions());
      final budgets = await _safeFetch(_api.getBudgets());

      if (!mounted) return;
      setState(() {
        _email = profile?['email']?.toString();
        if (profile?['monthly_income'] != null) {
          _incomeController.text = profile!['monthly_income'].toString();
        }
        if (profile?['emergency_fund'] != null) {
          _emergencyFundController.text = profile!['emergency_fund'].toString();
        }

        _notificationsCount = (notifications ?? []).length;
        _subscriptionCount = (subscriptions ?? []).length;
        _goalsCount = (budgets ?? []).length;

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load profile: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!mounted) return;
    setState(() {
      _isSaving = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      final data = <String, dynamic>{};
      if (_incomeController.text.trim().isNotEmpty) {
        data['monthly_income'] = double.parse(_incomeController.text.trim());
      }
      if (_emergencyFundController.text.trim().isNotEmpty) {
        data['emergency_fund'] =
            double.parse(_emergencyFundController.text.trim());
      }

      await _api.updateProfile(data);
      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _successMessage = 'Profile updated successfully!';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to update profile: $e';
      });
    }
  }

  Future<void> _exportData() async {
    setState(() {
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      final backup = await _api.exportBackup();
      if (!mounted) return;

      final count = (backup['transactions'] as List?)?.length ?? 0;
      setState(() {
        _successMessage = 'Export ready: $count transactions in secure backup.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Export failed: $e';
      });
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
              filter: ImageFilter.blur(sigmaX: glass.blurSigma, sigmaY: glass.blurSigma),
              child: card,
            )
          : card,
    );
  }

  Widget _badge(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.62)),
          ),
        ],
      ),
    );
  }

  Widget _settingsTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.68),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                ],
              ),
            ),
            trailing ?? const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }

  Widget _textInput({
    required TextEditingController controller,
    required String hint,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        hintText: hint,
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white.withOpacity(0.72),
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
          borderSide: BorderSide(color: AppTheme.primary, width: 1.3),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return _glassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.purple, AppTheme.mint],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.16),
                    border: Border.all(color: Colors.white.withOpacity(0.5)),
                  ),
                  child: Center(
                    child: Text(
                      (_email?.isNotEmpty ?? false)
                          ? _email!.substring(0, 1).toUpperCase()
                          : 'U',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 30),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Profile & Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.1)),
                    const SizedBox(height: 6),
                    Text(_email ?? 'No email', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.64), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    _badge('XP Level 4 Saver 🏆', AppTheme.primary, icon: Icons.workspace_premium_rounded),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _badge('7 day streak', AppTheme.purple, icon: Icons.local_fire_department_rounded),
              _badge('Saved ₹12,400 this month', AppTheme.mint, icon: Icons.savings_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSetupSection() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Income setup', 'Set your monthly income for personalized coaching'),
          _textInput(
            controller: _incomeController,
            hint: 'Enter your monthly income',
            label: 'Monthly Income (₹)',
            icon: Icons.currency_rupee_rounded,
          ),
          const SizedBox(height: 14),
          _sectionHeader('Emergency fund', 'Track your financial safety cushion'),
          _textInput(
            controller: _emergencyFundController,
            hint: 'Enter emergency fund amount',
            label: 'Emergency Fund (₹)',
            icon: Icons.shield_moon_rounded,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : const Text('Save Setup'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Settings', 'Manage app preferences and account options'),
          _settingsTile(
            title: 'Security',
            subtitle: 'Biometric, PIN, and account protection',
            icon: Icons.lock_rounded,
            color: Colors.indigo,
            onTap: () {
              setState(() => _successMessage = 'Security center coming soon.');
            },
          ),
          _settingsTile(
            title: 'Export data',
            subtitle: 'Download secure financial backup',
            icon: Icons.file_download_rounded,
            color: AppTheme.primary,
            onTap: _exportData,
          ),
          _settingsTile(
            title: 'Dark mode',
            subtitle: _darkModeEnabled ? 'Enabled (preview state)' : 'Disabled (preview state)',
            icon: Icons.dark_mode_rounded,
            color: AppTheme.purple,
            trailing: Switch(
              value: _darkModeEnabled,
              onChanged: (v) => setState(() => _darkModeEnabled = v),
            ),
            onTap: () => setState(() => _darkModeEnabled = !_darkModeEnabled),
          ),
          _settingsTile(
            title: 'Notifications',
            subtitle: '$_notificationsCount alerts available',
            icon: Icons.notifications_active_rounded,
            color: Colors.orange,
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (v) => setState(() => _notificationsEnabled = v),
            ),
            onTap: () => setState(() => _notificationsEnabled = !_notificationsEnabled),
          ),
          _settingsTile(
            title: 'Goals',
            subtitle: '$_goalsCount active goal setups',
            icon: Icons.flag_circle_rounded,
            color: AppTheme.mint,
            onTap: () {
              setState(() => _successMessage = 'Goals manager opening soon.');
            },
          ),
          _settingsTile(
            title: 'Subscription',
            subtitle: '$_subscriptionCount active subscriptions',
            icon: Icons.workspace_premium_rounded,
            color: Colors.teal,
            onTap: () {
              setState(() => _successMessage = 'Subscription center opening soon.');
            },
          ),
        ],
      ),
    );
  }

  Widget _messageBanner() {
    if (_errorMessage.isEmpty && _successMessage.isEmpty) return const SizedBox.shrink();

    final isError = _errorMessage.isNotEmpty;
    final color = isError ? Colors.red : Colors.green;
    final text = isError ? _errorMessage : _successMessage;

    return _glassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(isError ? Icons.error_rounded : Icons.check_circle_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7FBFF), Color(0xFFF3F7FF), Color(0xFFF6FFFD)],
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
              top: 170,
              left: -70,
              child: _GlowBlob(color: AppTheme.mint.withOpacity(0.16), size: 160),
            ),
            SafeArea(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadProfile,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 12),
                            _messageBanner(),
                            if (_errorMessage.isNotEmpty || _successMessage.isNotEmpty)
                              const SizedBox(height: 12),
                            _buildSetupSection(),
                            const SizedBox(height: 12),
                            _buildSettingsSection(),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _incomeController.dispose();
    _emergencyFundController.dispose();
    super.dispose();
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
            colors: [color, color.withOpacity(0)],
            stops: const [0, 1],
          ),
        ),
      ),
    );
  }
}