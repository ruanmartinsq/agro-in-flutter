# Agro.in — Front-end Flutter

Versão Flutter do front-end do Agro.in (antes React + Vite + Tailwind).
Mesmas telas, rotas, textos, cores e formas; consome o **mesmo back-end** (`../backend`) sem nenhuma alteração.

## Requisitos

- Flutter 3.47+ com Dart 3.13.7+ (SDK local: Flutter 3.47.8)
- Back-end rodando (`cd ../backend && npm install && npm run dev` — porta 3333)

## Executar

```bash
flutter pub get
flutter run -d chrome --dart-define=API_URL=http://localhost:3333
```

- `API_URL` substitui o antigo `VITE_API_URL`.
- Emulador Android: use `--dart-define=API_URL=http://10.0.2.2:3333`.
- Windows: `flutter run -d windows --dart-define=API_URL=http://localhost:3333`.

## Build web (Vercel)

```bash
flutter build web --release --dart-define=API_URL=https://sua-api.com
```

O conteúdo vai para `build/web`. O `web/vercel.json` (copiado para o build) mantém o rewrite para `index.html`, assim as rotas `/login`, `/dashboard`, `/redefinir-senha?token=...` funcionam direto pela URL.

## Estrutura

```
lib/
  main.dart                 # inicialização, tema, localização pt-BR
  router.dart               # rotas (equivalente ao App.tsx)
  core/
    theme.dart              # paleta (index.css + classes Tailwind)
    api.dart                # cliente HTTP (Dio) com token Bearer — equivalente ao lib/api.ts
    storage.dart            # substitui o localStorage (shared_preferences)
    format.dart             # moeda/datas pt-BR
    relatorios.dart         # hooks/relatorios.ts
  widgets/
    app_shell.dart          # Sidebar + cabeçalho mobile
    auth_layout.dart        # AuthLayout
    analise_foliar_nav.dart # AnaliseFoliarNav
    foto_analise_protegida.dart
    common.dart             # botões, campos, modais, cabeçalhos de página
  pages/                    # uma página por tela do React
```

## Correspondência de telas

| Rota | React | Flutter |
|---|---|---|
| `/` | Register.tsx | register_page.dart |
| `/login` | Login.tsx | login_page.dart |
| `/esqueci-senha` | ForgotPassword.tsx | forgot_password_page.dart |
| `/redefinir-senha` | ResetPassword.tsx | reset_password_page.dart |
| `/dashboard` | Dashboard.tsx | dashboard_page.dart |
| `/propriedade` | Propriedade.tsx | propriedade_page.dart |
| `/financeiro` | Financeiro.tsx | financeiro_page.dart |
| `/producao` | Producao.tsx | producao_page.dart |
| `/estoque` | Estoque.tsx | estoque_page.dart |
| `/meta` | Metas.tsx | metas_page.dart |
| `/relatorios` | Relatorios.tsx | relatorios_page.dart |
| `/perfil` | Perfil.tsx | perfil_page.dart |
| `/analise-foliar` | AnaliseFoliar.tsx | analise_foliar_page.dart |
| `/analise-foliar/quarentenas` | QuarentenasFoliares.tsx | quarentenas_foliares_page.dart |
| `/analise-foliar/vistorias` | VistoriasFoliares.tsx | vistorias_foliares_page.dart |
| `/assistente` | Assistente.tsx | assistente_page.dart |
