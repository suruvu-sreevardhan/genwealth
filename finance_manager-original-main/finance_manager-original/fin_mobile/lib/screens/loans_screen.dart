// lib/screens/loans_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  _LoansScreenState createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  final api = ApiService();
  
  Map<String, dynamic>? creditSummary;
  List<dynamic> loans = [];
  bool loading = true;
  bool hasLinkedCredit = false;

  @override
  void initState() {
    super.initState();
    _loadLoansData();
  }

  Future<void> _loadLoansData() async {
    if (!mounted) return;
    setState(() => loading = true);

    try {
      final summary = await api.getCreditSummary();
      if (!mounted) return;
      final loansList = await api.getLoans();
      if (!mounted) return;
      setState(() {
        creditSummary = summary;
        loans = loansList;
        hasLinkedCredit = summary['credit_score'] != null;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      hasLinkedCredit = false;
    }
  }

  void _showLinkCreditDialog() {
    final panController = TextEditingController();
    final nameController = TextEditingController();
    final dobController = TextEditingController();
    final mobileController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Link Credit Report'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: panController,
                decoration: const InputDecoration(labelText: 'PAN Number'),
                textCapitalization: TextCapitalization.characters,
              ),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              TextField(
                controller: dobController,
                decoration: const InputDecoration(labelText: 'Date of Birth (YYYY-MM-DD)'),
              ),
              TextField(
                controller: mobileController,
                decoration: const InputDecoration(labelText: 'Mobile Number'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final result = await api.initiatePanConsent(
                  panController.text,
                  nameController.text,
                  dobController.text,
                  mobileController.text,
                );
                if (!dialogCtx.mounted) return;
                Navigator.pop(dialogCtx);
                _showOtpDialog(result['consent_request_id'], result['mock_otp'], panController.text);
              } catch (e) {
                if (!dialogCtx.mounted) return;
                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Send OTP'),
          ),
        ],
      ),
    );
  }

  void _showOtpDialog(String consentId, String mockOtp, String pan) {
    final otpController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Verify OTP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter OTP sent to your mobile'),
            Text('Mock OTP: $mockOtp', style: const TextStyle(color: Colors.blue)),
            const SizedBox(height: 12),
            TextField(
              controller: otpController,
              decoration: const InputDecoration(labelText: 'OTP'),
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
                await api.verifyOtp(consentId, otpController.text);
                if (!dialogCtx.mounted) return;
                Navigator.pop(dialogCtx);

                // Fetch credit report using the outer scaffold context
                final report = await api.fetchCreditReport(pan);
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Credit report linked! Score: ${report['credit_score']}')),
                );

                _loadLoansData();
              } catch (e) {
                if (!dialogCtx.mounted) return;
                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loans & Credit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLoansData,
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : !hasLinkedCredit
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.credit_card, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No credit data linked'),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _showLinkCreditDialog,
                        icon: const Icon(Icons.link),
                        label: const Text('Link Credit Report'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Credit Summary Card
                      Card(
                        color: Colors.indigo[50],
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Credit Score', style: TextStyle(fontSize: 16)),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${creditSummary!['credit_score'] ?? 'N/A'}',
                                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const Icon(Icons.credit_score, size: 64, color: Colors.indigo),
                                ],
                              ),
                              const Divider(height: 32),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildSummaryItem('Active Loans', '${creditSummary!['active_loans']}'),
                                  _buildSummaryItem('Monthly EMI', '₹${creditSummary!['total_monthly_emi'].toStringAsFixed(0)}'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Outstanding Amount
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.account_balance, color: Colors.red),
                          title: const Text('Total Outstanding'),
                          trailing: Text(
                            '₹${creditSummary!['total_outstanding'].toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Loans List
                      const Text(
                        'Your Loans',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      
                      if (loans.isEmpty)
                        const Center(child: Text('No loans found'))
                      else
                        ...loans.map((loan) => Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ExpansionTile(
                                leading: Icon(
                                  loan['status'] == 'open' ? Icons.credit_card : Icons.check_circle,
                                  color: loan['status'] == 'open' ? Colors.blue : Colors.green,
                                ),
                                title: Text(
                                  loan['account_type'],
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(loan['lender']),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        _buildLoanDetail('Current Balance', '₹${loan['current_balance'].toStringAsFixed(2)}'),
                                        _buildLoanDetail('Monthly EMI', '₹${loan['emi_amount'].toStringAsFixed(2)}'),
                                        _buildLoanDetail('Interest Rate', '${loan['interest_rate']}%'),
                                        _buildLoanDetail('Status', loan['status'].toString().toUpperCase()),
                                        if (loan['days_past_due'] > 0)
                                          _buildLoanDetail(
                                            'Days Past Due',
                                            '${loan['days_past_due']} days',
                                            isWarning: true,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )),
                    ],
                  ),
                ),
      floatingActionButton: hasLinkedCredit
          ? null
          : FloatingActionButton.extended(
              onPressed: _showLinkCreditDialog,
              icon: const Icon(Icons.link),
              label: const Text('Link Credit'),
            ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLoanDetail(String label, String value, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isWarning ? Colors.red : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
