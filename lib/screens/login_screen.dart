import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _userCtrl   = TextEditingController(text: 'jhon.joe');
  final _senhaCtrl  = TextEditingController(text: 'secret123');
  bool _senhaVisivel = false;
  bool _carregando   = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final username = _userCtrl.text.trim();
    dev.log('LoginScreen: tentando login — usuário: $username', name: 'LoginScreen');

    setState(() => _carregando = true);

    try {
      await AuthService.instance.login(username, _senhaCtrl.text);

      dev.log('LoginScreen: login bem-sucedido — navegando para HomeScreen', name: 'LoginScreen');

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    } on AuthException catch (e) {
      dev.log('LoginScreen: falha no login — ${e.message}', name: 'LoginScreen');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F2),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5C3A),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.delivery_dining,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(height: 32),
              const Text(
                'Bem-vindo de volta',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Entre com sua conta para continuar',
                style: TextStyle(fontSize: 15, color: Color(0xFF8A8A99)),
              ),
              const SizedBox(height: 40),

              // Formulário
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Usuário
                    TextFormField(
                      controller: _userCtrl,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration('Usuário', Icons.person_outline),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Informe o usuário';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Senha
                    TextFormField(
                      controller: _senhaCtrl,
                      obscureText: !_senhaVisivel,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _login(),
                      decoration: _inputDecoration(
                        'Senha',
                        Icons.lock_outline,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _senhaVisivel
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF8A8A99),
                          ),
                          onPressed: () =>
                              setState(() => _senhaVisivel = !_senhaVisivel),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Informe a senha';
                        if (v.length < 4) return 'Senha muito curta';
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Botão entrar
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _carregando ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5C3A),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              const Color(0xFFFF5C3A).withValues(alpha: 0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _carregando
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Entrar',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF8A8A99)),
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: Color(0xFF8A8A99)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEAEAE6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEAEAE6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0xFFFF5C3A), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}
