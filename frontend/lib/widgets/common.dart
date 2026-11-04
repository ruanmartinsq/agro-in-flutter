import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Peças visuais reutilizadas pelas páginas internas (equivalentes às classes Tailwind repetidas no React).

/// Cabeçalho verde das páginas internas:
/// `<header className="px-4 pb-6 pt-6 sm:px-6 sm:pt-8 lg:px-10" style={{ background: "#1F5B3A" }}>`
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.actions = const [],
    this.background = AgroColors.primary,
    this.titleColor = Colors.white,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final List<Widget> actions;
  final Color background;
  final Color titleColor;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final hPad = w >= 1024 ? 40.0 : (w >= 640 ? 24.0 : 16.0);
    final sm = w >= 640;

    final titulo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: kTitleFont,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: titleColor,
          ),
        ),
        if (subtitleWidget != null) ...[
          const SizedBox(height: 6),
          subtitleWidget!,
        ] else if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: .65),
            ),
          ),
        ],
      ],
    );

    return Container(
      width: double.infinity,
      color: background,
      padding: EdgeInsets.fromLTRB(hPad, sm ? 32 : 24, hPad, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (actions.isEmpty)
            titulo
          else if (sm)
            Row(
              children: [
                Expanded(child: titulo),
                const SizedBox(width: 16),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            )
          else ...[
            titulo,
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
          if (bottom != null) ...[const SizedBox(height: 16), bottom!],
        ],
      ),
    );
  }
}

/// Padding horizontal padrão do conteúdo (px-4 sm:px-6 lg:px-10).
EdgeInsets pagePadding(
  BuildContext context, {
  double top = 20,
  double bottom = 28,
}) {
  final w = MediaQuery.sizeOf(context).width;
  final h = w >= 1024 ? 40.0 : (w >= 640 ? 24.0 : 16.0);
  return EdgeInsets.fromLTRB(h, top, h, bottom);
}

/// Mensagem de erro (borda #E8B9AB, fundo #FFF1EC, texto #9B442C).
class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AgroColors.errorBg,
      border: Border.all(color: AgroColors.errorBorder),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      message,
      style: const TextStyle(fontSize: 12, color: AgroColors.errorText),
    ),
  );
}

/// Mensagem de sucesso (verde suave).
class SuccessBanner extends StatelessWidget {
  const SuccessBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFEDF7EE),
      border: Border.all(color: const Color(0xFFB9DDBF)),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      message,
      style: const TextStyle(fontSize: 12, color: AgroColors.primary),
    ),
  );
}

/// Botão verde primário (bg #1F5B3A, hover #17482F).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.background = AgroColors.primary,
    this.foreground = Colors.white,
    this.height = 40,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final Color background;
  final Color foreground;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final btn = FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: background.withValues(alpha: .6),
        disabledForegroundColor: foreground.withValues(alpha: .9),
        minimumSize: Size(0, height),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foreground,
              ),
            )
          else if (icon != null)
            Icon(icon, size: 16),
          if (loading || icon != null) const SizedBox(width: 8),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// Botão com borda (secundário).
class OutlineButtonAgro extends StatelessWidget {
  const OutlineButtonAgro({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AgroColors.primary,
    this.borderColor = AgroColors.emptyBorder,
    this.background = Colors.white,
    this.height = 40,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final Color borderColor;
  final Color background;
  final double height;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: color,
      backgroundColor: background,
      side: BorderSide(color: borderColor),
      minimumSize: Size(0, height),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 15), const SizedBox(width: 6)],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    ),
  );
}

/// Cartão branco com borda #E1E6DF e cantos de 8–12px.
class AgroCard extends StatelessWidget {
  const AgroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 10,
    this.borderColor = AgroColors.border,
    this.color = Colors.white,
    this.shadow = true,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color borderColor;
  final Color color;
  final bool shadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: shadow
            ? const [
                BoxShadow(
                  color: Color(0x0F1A301F),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(radius),
                onTap: onTap,
                child: content,
              ),
            ),
    );
  }
}

/// Rótulo de campo de formulário (text-xs/sm font-medium #46564B).
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AgroColors.text2,
      ),
    ),
  );
}

/// Campo de formulário com rótulo acima.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.obscure = false,
    this.readOnly = false,
    this.onTap,
    this.suffix,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool obscure;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      FieldLabel(label),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        obscureText: obscure,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: AgroColors.text),
        decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
      ),
    ],
  );
}

/// Select (dropdown) com rótulo acima.
class LabeledDropdown<T> extends StatelessWidget {
  const LabeledDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      FieldLabel(label),
      DropdownButtonFormField<T>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        isExpanded: true,
        hint: hint == null
            ? null
            : Text(hint!, style: const TextStyle(fontSize: 14)),
        style: const TextStyle(fontSize: 14, color: AgroColors.text),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
    ],
  );
}

/// Campo de data (abre o seletor de data). [value] no formato yyyy-MM-dd.
class LabeledDateField extends StatelessWidget {
  const LabeledDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(label),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(1990),
              lastDate: DateTime(2100),
              locale: const Locale('pt', 'BR'),
            );
            if (d != null) onChanged(d);
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              suffixIcon: Icon(Icons.calendar_today_outlined, size: 16),
            ),
            child: Text(
              value == null ? 'dd/mm/aaaa' : fmt(value!),
              style: TextStyle(
                fontSize: 14,
                color: value == null
                    ? const Color(0xFF9DAA9F)
                    : AgroColors.text,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Modal padrão — equivalente ao `<div className="fixed inset-0 ... bg rgba(0,0,0,.4)">` com
/// cartão branco central (max-w-md, rounded-xl).
Future<T?> showAgroModal<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Widget Function(BuildContext context, StateSetter setState) builder,
  double maxWidth = 448,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .4),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AgroColors.text,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AgroColors.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: AgroColors.muted,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                builder(ctx, setState),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Confirmação simples (substitui window.confirm).
Future<bool> confirmar(
  BuildContext context,
  String mensagem, {
  String confirmar = 'Excluir',
  String titulo = 'Confirmar',
}) async {
  final r = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .4),
    builder: (ctx) => AlertDialog(
      title: Text(
        titulo,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      content: Text(
        mensagem,
        style: const TextStyle(fontSize: 14, color: AgroColors.text2),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AgroColors.accentMetas,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmar),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Toast/aviso rápido (substitui alert()).
void avisar(BuildContext context, String mensagem) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensagem)));
}

/// Estado de carregamento centralizado ("Carregando ...").
class LoadingView extends StatelessWidget {
  const LoadingView(this.texto, {super.key});
  final String texto;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 14, color: AgroColors.muted),
      ),
    ),
  );
}

/// Pílula/badge colorida.
class Pill extends StatelessWidget {
  const Pill(
    this.text, {
    super.key,
    this.background = AgroColors.badgeBg,
    this.color = AgroColors.primary,
  });
  final String text;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
    ),
  );
}

/// Grade responsiva: 1 coluna no celular, [md] colunas >= 768px, [xl] colunas >= 1280px.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.sm = 1,
    this.md = 2,
    this.lg,
    this.xl = 3,
    this.spacing = 16,
  });

  final List<Widget> children;
  final int sm, md, xl;
  final int? lg;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = MediaQuery.sizeOf(context).width;
        final cols = w >= 1280
            ? xl
            : (w >= 1024 ? (lg ?? md) : (w >= 768 ? md : (w >= 640 ? sm : 1)));
        final itemW = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final ch in children) SizedBox(width: itemW, child: ch),
          ],
        );
      },
    );
  }
}
