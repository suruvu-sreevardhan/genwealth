// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.prefilledMonthlyIncome});

  final double? prefilledMonthlyIncome;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _monthlyIncome = TextEditingController();
  bool _isRegister = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledMonthlyIncome != null) {
      _isRegister = true;
      _monthlyIncome.text = widget.prefilledMonthlyIncome!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _monthlyIncome.dispose();
    super.dispose();
  }

  void _submit() async {
    setState(() => _loading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    Map res;
    if (_isRegister) {
      res = await auth.register(
        _name.text.trim(),
        _email.text.trim(),
        _password.text.trim(),
        monthlyIncome: double.tryParse(_monthlyIncome.text.trim()),
      );
    } else {
      res = await auth.login(_email.text.trim(), _password.text.trim());
    }
    setState(() => _loading = false);
    if (res['error'] != null) {
      _showError(res['error'].toString());
      return;
    }
    if (res['token'] != null || res['user'] != null || res['id'] != null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      _showError('Unexpected response: ${res.toString()}');
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finlit — Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_isRegister)
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
            if (_isRegister) const SizedBox(height: 12),
            if (_isRegister)
              TextField(
                controller: _monthlyIncome,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Monthly Income (optional)'),
              ),
            if (_isRegister) const SizedBox(height: 12),
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(controller: _password, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            const SizedBox(height: 20),
            _loading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _submit, child: Text(_isRegister ? 'Register' : 'Login')),
            TextButton(onPressed: () => setState(() => _isRegister = !_isRegister), child: Text(_isRegister ? 'Have an account? Login' : 'Create new account')),
          ],
        ),
      ),
    );
  }
}
