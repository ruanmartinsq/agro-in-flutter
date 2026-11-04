# Módulo de análise foliar

## Estado implementado

O Agro.in agora possui um fluxo mobile de captura, pré-processamento, triagem,
histórico e feedback. A foto passa pelas seguintes etapas:

1. validação de formato, tamanho e resolução;
2. correção de orientação e compressão sem metadados;
3. avaliação aproximada de luz, contraste, foco e presença de tecido vegetal;
4. leitura de proporções visuais verde, amarela, marrom e escura;
5. classificação local conservadora ou chamada do provedor especializado;
6. geração de hipóteses, perguntas de confirmação e recomendações;
7. armazenamento privado da miniatura e do resultado;
8. feedback do usuário e registro de eventual diagnóstico confirmado.
9. quarentena com plano de tratamento, próxima revisão e comparação temporal;
10. vistoria de área por pontos com posição, precisão GPS e repetição da captura.

A implementação local nunca afirma identificar fungo, bactéria, vírus ou espécie.
Ela informa apenas padrões visuais. Quando a variável `PLANTNET_API_KEY` está
configurada, o backend envia a imagem comprimida ao Pl@ntNet Diseases e normaliza
as três hipóteses mais prováveis. A chave fica somente no servidor.

O Pl@ntNet é o provedor primário. O `crop.health` continua disponível como
contingência quando sua chave também estiver configurada. Se os provedores
falharem, esgotarem a cota ou retornarem confiança abaixo do limiar conservador,
a análise continua com a triagem visual local e informa o fallback ao usuário.

## Limite agronômico essencial

Uma fotografia RGB de uma folha pode levantar hipóteses de clorose, necrose,
doença ou estresse. Ela não mede N, P, K, pH, matéria orgânica ou fertilidade do
solo. Sintomas parecidos podem ser produzidos por água, raiz, fitotoxicidade,
doença e diferentes deficiências.

A própria Embrapa descreve a diagnose foliar como análise química de tecido
coletado de forma padronizada e recomenda interpretá-la junto com análise de
solo, histórico, cultura e condições da lavoura:

- [Diagnose foliar — Embrapa](https://www.embrapa.br/en/web/agencia-de-informacao-tecnologica/cultivos/cenoura/producao/manejo-do-solo/analise-do-solo/adubacao-e-nutricao/diagnose-foliar)
- [Análise foliar em milho — Embrapa](https://www.embrapa.br/en/web/agencia-de-informacao-tecnologica/cultivos/milho/producao/manejo-do-solo-e-adubacao/adubacao-e-fertilidade-do-solo/diagnose-foliar)
- [Análise foliar em pimenta — Embrapa](https://www.embrapa.br/en/web/agencia-de-informacao-tecnologica/cultivos/pimenta/producao/manejo-do-solo/analise-foliar)

Por isso, o produto usa o termo **hipótese visual de estresse nutricional** e não
“estimativa do solo”. Dose de fertilizante ou defensivo não deve ser gerada
automaticamente.

## Quarentena e comparação temporal

Uma análise individual pode iniciar uma quarentena. O caso preserva a foto
inicial, cultura, propriedade, tratamento informado e data da próxima revisão.
Cada nova foto fica na mesma linha do tempo e é comparada à anterior por variação
dos tecidos verde, amarelado, marrom e escuro.

O resultado da comparação é um dos estados `melhora_visual`, `estavel`,
`piora_visual` ou `inconclusivo`. Ele não representa confirmação de cura. Para
reduzir variações artificiais, o app orienta repetir a mesma planta ou folhas de
idade semelhante, enquadramento e iluminação.

O encerramento mantém o histórico e a quarentena pode ser reaberta.

## Vistoria orientativa de área

A vistoria cria inicialmente cinco pontos: frente, lateral esquerda, centro,
lateral direita e fundo. Pontos adicionais podem ser incluídos. Em cada ponto o
usuário pode:

- salvar latitude, longitude e precisão fornecida pelo aparelho;
- tirar uma foto vinculada ao ponto;
- repetir fotos e comparar com o registro anterior;
- pedir a distância aproximada até o ponto salvo;
- concluir ou reabrir a vistoria.

O indicador de cobertura significa **pontos fotografados / pontos previstos**.
Ele não estima diretamente a porcentagem do talhão doente. A interface recomenda
um percurso em zigue-zague e distribuição em zonas homogêneas porque a
representatividade depende do plano de amostragem:

- [Monitoramento de doenças — Embrapa](https://www.embrapa.br/agencia-de-informacao-tecnologica/cultivos/manga/producao/sistemas-diferenciados/producao-integrada/monitoramento/doencas)
- [Monitoramento da lavoura de soja — Embrapa](https://www.embrapa.br/en/web/agencia-de-informacao-tecnologica/cultivos/soja/producao/manejo-integrado-de-pragas/monitoramento-da-lavoura)
- [Como amostrar o solo — Embrapa](https://www.embrapa.br/web/agencia-de-informacao-tecnologica/cultivos/soja/producao/manejo-da-fertilidade-do-solo/analise-do-solo/como-amostrar)
- [Agricultura de precisão e GPS — Embrapa](https://www.embrapa.br/en/web/agencia-de-informacao-tecnologica/cultivos/cana-de-acucar/producao/avanco-tecnologico/agricultura-de-precisao)

A geolocalização do navegador exige HTTPS e autorização explícita. A precisão
varia conforme aparelho e ambiente. O GPS ajuda a retornar ao ponto sem exigir
um mapa, mas análise e sincronização continuam dependendo de internet:

- [Geolocation API — MDN](https://developer.mozilla.org/en-US/docs/Web/API/Geolocation_API)

## Fontes brasileiras encontradas

### Digipathos

A Embrapa disponibilizou publicamente a base Digipathos, com quase 3 mil imagens
de doenças descritas por especialistas em culturas como soja, café, arroz,
feijão, trigo, milho e frutas. Não foi encontrada uma API pública da Embrapa que
receba a foto e devolva um diagnóstico pronto.

- [Notícia e descrição da base Digipathos](https://www.embrapa.br/en/noticias-mais-lidas/-/asset_publisher/HA73uEmvroGS/content/id/42625978)
- [Artigo técnico sobre as bases PDDB/XDB](https://www.alice.cnptia.embrapa.br/alice/handle/doc/1097219?mode=full)
- [Exemplo de conjunto com download no OasisBR](https://oasisbr.ibict.br/vufind/Record/EMBRAPA-06_25bc8d44108060bad03dab82c2fcc4cd)

Antes de treinar comercialmente, é necessário revisar a licença de cada imagem,
atribuições e permissão de redistribuição.

### AgroAPI / Agrofit

A API Agrofit da Embrapa fornece dados de produtos e indicações registrados no
MAPA. Ela é útil **depois** de uma hipótese confirmada para filtrar produto por
cultura e alvo. Ela não diagnostica a foto.

- [Documentação da API Agrofit](https://www.portal.agroapi.cnptia.embrapa.br/api-docs/agrofit)

A etapa de defensivos deve exigir cultura, alvo, registro válido, localização e
responsável técnico. O app não deve copiar dosagem de uma fonte genérica.

### PlantAnnot

PlantAnnot é uma plataforma de anotação genômica/proteica para respostas a
estresses, não uma API de reconhecimento de doenças em fotografias.

- [PlantAnnot — Embrapa](https://www.embrapa.br/en/busca-de-solucoes-tecnologicas/-/produto-servico/7780/plantannot)

## Bases complementares para modelo próprio

- [PlantVillage](https://arxiv.org/abs/1604.03169): 54.306 imagens, 14 culturas e
  classes saudáveis/doentes; ótima para baseline, mas majoritariamente capturada
  em condições controladas.
- [PlantDoc](https://arxiv.org/abs/1911.10317): imagens mais próximas do campo,
  com fundo, iluminação e enquadramento variados.
- [Paddy Doctor](https://arxiv.org/abs/2205.11108): 16.225 imagens de arroz em
  ambiente real.
- [PlantSeg](https://www.nature.com/articles/s41597-025-06513-4.pdf): imagens
  “in the wild” com segmentação e 27 classes.

Resultados de laboratório não devem ser usados como promessa de desempenho no
campo. Estudos de generalização mostram queda relevante entre bases controladas
e fotos reais:

- [Generalização entre PlantVillage, PlantDoc, Digipathos e campo](https://doaj.org/article/e81741e8485f44b0b4f4ef55b92c95d0)
- [Viés de fundo em PlantVillage](https://arxiv.org/abs/2206.04374)

## Provedor escolhido para o MVP

O provedor primário implementado é o **Pl@ntNet Diseases**. O plano gratuito
oficial oferece 500 identificações por dia. Cada requisição de doença consome um
crédito e pode receber até cinco fotos da mesma planta. O Agro.in envia uma foto
JPEG com o órgão `leaf`, solicita apenas três resultados e não pede imagens
relacionadas, evitando a complexidade de licenciamento dessas ilustrações.

O endpoint devolve doenças e pragas por código EPPO, descrição e confiança. A
funcionalidade foi lançada em dezembro de 2025 e ainda cobre uma lista limitada
de espécies e patologias. Por segurança, o Agro.in rejeita respostas abaixo de
35% de confiança e preserva a triagem local. Esse limiar pode ser ajustado após
validação de campo.

- [Documentação do Pl@ntNet Diseases](https://my.plantnet.org/doc/api/diseases)
- [Plano gratuito e preços](https://my.plantnet.org/pricing)
- [Criação da conta e chave](https://my.plantnet.org/doc/getting-started/introduction)
- [Termos, privacidade e atribuição](https://my.plantnet.org/terms_of_use)
- [Consórcio Pl@ntNet](https://plantnet.org/en/plntnet-consortium/)
- [Histórico de lançamento do endpoint](https://my.plantnet.org/doc/references/changelog)

Configuração:

```env
PLANTNET_API_KEY="sua_chave_privada_plantnet"
PLANTNET_MIN_SCORE="0.35"
```

O `crop.health` da Kindwise permanece como fallback opcional:

```env
KINDWISE_CROP_HEALTH_API_KEY="sua_chave_crop_health"
```

- [Descrição do crop.health](https://www.kindwise.com/crop-health)
- [Documentação da API](https://crop.kindwise.com/docs)

Nunca exponha nenhuma dessas chaves no frontend. Elas devem ser configuradas
somente no backend/Vercel. Quando o Pl@ntNet está ativo, a interface identifica o
provedor no consentimento e exibe a atribuição. Segundo os termos oficiais, a
imagem enviada permanece apenas na memória volátil do serviço durante a
identificação; o Agro.in continua responsável por sua própria cópia no histórico.

## Arquitetura recomendada para modelo Agro.in

```text
captura mobile
  -> verificação de foto/não-planta
  -> identificação da cultura
  -> segmentação de folha e lesões
  -> classificador multi-rótulo
  -> calibração de confiança e rejeição fora do domínio
  -> perguntas de confirmação
  -> base agronômica versionada
  -> revisão de especialista e feedback
```

### Estratégia de dados

1. Normalizar taxonomia, cultura, órgão, doença, agente causal, fase e severidade.
2. Manter origem, autor e licença por imagem.
3. Separar treino/validação/teste por fazenda, data e dispositivo, evitando que
   fotos quase iguais caiam em grupos diferentes.
4. Priorizar fotos brasileiras reais: luz forte, sombra, poeira, folhas
   sobrepostas e diferentes celulares.
5. Incluir classes “não é planta”, “foto inadequada”, “sintoma desconhecido” e
   “mais de uma causa”.
6. Fazer dupla anotação e arbitragem por fitopatologista/agronomista.

### Métricas mínimas

- recall e precisão por cultura/doença;
- macro F1 para evitar esconder classes raras;
- top-3 e matriz de confusão;
- calibração de probabilidade;
- taxa de rejeição correta fora do domínio;
- validação externa em fazendas não vistas no treino;
- impacto das perguntas adicionais no diagnóstico final.

## Privacidade e operação

- A foto só é enviada após consentimento explícito.
- O backend remove metadados EXIF durante a compressão.
- A miniatura fica vinculada ao usuário e exige JWT para leitura.
- O usuário pode excluir análise e foto.
- Localização é opcional e armazenada apenas quando solicitada.
- Para escala, as imagens devem migrar de `BYTEA` para Supabase Storage ou
  armazenamento de objetos com URLs assinadas e política de retenção.

## Próximos passos para produção

1. Criar a conta gratuita do Pl@ntNet e configurar `PLANTNET_API_KEY` no backend.
2. Integrar Agrofit somente após confirmação e com regras de registro brasileiras.
3. Criar o catálogo versionado de recomendações por cultura, fase e região.
4. Montar a ingestão licenciada do Digipathos e das bases complementares.
5. Firmar validação com agrônomo/fitopatologista e coletar imagens locais.
6. Treinar e calibrar um modelo próprio, mantendo o provedor como comparação.
