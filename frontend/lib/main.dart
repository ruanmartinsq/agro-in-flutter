import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/storage.dart';
import 'core/theme.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // URLs sem "#" na web (/login, /dashboard...), como no React.
  await initializeDateFormatting('pt_BR');
  await Storage.init();
  runApp(const AgroInApp());
}

class AgroInApp extends StatelessWidget {
  const AgroInApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Agro.in',
      debugShowCheckedModeBanner: false,
      theme: buildAgroTheme(),
      routerConfig: appRouter,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
