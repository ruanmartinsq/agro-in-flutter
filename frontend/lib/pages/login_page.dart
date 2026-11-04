import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../widgets/auth_layout.dart';
import '../widgets/common.dart';

/// Port de src/pages/Login.tsx
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  String _erro = '';
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _erro = '');
    if (_email.text.isEmpty || _senha.text.isEmpty) {
      setState(() => _erro = 'Preencha todos os campos.');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await api.post(
        '/auth/login',
        data: {'email': _email.text, 'senha': _senha.text},
      );
      await Storage.setToken('${res.data['token']}');
      if (mounted) context.go('/dashboard');
    } catch (e) {
      setState(() => _erro = apiErrorMessage(e) ?? 'Erro ao fazer login.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Bem-Vindo de Volta!',
      description: 'Entre com suas credenciais para acessar sua conta',
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthField(
              label: 'E-mail',
              controller: _email,
              hint: 'Insira seu e-mail',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 20),
            AuthField(
              label: 'Senha',
              controller: _senha,
              hint: 'Insira sua senha',
              obscure: true,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _handleLogin(),
            ),
            if (_erro.isNotEmpty) ...[
              const SizedBox(height: 20),
              ErrorBanner(_erro),
            ],
            const SizedBox(height: 20),
            AuthButton(
              label: _loading ? 'Entrando...' : 'Login',
              loading: _loading,
              onPressed: _handleLogin,
            ),
            const SizedBox(height: 12),
            Center(
              child: AuthLink(
                label: 'Esqueceu sua senha?',
                onTap: () => context.go('/esqueci-senha'),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Não possui uma conta? ',
                  style: TextStyle(fontSize: 14, color: AgroColors.authText2),
                ),
                AuthLink(label: 'Registre-se', onTap: () => context.go('/')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
