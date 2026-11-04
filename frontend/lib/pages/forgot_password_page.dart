import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api.dart';
import '../core/theme.dart';

/// Port de src/pages/ForgotPassword.tsx
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _email = TextEditingController();
  String _erro = '';
  String _mensagem = '';
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _erro = '';
      _mensagem = '';
    });

    if (_email.text.trim().isEmpty) {
      setState(() => _erro = 'Informe seu e-mail.');
      return;
    }

    setState(() => _loading = true);

    try {
      final res = await api.post(
        '/auth/esqueci-senha',
        data: {'email': _email.text.trim()},
      );
      final data = asMap(res.data);
      if (mounted) setState(() => _mensagem = '${data['message'] ?? ''}');
    } catch (e) {
      if (mounted) {
        setState(
          () => _erro =
              apiErrorMessage(e) ?? 'Não foi possível solicitar a redefinição.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SplitLayout(
      eyebrow: 'ACESSO SEGURO',
      heading: 'Retome o controle da sua fazenda',
      text: 'Enviaremos um link de uso único para proteger sua conta e seus dados.',
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.asset(
            'assets/logo.png',
            width: 80,
            alignment: Alignment.centerLeft,
          ),
          const SizedBox(height: 32),
          const Text(
            'Redefinir senha',
            style: TextStyle(
              fontSize: 30,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Digite o e-mail da sua conta para receber um link seguro.',
            style: TextStyle(
              fontSize: 14,
              height: 1.43,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 32),
          AutofillGroup(
            child: _Campo(
              label: 'E-mail',
              controller: _email,
              hint: 'Insira seu e-mail',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              onSubmitted: (_) => _handleSubmit(),
            ),
          ),
          if (_erro.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _erro,
              style: const TextStyle(fontSize: 14, color: Color(0xFFDC2626)),
            ),
          ],
          if (_mensagem.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _mensagem,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.625,
                  color: Color(0xFF166534),
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          _BotaoVerde(
            label: _loading ? 'Enviando...' : 'Enviar link',
            onPressed: _loading ? null : _handleSubmit,
          ),
          const SizedBox(height: 20),
          _LinkVoltar(onTap: () => context.go('/login')),
        ],
      ),
    );
  }
}

/// Layout dividido: formulário (#F8F8F8) e painel verde (#1F5B3A).
/// Empilhado no celular (flex-col) e lado a lado a partir de lg (1024px).
class _SplitLayout extends StatelessWidget {
  const _SplitLayout({
    required this.eyebrow,
    required this.heading,
    required this.text,
    required this.form,
  });

  final String eyebrow;
  final String heading;
  final String text;
  final Widget form;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final lg = w >= 1024;
    final xl = w >= 1280;

    final formSection = Container(
      color: AgroColors.authBg,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 384),
        child: form,
      ),
    );

    final texto = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 448),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              eyebrow,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: Color(0xFFA9E7AF),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              heading,
              style: TextStyle(
                fontSize: xl ? 48 : (lg ? 36 : 30),
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              text,
              style: TextStyle(
                fontSize: lg ? 16 : 14,
                height: 1.625,
                color: Colors.white.withValues(alpha: .9),
              ),
            ),
          ],
        ),
      ),
    );

    final imagem = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 512),
      child: Image.asset(
        'assets/notebook.png',
        width: double.infinity,
        fit: BoxFit.contain,
      ),
    );

    if (lg) {
      return Scaffold(
        backgroundColor: AgroColors.authBg,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.sizeOf(context).height,
                  ),
                  child: formSection,
                ),
              ),
            ),
            Expanded(
              child: Container(
                color: AgroColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 48,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    texto,
                    const SizedBox(height: 32),
                    Flexible(child: Center(child: imagem)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AgroColors.authBg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.sizeOf(context).height / 2,
              ),
              child: formSection,
            ),
            Container(
              color: AgroColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Column(
                children: [texto, const SizedBox(height: 32), imagem],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Input h-12, rounded-md, bg #EFF2EE, foco com anel #1F5B3A/30.
class _Campo extends StatelessWidget {
  const _Campo({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.autofillHints,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final semBorda = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: Colors.transparent),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, color: AgroColors.primary),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 48,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            autofillHints: autofillHints,
            onSubmitted: onSubmitted,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFEFF2EE),
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: semBorda,
              enabledBorder: semBorda,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: AgroColors.primary.withValues(alpha: .3),
                  width: 2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Botão h-12 rounded-md bg #1F5B3A, text-base font-semibold.
class _BotaoVerde extends StatelessWidget {
  const _BotaoVerde({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    width: double.infinity,
    child: FilledButton(
      onPressed: onPressed,
      style:
          FilledButton.styleFrom(
            backgroundColor: AgroColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AgroColors.primary.withValues(alpha: .6),
            disabledForegroundColor: Colors.white.withValues(alpha: .6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ).copyWith(
            overlayColor: WidgetStatePropertyAll(
              Colors.white.withValues(alpha: .1),
            ),
          ),
      child: Text(label),
    ),
  );
}

class _LinkVoltar extends StatelessWidget {
  const _LinkVoltar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: AgroColors.primary,
      minimumSize: const Size(double.infinity, 44),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    child: const Text('Voltar para o login'),
  );
}
