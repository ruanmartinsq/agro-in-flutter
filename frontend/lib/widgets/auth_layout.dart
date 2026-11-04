import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Port de src/components/AuthLayout.tsx — formulário à esquerda e,
/// em telas largas (>= 1024px), painel verde com o notebook à direita.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    this.description,
    required this.child,
  });

  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final largo = MediaQuery.sizeOf(context).width >= 1024;

    final form = Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: largo ? 48 : 24,
          vertical: 40,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 384),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOut,
            builder: (_, t, c) => Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 6 * (1 - t)),
                child: c,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset('assets/logo.png', width: 80, height: 80),
                SizedBox(height: largo ? 32 : 28),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                    color: Color(0xFF111111),
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    description!,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.7,
                      color: AgroColors.authMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                child,
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AgroColors.authBg,
      body: largo
          ? Row(
              children: [
                Expanded(child: form),
                Expanded(child: _PainelLateral()),
              ],
            )
          : SafeArea(child: form),
    );
  }
}

class _PainelLateral extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.sizeOf(context).width;
    final altura = MediaQuery.sizeOf(context).height;
    final xl = largura >= 1280;
    return Container(
      color: AgroColors.authGreen,
      padding: EdgeInsets.fromLTRB(xl ? 56 : 40, 48, xl ? 56 : 40, 20),
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 512),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TUDO EM UM SÓ LUGAR',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.2,
                    color: AgroColors.authAccent,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Conheça o melhor software de gestão de fazendas',
                  style: TextStyle(
                    fontSize: xl ? 48 : 36,
                    height: 1.17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.4,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'O Agro.in é um sistema que ajuda a gerenciar as atividades da fazenda, desde a operação até o controle de máquinas.',
                  style: TextStyle(
                    fontSize: xl ? 16 : 14,
                    height: xl ? 1.75 : 1.7,
                    color: Colors.white.withValues(alpha: .88),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: altura * .52),
            child: FractionallySizedBox(
              widthFactor: .94,
              child: Image.asset('assets/notebook.png', fit: BoxFit.contain),
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de texto das telas de autenticação (fundo #E4E4E4, foco verde).
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AgroColors.authGreen,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 48,
          child: _FocusFill(
            builder: (focused) => TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              autofillHints: autofillHints,
              onSubmitted: onSubmitted,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: focused ? Colors.white : AgroColors.authInput,
                hintText: hint,
                hintStyle: const TextStyle(
                  color: AgroColors.authPlaceholder,
                  fontSize: 14,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Colors.transparent),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Colors.transparent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AgroColors.authFocus),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FocusFill extends StatefulWidget {
  const _FocusFill({required this.builder});
  final Widget Function(bool focused) builder;

  @override
  State<_FocusFill> createState() => _FocusFillState();
}

class _FocusFillState extends State<_FocusFill> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => Focus(
    onFocusChange: (f) => setState(() => _focused = f),
    child: widget.builder(_focused),
  );
}

/// Botão principal das telas de autenticação (verde #0D5006, altura 48).
class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style:
            FilledButton.styleFrom(
              backgroundColor: AgroColors.authGreen,
              disabledBackgroundColor: AgroColors.authGreen.withValues(
                alpha: .6,
              ),
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ).copyWith(
              overlayColor: WidgetStatePropertyAll(
                AgroColors.authGreenHover.withValues(alpha: .4),
              ),
            ),
        child: Text(label),
      ),
    );
  }
}

/// Link de texto verde (ex.: "Esqueceu sua senha?").
class AuthLink extends StatelessWidget {
  const AuthLink({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: AgroColors.authGreen,
      minimumSize: const Size(0, 44),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    child: Text(label),
  );
}
