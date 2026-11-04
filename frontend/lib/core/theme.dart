import 'package:flutter/material.dart';

/// Paleta do Agro.in — mesmas cores do front-end React (index.css + classes Tailwind).
class AgroColors {
  AgroColors._();

  // Tokens do :root (index.css)
  static const pine = Color(0xFF163B2A);
  static const primary = Color(0xFF1F5B3A);
  static const primaryHover = Color(0xFF17482F);
  static const mint = Color(0xFF9AE6A6);
  static const canvas = Color(0xFFF5F6F2);
  static const surfaceMuted = Color(0xFFF2F5F0);
  static const border = Color(0xFFE1E6DF);
  static const text = Color(0xFF25352B);
  static const muted = Color(0xFF647269);

  // Sidebar / cabeçalhos
  static const sidebar = Color(0xFF0F5317);
  static const sidebarActiveBorder = Color(0xFF82DF91);
  static const headerTitle = Color(0xFF83E092);
  static const sidebarSubtitle = Color(0xFF9AC9A3);
  static const assistantBorder = Color(0xFF58AC63);
  static const assistantActiveText = Color(0xFF153F29);
  static const overlay = Color(0x99071C0D);

  // Auth
  static const authBg = Color(0xFFF8F8F8);
  static const authGreen = Color(0xFF0D5006);
  static const authGreenHover = Color(0xFF0A4205);
  static const authAccent = Color(0xFF48F36B);
  static const authInput = Color(0xFFE4E4E4);
  static const authFocus = Color(0xFF4D8758);
  static const authPlaceholder = Color(0xFF89918A);
  static const authMuted = Color(0xFF6B746D);
  static const authText2 = Color(0xFF454B46);

  // Cards
  static const cardBorder = Color(0xFFD8E0D8);
  static const cardDivider = Color(0xFFEFF3ED);
  static const chevron = Color(0xFF9DAA9F);
  static const emptyBorder = Color(0xFFC7D5C7);
  static const emptyHover = Color(0xFFEDF3EC);
  static const badgeBg = Color(0xFFE8F3EA);
  static const track = Color(0xFFE4E9E3);
  static const text2 = Color(0xFF46564B);

  // Erro
  static const errorBorder = Color(0xFFE8B9AB);
  static const errorBg = Color(0xFFFFF1EC);
  static const errorText = Color(0xFF9B442C);

  // Acentos do dashboard
  static const accentPropriedade = Color(0xFF2C7A3D);
  static const accentFinanceiro = Color(0xFF4D98BC);
  static const accentProducao = Color(0xFFC8A229);
  static const accentEstoque = Color(0xFF956437);
  static const accentMetas = Color(0xFFB64C35);
  static const accentRelatorios = Color(0xFF617665);
}

/// Converte "#RRGGBB" (como aparece no código React) em Color.
/// Ex.: hex('#1F5B3A'), hex('#1F5B3A', .5)
Color hex(String h, [double opacity = 1]) {
  var s = h.replaceAll('#', '');
  if (s.length == 3) s = s.split('').map((c) => '$c$c').join();
  return Color(int.parse('FF$s', radix: 16)).withValues(alpha: opacity);
}

/// Fonte do título das páginas (Montserrat no React; cai para a fonte padrão se ausente).
const kTitleFont = 'Montserrat';

ThemeData buildAgroTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AgroColors.primary,
      primary: AgroColors.primary,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: AgroColors.canvas,
    fontFamily: 'Segoe UI',
    fontFamilyFallback: const ['Aptos', 'Segoe UI', 'Roboto', 'Arial'],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AgroColors.text,
      displayColor: AgroColors.text,
    ),
    inputDecorationTheme: agroInputTheme(),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AgroColors.primary,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AgroColors.pine,
    ),
  );
}

InputDecorationTheme agroInputTheme() => InputDecorationTheme(
  isDense: true,
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  hintStyle: const TextStyle(color: Color(0xFF9DAA9F), fontSize: 14),
  labelStyle: const TextStyle(color: AgroColors.muted, fontSize: 13),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AgroColors.border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AgroColors.border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AgroColors.primary, width: 1.5),
  ),
);
