import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/auth_layout.dart';
import '../widgets/common.dart';

/// Port de src/pages/Register.tsx
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  String _erro = '';
  bool _loading = false;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    setState(() => _erro = '');

    if (_nome.text.isEmpty || _email.text.isEmpty || _senha.text.isEmpty) {
      setState(() => _erro = 'Preencha todos os campos.');
      return;
    }

    setState(() => _loading = true);
    try {
      await api.post(
        '/auth/register',
        data: {'nome': _nome.text, 'email': _email.text, 'senha': _senha.text},
      );
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        setState(() => _erro = apiErrorMessage(e) ?? 'Erro ao registrar.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Comece agora!',
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthField(
              label: 'Nome',
              controller: _nome,
              hint: 'Insira seu nome',
              keyboardType: TextInputType.name,
              autofillHints: const [AutofillHints.name],
            ),
            const SizedBox(height: 20),
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
              autofillHints: const [AutofillHints.newPassword],
              onSubmitted: (_) => _handleRegister(),
            ),
            if (_erro.isNotEmpty) ...[
              const SizedBox(height: 20),
              ErrorBanner(_erro),
            ],
            const SizedBox(height: 20),
            AuthButton(
              label: _loading ? 'Registrando...' : 'Registrar',
              loading: _loading,
              onPressed: _handleRegister,
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Já possui uma conta? ',
                  style: TextStyle(fontSize: 14, color: AgroColors.authText2),
                ),
                AuthLink(label: 'Entre', onTap: () => context.go('/login')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
