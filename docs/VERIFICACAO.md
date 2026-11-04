# Verificação local — 04/11/2026

## Validações aprovadas

- Flutter 3.47.8 / Dart 3.13.7 e Node.js 25.9.0.
- `flutter analyze --no-pub`: sem ocorrências.
- `dart format --output=none --set-exit-if-changed lib`: 32 arquivos, nenhuma alteração necessária.
- `flutter build web --release --no-pub --dart-define=API_URL=http://localhost:3333`: compilação concluída.
- Backend instalado com `npm ci --ignore-scripts`, Prisma Client gerado e `tsc --noEmit` aprovado.
- Quatro migrations aplicadas com sucesso em PostgreSQL 18 local e isolado, na porta 55432, sem usar dados ou credenciais de bancos existentes.
- 37 verificações HTTP aprovadas com API real e banco temporário: identificação do serviço, healthcheck, cadastro, login, perfil, rejeição de senha incorreta e de acesso sem token; criação, consulta, edição e exclusão de propriedade, financeiro, produção, estoque e metas; relatório, capacidades do assistente e da análise foliar e listagens de análises, quarentenas e vistorias.

## Segurança do versionamento

- Revisão dos arquivos candidatos: nenhuma credencial real encontrada; `.env.example` contém somente valores ilustrativos.
- Gitleaks 8.30.1 executado no conteúdo preparado para commit: nenhum segredo detectado, sem desabilitar regras ou suprimir resultados.
- `.gitignore` exclui ambientes locais, dependências, builds, logs, caches, dados de validação, certificados e arquivos de assinatura.
- Banco temporário, credenciais geradas em memória e logs de teste ficam fora do versionamento.
- Não há histórico anterior de commits neste projeto.

## Limites da validação

- A instalação de plugins Flutter exige suporte a links simbólicos no Windows; o comando que resolve as dependências apresentou esse aviso. A análise e o build Web passaram usando `--no-pub` após a resolução das dependências.
- A primeira inicialização da API excedeu o tempo limite enquanto o build Web estava em andamento; com a compilação encerrada, os testes passaram.
- Não foi possível testar visualmente o aplicativo: o serviço de automação de navegador estava indisponível na sessão.
- Android/APK, iOS e Windows não foram compilados ou testados nesta verificação.
- Envio de e-mail, respostas de IA, reconhecimento por provedores externos, GPS, câmera e impressão não foram testados. As integrações externas exigem configuração própria.
- O build Web validado usa API local. Para publicar o aplicativo, compile novamente com o endereço da API de destino em `API_URL`.

## Repositório

Destino: `ruanmartinsq/agro-in-flutter`, privado. Os resultados acima documentam os testes locais, sem equivaler a uma validação de produção.
