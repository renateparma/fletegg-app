// lib/features/auth/login_page.dart
// Login con teléfono + OTP

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/colors.dart';
import '../../services/firebase_service.dart';
import 'auth_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneCtrl = TextEditingController(text: '+56');
  final _codeCtrl = TextEditingController();
  bool _codigoEnviado = false;
  String? _verificationId;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_shipping, size: 80, color: FleteGGColors.primary),
              const SizedBox(height: 16),
              const Text('FleteGG', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
              const Text('Tu flete en minutos', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),

              if (!_codigoEnviado) ...[
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp / Teléfono',
                    hintText: '+56 9 1234 5678',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _enviarCodigo,
                    child: const Text('ENVIAR CÓDIGO'),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Código de verificación',
                    hintText: '123456',
                    prefixIcon: Icon(Icons.sms),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _verificar,
                    child: const Text('VERIFICAR'),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _codigoEnviado = false),
                  child: const Text('Cambiar número'),
                ),
              ],

              if (_loading) const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _enviarCodigo() async {
    setState(() => _loading = true);
    try {
      _verificationId = await FirebaseService.enviarCodigo(_phoneCtrl.text.trim());
      setState(() {
        _codigoEnviado = true;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _verificar() async {
    setState(() => _loading = true);
    try {
      final cred = await FirebaseService.verificarCodigo(
        _verificationId!,
        _codeCtrl.text.trim(),
      );
      // Auth controller maneja el redirect
      if (mounted) {
        context.read<AuthController>().onLogin(cred.user!);
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Código incorrecto: $e')),
        );
      }
    }
  }
}