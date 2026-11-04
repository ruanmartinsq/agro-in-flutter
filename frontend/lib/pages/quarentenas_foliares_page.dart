import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/analise_foliar_nav.dart';
import '../widgets/common.dart';
import '../widgets/foto_analise_protegida.dart';

/// Port de src/pages/QuarentenasFoliares.tsx
class QuarentenasFoliaresPage extends StatefulWidget {
  const QuarentenasFoliaresPage({super.key});

  @override
  State<QuarentenasFoliaresPage> createState() =>
      _QuarentenasFoliaresPageState();
}

// ---------------------------------------------------------------------------
// Modelos
// ---------------------------------------------------------------------------

class _Comparacao {
  _Comparacao(Map<String, dynamic> j)
    : estado = j['estado']?.toString() ?? 'inconclusivo',
      diasDesde = toInt(j['dias_desde']),
      resumo = j['resumo']?.toString() ?? '',
      aviso = j['aviso']?.toString() ?? '';
  final String estado;
  final int diasDesde;
  final String resumo;
  final String aviso;
}

class _AnaliseCaso {
  _AnaliseCaso(Map<String, dynamic> j)
    : id = toInt(j['id']),
      etapaAcompanhamento = toInt(j['etapa_acompanhamento']),
      statusGeral = j['status_geral']?.toString() ?? '',
      criadoEm = j['criado_em']?.toString() ?? '',
      comparacaoAnterior = j['comparacao_anterior'] is Map
          ? _Comparacao(asMap(j['comparacao_anterior']))
          : null,
      hipoteses = asList(j['hipoteses'])
          .map((h) => h['nome']?.toString() ?? '')
          .toList();
  final int id;
  final int etapaAcompanhamento;
  final String statusGeral;
  final String criadoEm;
  final _Comparacao? comparacaoAnterior;
  final List<String> hipoteses;
}

class _CasoFoliar {
  _CasoFoliar(Map<String, dynamic> j)
    : id = toInt(j['id']),
      titulo = j['titulo']?.toString() ?? '',
      cultura = j['cultura']?.toString(),
      tratamento = j['tratamento']?.toString(),
      status = j['status']?.toString() ?? 'em_quarentena',
      proximaRevisaoEm = j['proxima_revisao_em']?.toString(),
      propriedadeNome = j['propriedade'] is Map
          ? asMap(j['propriedade'])['nome']?.toString()
          : null,
      analises = asList(j['analises']).map(_AnaliseCaso.new).toList();
  final int id;
  final String titulo;
  final String? cultura;
  final String? tratamento;
  final String status;
  final String? proximaRevisaoEm;
  final String? propriedadeNome;
  final List<_AnaliseCaso> analises;

  bool get emQuarentena => status == 'em_quarentena';
}

/// `Intl.DateTimeFormat("pt-BR", { day: "2-digit", month: "short", year: "numeric" })`
String _dataCurta(String valor) {
  final d = parseData(valor);
  return d == null ? valor : formatPattern(d, "dd 'de' MMM 'de' y");
}

const _comparacoes = <String, ({String rotulo, Color cor, Color fundo})>{
  'melhora_visual': (
    rotulo: 'Melhora visual',
    cor: Color(0xFF176B35),
    fundo: Color(0xFFE4F5E7),
  ),
  'estavel': (
    rotulo: 'Estável',
    cor: Color(0xFF526052),
    fundo: Color(0xFFEEF1EC),
  ),
  'piora_visual': (
    rotulo: 'Piora visual',
    cor: Color(0xFFA0482C),
    fundo: Color(0xFFFBECE5),
  ),
  'inconclusivo': (
    rotulo: 'Inconclusivo',
    cor: Color(0xFF756320),
    fundo: Color(0xFFFFF7D8),
  ),
};

const _primary = Color(0xFF1F5B3A);

// ---------------------------------------------------------------------------
// Página
// ---------------------------------------------------------------------------

class _QuarentenasFoliaresPageState extends State<QuarentenasFoliaresPage> {
  List<_CasoFoliar> _casos = [];
  bool _carregando = true;
  bool _salvando = false;
  String _erro = '';
  final _tratamento = TextEditingController();
  String _proximaRevisao = ''; // yyyy-MM-dd
  String? _sincronizado;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _tratamento.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sincronizar(_selecionado);
  }

  String? get _paramId => GoRouterState.of(context).uri.queryParameters['id'];

  void _setParams(int id) => context.go('/analise-foliar/quarentenas?id=$id');

  _CasoFoliar? get _selecionado {
    final solicitado = int.tryParse(_paramId ?? '') ?? 0;
    final id = solicitado != 0
        ? solicitado
        : (_casos.isNotEmpty ? _casos.first.id : null);
    for (final c in _casos) {
      if (c.id == id) return c;
    }
    return null;
  }

  String _tratarErro(Object error, String mensagem) {
    if (apiStatus(error) == 401) {
      context.go('/login');
      return 'Sua sessão expirou.';
    }
    return apiErrorMessage(error) ?? mensagem;
  }

  Future<void> _carregar() async {
    try {
      final res = await api.get('/analise-foliar/quarentenas');
      if (!mounted) return;
      final data = asList(res.data).map(_CasoFoliar.new).toList();
      setState(() {
        _casos = data;
        _sincronizar(_selecionado);
      });
      final solicitado = int.tryParse(_paramId ?? '') ?? 0;
      if (solicitado == 0 && data.isNotEmpty) _setParams(data.first.id);
    } catch (e) {
      if (mounted) {
        setState(
          () => _erro = _tratarErro(
            e,
            'Não foi possível carregar as quarentenas.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  /// Equivalente ao useEffect que sincroniza tratamento/próxima revisão com o caso selecionado.
  void _sincronizar(_CasoFoliar? sel) {
    final chave = '${sel?.id}|${sel?.tratamento}|${sel?.proximaRevisaoEm}';
    if (chave == _sincronizado) return;
    _sincronizado = chave;
    _tratamento.text = sel?.tratamento ?? '';
    final p = sel?.proximaRevisaoEm;
    _proximaRevisao = p != null && p.length >= 10 ? p.substring(0, 10) : '';
  }

  void _substituir(Map<String, dynamic> json) {
    final novo = _CasoFoliar(json);
    setState(() {
      _casos = _casos.map((c) => c.id == novo.id ? novo : c).toList();
      _sincronizar(_selecionado);
    });
  }

  Future<void> _salvarPlano() async {
    final sel = _selecionado;
    if (sel == null) return;
    setState(() {
      _salvando = true;
      _erro = '';
    });
    try {
      String? revisao;
      if (_proximaRevisao.isNotEmpty) {
        final d = DateTime.parse(_proximaRevisao);
        revisao = DateTime(
          d.year,
          d.month,
          d.day,
          12,
        ).toUtc().toIso8601String();
      }
      final res = await api.patch(
        '/analise-foliar/quarentenas/${sel.id}',
        data: {
          'tratamento': _tratamento.text.trim().isEmpty
              ? null
              : _tratamento.text.trim(),
          'proxima_revisao_em': revisao,
        },
      );
      if (!mounted) return;
      _substituir(asMap(res.data));
    } catch (e) {
      if (mounted) {
        setState(
          () => _erro = _tratarErro(e, 'Não foi possível salvar o plano.'),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _alternarStatus() async {
    final sel = _selecionado;
    if (sel == null) return;
    final encerrando = sel.emQuarentena;
    if (encerrando &&
        !await confirmar(
          context,
          'Encerrar esta quarentena? O histórico será mantido e poderá ser reaberto.',
          confirmar: 'OK',
        )) {
      return;
    }
    setState(() => _salvando = true);
    try {
      final acao = encerrando ? 'encerrar' : 'reabrir';
      final res = await api.post('/analise-foliar/quarentenas/${sel.id}/$acao');
      if (!mounted) return;
      _substituir(asMap(res.data));
    } catch (e) {
      if (mounted) {
        setState(
          () => _erro = _tratarErro(
            e,
            'Não foi possível atualizar a quarentena.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: _primary),
        ),
      );
    }

    final w = MediaQuery.sizeOf(context).width;
    final md = w >= 768;
    final lg = w >= 1024;
    final selecionado = _selecionado;
    final ativas = _casos.where((c) => c.emQuarentena).length;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Cabeçalho
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAF5),
            border: Border(bottom: BorderSide(color: Color(0xFFDDE2D8))),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: lg ? 40 : (md ? 32 : 20),
            vertical: 20,
          ),
          child: _Centro(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      LucideIcons.shieldCheck,
                      size: 14,
                      color: Color(0xFF317244),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'ACOMPANHAMENTO TEMPORAL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.98,
                        color: Color(0xFF317244),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Quarentenas',
                  style: TextStyle(
                    fontSize: md ? 36 : 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: (md ? 36 : 30) * -0.035,
                    color: AgroColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 672),
                  child: const Text(
                    'Guarde o contexto, registre o tratamento e compare a evolução visual sem perder a foto inicial.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 24 / 14,
                      color: Color(0xFF687267),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: lg ? 40 : (md ? 32 : 16),
            vertical: md ? 32 : 20,
          ),
          child: _Centro(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AnaliseFoliarNav(),
                if (_erro.isNotEmpty) ...[
                  _Erro(_erro),
                  const SizedBox(height: 20),
                ],
                if (_casos.isEmpty)
                  _vazio(context)
                else
                  _painel(context, selecionado, ativas),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _vazio(BuildContext context) => CustomPaint(
    foregroundPainter: const _BordaTracejada(
      color: Color(0xFFC9D4C6),
      radius: 8,
    ),
    child: Container(
      constraints: const BoxConstraints(minHeight: 440),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            LucideIcons.shieldCheck,
            size: 38,
            color: Color(0xFF3B7748),
          ),
          const SizedBox(height: 20),
          const Text(
            'Nenhuma quarentena aberta',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AgroColors.text,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 448),
            child: const Text(
              'Faça um diagnóstico e use “Acompanhar tratamento” para criar a primeira linha do tempo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 24 / 14,
                color: Color(0xFF6F7B70),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _BotaoVerde(
            icon: LucideIcons.plus,
            iconSize: 17,
            label: 'Nova análise',
            fontSize: 14,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            onPressed: () => context.go('/analise-foliar'),
          ),
        ],
      ),
    ),
  );

  Widget _painel(BuildContext context, _CasoFoliar? selecionado, int ativas) {
    final lg = MediaQuery.sizeOf(context).width >= 1024;

    final listaCasos = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE0E5DC))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Casos',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AgroColors.text,
                ),
              ),
              Text(
                '$ativas ativos',
                style: const TextStyle(fontSize: 11, color: Color(0xFF748074)),
              ),
            ],
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 760),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, caso) in _casos.indexed) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFE4E9E1),
                    ),
                  _itemCaso(caso, caso.id == selecionado?.id),
                ],
              ],
            ),
          ),
        ),
      ],
    );

    final detalhe = selecionado == null
        ? const SizedBox.shrink()
        : _detalhe(context, selecionado);

    Widget conteudo;
    if (lg) {
      // grid lg:grid-cols-[330px_minmax(0,1fr)] — o fundo do aside ocupa toda a altura da linha.
      conteudo = Stack(
        children: [
          const Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 330,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFF8FAF6),
                border: Border(right: BorderSide(color: Color(0xFFE0E5DC))),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 329, child: listaCasos),
              const SizedBox(width: 1),
              Expanded(child: detalhe),
            ],
          ),
        ],
      );
    } else {
      conteudo = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAF6),
              border: Border(bottom: BorderSide(color: Color(0xFFE0E5DC))),
            ),
            child: listaCasos,
          ),
          detalhe,
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD9E0D4)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(31, 61, 35, 0.06),
            offset: Offset(0, 22),
            blurRadius: 55,
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(7), child: conteudo),
    );
  }

  Widget _itemCaso(_CasoFoliar caso, bool ativo) {
    final ultima = caso.analises.isEmpty ? null : caso.analises.last;
    return Material(
      color: ativo ? const Color(0xFFEDF5E9) : Colors.transparent,
      child: InkWell(
        onTap: () => _setParams(caso.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: caso.emQuarentena
                      ? const Color(0xFF2F8142)
                      : const Color(0xFFA8B1A7),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caso.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AgroColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ultima != null
                          ? '${caso.analises.length} registro(s) · ${_dataCurta(ultima.criadoEm)}'
                          : 'Sem registros',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF778277),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: Color(0xFF9AA49A),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detalhe(BuildContext context, _CasoFoliar sel) {
    final w = MediaQuery.sizeOf(context).width;
    final sm = w >= 640;
    final md = w >= 768;
    final xl = w >= 1280;
    final emQuarentena = sel.emQuarentena;

    final infoCaso = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: emQuarentena
                ? const Color(0xFFE4F5E7)
                : const Color(0xFFEDF0EB),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            emQuarentena ? 'EM ACOMPANHAMENTO' : 'ENCERRADA',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: emQuarentena
                  ? const Color(0xFF176B35)
                  : const Color(0xFF606A60),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          sel.titulo,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 24 * -0.03,
            color: AgroColors.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(sel.cultura ?? '').isNotEmpty ? sel.cultura : 'Cultura não informada'}'
          '${(sel.propriedadeNome ?? '').isNotEmpty ? ' · ${sel.propriedadeNome}' : ''}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF788278)),
        ),
      ],
    );

    final botaoStatus = _BotaoBorda(
      onPressed: _salvando ? null : _alternarStatus,
      icon: emQuarentena ? LucideIcons.circleCheck : LucideIcons.refreshCw,
      label: emQuarentena ? 'Encerrar quarentena' : 'Reabrir',
    );

    final cabecalho = Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE1E6DE))),
      ),
      padding: EdgeInsets.symmetric(horizontal: md ? 28 : 20, vertical: 20),
      child: sm
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: infoCaso),
                const SizedBox(width: 16),
                botaoStatus,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [infoCaso, const SizedBox(height: 16), botaoStatus],
            ),
    );

    final linhaDoTempo = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LINHA DO TEMPO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: Color(0xFF5F8066),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Antes e depois',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AgroColors.text,
                    ),
                  ),
                ],
              ),
            ),
            if (emQuarentena)
              _BotaoVerde(
                icon: LucideIcons.plus,
                iconSize: 15,
                label: 'Nova foto',
                minHeight: 44,
                onPressed: () => context.go('/analise-foliar?caso=${sel.id}'),
              ),
          ],
        ),
        const SizedBox(height: 20),
        for (final (indice, analise) in sel.analises.indexed) ...[
          if (indice > 0) const SizedBox(height: 20),
          _registro(sel, analise, indice, sm),
        ],
      ],
    );

    final plano = _plano(context, sel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cabecalho,
        Padding(
          padding: EdgeInsets.all(md ? 28 : 20),
          child: xl
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: linhaDoTempo),
                    const SizedBox(width: 28),
                    SizedBox(width: 290, child: plano),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [linhaDoTempo, const SizedBox(height: 28), plano],
                ),
        ),
      ],
    );
  }

  Widget _registro(_CasoFoliar sel, _AnaliseCaso analise, int indice, bool sm) {
    final comparacao = analise.comparacaoAnterior;
    final meta = comparacao != null ? _comparacoes[comparacao.estado] : null;

    final foto = FotoAnaliseProtegida(
      analiseId: analise.id,
      width: sm ? 150 : double.infinity,
      height: sm ? 128 : 144,
      borderRadius: BorderRadius.circular(6),
    );

    final texto = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              indice == 0 ? 'FOTO INICIAL' : 'REVISÃO $indice',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
                color: Color(0xFF66816C),
              ),
            ),
            Text(
              _dataCurta(analise.criadoEm),
              style: const TextStyle(fontSize: 11, color: Color(0xFF879187)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          analise.hipoteses.isNotEmpty && analise.hipoteses.first.isNotEmpty
              ? analise.hipoteses.first
              : 'Análise foliar',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AgroColors.text,
          ),
        ),
        if (meta != null && comparacao != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: meta.fundo,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.arrowLeftRight, size: 14, color: meta.cor),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${meta.rotulo} · ${comparacao.diasDesde} dias',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: meta.cor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comparacao.resumo,
                  style: TextStyle(
                    fontSize: 11,
                    height: 20 / 11,
                    color: meta.cor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );

    return Container(
      padding: const EdgeInsets.only(bottom: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE4E9E1))),
      ),
      child: sm
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                foto,
                const SizedBox(width: 16),
                Expanded(child: texto),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [foto, const SizedBox(height: 16), texto],
            ),
    );
  }

  Widget _plano(BuildContext context, _CasoFoliar sel) {
    final encerrado = sel.status == 'encerrado';
    final borda = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: Color(0xFFD7DED3)),
    );
    String fmt(String iso) {
      final d = DateTime.tryParse(iso);
      return d == null ? iso : formatData(d);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6F0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Plano de tratamento',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AgroColors.text,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tratamento,
            enabled: !encerrado,
            minLines: 6,
            maxLines: 6,
            style: const TextStyle(
              fontSize: 12,
              height: 20 / 12,
              color: AgroColors.text,
            ),
            decoration: InputDecoration(
              hintText:
                  'O que foi aplicado, dose orientada, manejo realizado...',
              hintStyle: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9DAA9F),
              ),
              filled: true,
              fillColor: encerrado ? const Color(0xFFEEF1EC) : Colors.white,
              contentPadding: const EdgeInsets.all(12),
              border: borda,
              enabledBorder: borda,
              disabledBorder: borda,
              focusedBorder: borda.copyWith(
                borderSide: const BorderSide(color: Color(0xFF5D8C63)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Próxima revisão',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AgroColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: encerrado ? const Color(0xFFEEF1EC) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: const BorderSide(color: Color(0xFFD7DED3)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: encerrado
                  ? null
                  : () async {
                      final atual = DateTime.tryParse(_proximaRevisao);
                      final d = await showDatePicker(
                        context: context,
                        initialDate: atual ?? DateTime.now(),
                        firstDate: DateTime(1990),
                        lastDate: DateTime(2100),
                        locale: const Locale('pt', 'BR'),
                      );
                      if (d != null && mounted) {
                        setState(() => _proximaRevisao = isoDate(d));
                      }
                    },
              child: SizedBox(
                height: 40,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(
                      LucideIcons.calendarClock,
                      size: 15,
                      color: Color(0xFF6C7C6F),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _proximaRevisao.isEmpty
                            ? 'dd/mm/aaaa'
                            : fmt(_proximaRevisao),
                        style: TextStyle(
                          fontSize: 12,
                          color: _proximaRevisao.isEmpty
                              ? const Color(0xFF9DAA9F)
                              : AgroColors.text,
                        ),
                      ),
                    ),
                    if (_proximaRevisao.isNotEmpty && !encerrado)
                      IconButton(
                        onPressed: () => setState(() => _proximaRevisao = ''),
                        icon: const Icon(
                          LucideIcons.x,
                          size: 14,
                          color: Color(0xFF6C7C6F),
                        ),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Limpar',
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (sel.emQuarentena) ...[
            const SizedBox(height: 16),
            Opacity(
              opacity: _salvando ? 0.5 : 1,
              child: _BotaoVerde(
                icon: LucideIcons.save,
                iconSize: 15,
                label: 'Salvar plano',
                loading: _salvando,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                onPressed: _salvando ? null : _salvarPlano,
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Compare a mesma planta ou folhas de idade semelhante, no mesmo enquadramento e luz. A leitura é orientativa.',
            style: TextStyle(
              fontSize: 10,
              height: 16 / 10,
              color: Color(0xFF7A857A),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets auxiliares
// ---------------------------------------------------------------------------

/// `mx-auto max-w-[1380px]`
class _Centro extends StatelessWidget {
  const _Centro({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1380),
      child: child,
    ),
  );
}

/// Erro: border #E9C1A8, bg #FFF4EC, texto #8A431F.
class _Erro extends StatelessWidget {
  const _Erro(this.mensagem);
  final String mensagem;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4EC),
      border: Border.all(color: const Color(0xFFE9C1A8)),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      mensagem,
      style: const TextStyle(fontSize: 14, color: Color(0xFF8A431F)),
    ),
  );
}

/// Botão verde (bg #1F5B3A, texto branco, text-xs bold).
class _BotaoVerde extends StatelessWidget {
  const _BotaoVerde({
    required this.label,
    required this.onPressed,
    required this.icon,
    this.iconSize = 15,
    this.fontSize = 12,
    this.minHeight = 0,
    this.loading = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final double iconSize;
  final double fontSize;
  final double minHeight;
  final bool loading;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Material(
    color: _primary,
    borderRadius: BorderRadius.circular(6),
    child: InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: iconSize,
                  height: iconSize,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Icon(icon, size: iconSize, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Botão com borda #CAD5C8, fundo branco, texto #31533A.
class _BotaoBorda extends StatelessWidget {
  const _BotaoBorda({
    required this.label,
    required this.onPressed,
    required this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
      side: const BorderSide(color: Color(0xFFCAD5C8)),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: const Color(0xFF31533A)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF31533A),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Borda tracejada (border-dashed) com cantos arredondados.
class _BordaTracejada extends CustomPainter {
  const _BordaTracejada({required this.color, this.radius = 8});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(0.5),
      );
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 4), paint);
        d += 7;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BordaTracejada old) =>
      old.color != color || old.radius != radius;
}
