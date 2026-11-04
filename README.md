# AGRO.IN — Flutter

Sistema de gestão de propriedades rurais com aplicativo Flutter e API em Node.js, TypeScript, Fastify, Prisma e PostgreSQL.

O aplicativo inclui cadastro e login, painel de indicadores, propriedades, financeiro, produção, estoque, metas, relatórios, análise foliar e assistente rural. As integrações de e-mail e inteligência artificial dependem de configuração própria.

## Estrutura

- `frontend/`: aplicativo Flutter para Web, Android, iOS e Windows.
- `backend/`: API, schema Prisma e migrations do PostgreSQL.
- `docs/`: documentação do assistente e da análise foliar.

## Requisitos

- Flutter 3.47 ou superior com Dart 3.13.7 ou superior (SDK local: Flutter 3.47.8).
- Node.js 22 ou superior e npm.
- PostgreSQL e um banco de desenvolvimento.

No Windows, plugins Flutter também exigem suporte a links simbólicos; o SDK informa quando é necessário habilitar o Modo de Desenvolvedor nas configurações do sistema.

## Executar a API

Na pasta `backend`, copie `.env.example` para `.env`. Ajuste `DATABASE_URL` para seu banco e substitua `JWT_SECRET` por um segredo aleatório. As chaves dos provedores externos são configuradas nesse mesmo arquivo.

```bash
cd backend
npm ci --ignore-scripts
npx prisma generate
npx prisma migrate deploy
npm run dev
```

O passo `migrate deploy` aplica as migrations ao banco informado; use um banco de desenvolvimento. A instalação usa `--ignore-scripts` porque o `postinstall` existente também executa migrations automaticamente.

A API atende em `http://localhost:3333`. O endpoint `/` identifica o serviço; `/health` verifica também a conexão com o banco.

## Executar o aplicativo

Em outro terminal:

```bash
cd frontend
flutter pub get
flutter run -d chrome --web-port=8080 --dart-define=API_URL=http://localhost:3333
```

No emulador Android, use `http://10.0.2.2:3333` em `API_URL`. Em um aparelho físico, use o endereço de rede da máquina que executa a API.

## Validar e compilar

```bash
cd frontend
flutter analyze
dart format --output=none --set-exit-if-changed lib
flutter build web --release --dart-define=API_URL=https://sua-api.example.com
```

A compilação Web é gerada em `frontend/build/web`. O endereço da API é definido durante a compilação. Para validar o backend após instalar suas dependências e gerar o Prisma Client, execute `npx tsc --noEmit` na pasta `backend`.

O funcionamento integrado exige API e PostgreSQL ativos. Compilar o aplicativo, isoladamente, não valida login, operações no banco, envio de e-mail ou provedores de IA.

## Documentação

- [Aplicativo Flutter](frontend/README.md)
- [Backend](backend/README.md)
- [Assistente IA](docs/ASSISTENTE_IA.md)
- [Análise foliar](docs/ANALISE_FOLIAR.md)

Arquivos `.env`, caches, dependências, builds e logs locais são excluídos do Git. Apenas `.env.example`, sem credenciais reais, deve ser versionado.
