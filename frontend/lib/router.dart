import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'pages/analise_foliar_page.dart';
import 'pages/assistente_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/estoque_page.dart';
import 'pages/financeiro_page.dart';
import 'pages/forgot_password_page.dart';
import 'pages/login_page.dart';
import 'pages/metas_page.dart';
import 'pages/perfil_page.dart';
import 'pages/producao_page.dart';
import 'pages/propriedade_page.dart';
import 'pages/quarentenas_foliares_page.dart';
import 'pages/register_page.dart';
import 'pages/relatorios_page.dart';
import 'pages/reset_password_page.dart';
import 'pages/vistorias_foliares_page.dart';
import 'widgets/app_shell.dart';

/// Mesmas rotas do App.tsx (react-router-dom).
/// As páginas internas ficam dentro do [AppShell] (sidebar + cabeçalho mobile).
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, _) => const RegisterPage()),
    GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
    GoRoute(
      path: '/esqueci-senha',
      builder: (_, _) => const ForgotPasswordPage(),
    ),
    GoRoute(
      path: '/redefinir-senha',
      builder: (_, state) =>
          ResetPasswordPage(token: state.uri.queryParameters['token']),
    ),
    ShellRoute(
      builder: (_, _, child) => AppShell(child: child),
      routes: [
        _r('/dashboard', const DashboardPage()),
        _r('/estoque', const EstoquePage()),
        _r('/propriedade', const PropriedadePage()),
        _r('/financeiro', const FinanceiroPage()),
        _r('/meta', const MetasPage()),
        _r('/producao', const ProducaoPage()),
        _r('/relatorios', const RelatoriosPage()),
        _r('/perfil', const PerfilPage()),
        GoRoute(
          path: '/analise-foliar',
          pageBuilder: (_, state) => NoTransitionPage(
            key: state.pageKey,
            child: const AnaliseFoliarPage(),
          ),
          routes: [
            GoRoute(
              path: 'quarentenas',
              pageBuilder: (_, state) => NoTransitionPage(
                key: state.pageKey,
                child: const QuarentenasFoliaresPage(),
              ),
            ),
            GoRoute(
              path: 'vistorias',
              pageBuilder: (_, state) => NoTransitionPage(
                key: state.pageKey,
                child: const VistoriasFoliaresPage(),
              ),
            ),
          ],
        ),
        _r('/assistente', const AssistentePage()),
      ],
    ),
  ],
);

GoRoute _r(String path, Widget page) => GoRoute(
  path: path,
  pageBuilder: (_, state) => NoTransitionPage(key: state.pageKey, child: page),
);
