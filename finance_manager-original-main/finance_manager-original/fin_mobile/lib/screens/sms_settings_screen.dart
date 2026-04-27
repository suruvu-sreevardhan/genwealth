// lib/screens/sms_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/sms_monitor_service.dart';

class SmsSettingsScreen extends StatefulWidget {
  const SmsSettingsScreen({super.key});

  @override
  _SmsSettingsScreenState createState() => _SmsSettingsScreenState();
}

class _SmsSettingsScreenState extends State<SmsSettingsScreen> {
  bool isMonitoring = false;
  bool hasPermission = false;
  bool isLoading = false;
  bool isSyncing = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    PermissionStatus status = await Permission.sms.status;
    if (!mounted) return;
    setState(() {
      hasPermission = status.isGranted;
      isMonitoring = status.isGranted;
    });
  }

  Future<void> _requestPermission() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    bool granted = await SmsMonitorService.requestPermissions();

    if (granted) {
      await SmsMonitorService.startListening();
    }

    if (!mounted) return;
    if (granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ SMS monitoring enabled!'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ SMS permission denied'), backgroundColor: Colors.red),
      );
    }

    setState(() {
      hasPermission = granted;
      isMonitoring = granted;
      isLoading = false;
    });
  }

  Future<void> _syncExistingSms() async {
    if (!mounted) return;
    setState(() => isSyncing = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🔄 Syncing SMS... This may take a minute')),
    );

    await SmsMonitorService.syncExistingSms();

    if (!mounted) return;
    setState(() => isSyncing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Sync complete! Check your transactions'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Auto-Tracking'),
        backgroundColor: Colors.indigo,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              color: Colors.indigo[50],
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.message, size: 64, color: Colors.indigo),
                    const SizedBox(height: 12),
                    const Text(
                      'Automatic Transaction Tracking',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Read bank SMS to automatically create transactions',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Status
            const Text('Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Icon(
                  isMonitoring ? Icons.check_circle : Icons.cancel,
                  color: isMonitoring ? Colors.green : Colors.red,
                  size: 40,
                ),
                title: Text(
                  isMonitoring ? 'SMS Monitoring Active' : 'SMS Monitoring Inactive',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  isMonitoring
                      ? 'Automatically tracking bank SMS'
                      : 'Enable to start auto-tracking',
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Enable/Disable Button
            if (!hasPermission) ...[
              const Text('Enable SMS Monitoring', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Grant SMS permission to automatically track transactions from bank SMS',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: isLoading ? null : _requestPermission,
                        icon: const Icon(Icons.lock_open),
                        label: Text(isLoading ? 'Requesting...' : 'Grant Permission'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Sync Button
            if (hasPermission) ...[
              const SizedBox(height: 24),
              const Text('Sync Existing SMS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Import transactions from existing bank SMS (last 30 days)',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: isSyncing ? null : _syncExistingSms,
                        icon: const Icon(Icons.sync),
                        label: Text(isSyncing ? 'Syncing...' : 'Sync Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // How it works
            const Text('How It Works', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStep('1', 'Bank sends SMS for transaction', Icons.message),
                    const Divider(),
                    _buildStep('2', 'App reads and parses SMS', Icons.analytics),
                    const Divider(),
                    _buildStep('3', 'AI categorizes transaction', Icons.psychology),
                    const Divider(),
                    _buildStep('4', 'Transaction auto-created', Icons.check_circle),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Supported Banks
            const Text('Supported Banks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildBankChip('HDFC Bank'),
                    _buildBankChip('ICICI Bank'),
                    _buildBankChip('SBI'),
                    _buildBankChip('Axis Bank'),
                    _buildBankChip('Kotak'),
                    _buildBankChip('PNB'),
                    _buildBankChip('Yes Bank'),
                    _buildBankChip('IDFC First'),
                    _buildBankChip('+ 15 more'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Privacy Notice
            Card(
              color: Colors.amber[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.privacy_tip, color: Colors.amber[800]),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Privacy & Security',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'We only read bank SMS. Your personal messages are never accessed. SMS data is processed locally and never shared.',
                            style: TextStyle(fontSize: 12),
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
      ),
    );
  }

  Widget _buildStep(String number, String text, IconData icon) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: Colors.indigo[100],
          foregroundColor: Colors.indigo,
          child: Text(number, style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Icon(icon, color: Colors.indigo),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }

  Widget _buildBankChip(String bank) {
    return Chip(
      label: Text(bank, style: const TextStyle(fontSize: 12)),
      backgroundColor: Colors.blue[50],
    );
  }
}
