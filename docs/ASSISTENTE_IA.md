# Assistente agronômico gratuito

## Decisão técnica

O assistente usa o plano gratuito da Groq com o modelo principal
`openai/gpt-oss-120b`. Se o limite específico desse modelo for atingido, o
backend tenta `llama-3.1-8b-instant` com a mesma chave.

Nenhuma assinatura paga ou cartão é configurado pelo código. As cotas do plano
gratuito são definidas e podem ser alteradas pelo provedor.

## Arquitetura

1. O frontend envia a pergunta e, no máximo, as oito últimas mensagens.
2. O backend recupera até quatro sínteses relevantes da base local.
3. Somente a pergunta, o histórico curto e essas sínteses são enviados à Groq.
4. A resposta retorna com os links das fontes recuperadas.

Dados de propriedades, finanças, localização e o e-mail da conta não são
enviados automaticamente ao provedor.

## Base de conhecimento

A base inicial fica em
`backend/src/data/conhecimento-agronomico.ts`. Ela contém sínteses próprias e
links para fontes como Embrapa e MAPA. Não são copiadas obras integrais.

Antes de adicionar material:

- verifique a licença e a permissão de uso comercial;
- prefira uma síntese factual e mantenha o link para o original;
- registre título, organização e URL;
- não use a compra de um livro como autorização para treinar ou redistribuir seu
  conteúdo.

## Segurança agronômica

O prompt do sistema proíbe:

- diagnóstico definitivo com base apenas em relato ou imagem;
- prescrição de defensivo, ingrediente ativo, dose, mistura ou carência;
- dose de fertilizante, calcário ou gesso sem análise e recomendação regional;
- inferência de NPK, pH ou fertilidade a partir da cor de uma folha.

## Configuração

No backend:

```env
GROQ_API_KEY="gsk_..."
GROQ_MODEL="openai/gpt-oss-120b"
GROQ_FALLBACK_MODEL="llama-3.1-8b-instant"
```

A chave deve existir somente no backend/Vercel. Nunca use prefixo `VITE_` nem
inclua a chave no frontend.

## Endpoints

- `GET /assistente/capacidades`
- `POST /assistente/perguntar`

Ambos exigem o token JWT do Agro.in.
