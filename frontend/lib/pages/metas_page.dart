import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Port de src/pages/Metas.tsx

// ============================================================
// Tipos e constantes
// ============================================================

/// Status: "pendente" | "em_andamento" | "concluida".
/// Categorias: "producao" | "financeiro" | "sustentabilidade" | "geral"; aba extra "todas".
const _categorias = <({String key, String label})>[
  (key: 'todas', label: 'Todas'),
  (key: 'producao', label: 'Produção'),
  (key: 'financeiro', label: 'Financeiro'),
  (key: 'sustentabilidade', label: 'Sustentabilidade'),
];

const _categoriaLabel = <String, String>{
  'producao': 'Produção',
  'financeiro': 'Financeiro',
  'sustentabilidade': 'Sustentabilidade',
  'geral': 'Geral',
};

class _CorCategoria {
  const _CorCategoria(this.linha, this.barra, this.bg, this.texto);
  final Color linha, barra, bg, texto;
}

const _coresCategoria = <String, _CorCategoria>{
  'producao': _CorCategoria(
    Color(0xFFE2574C),
    Color(0xFFE2574C),
    Color(0xFFF8ECE8),
    Color(0xFFA8553E),
  ),
  'financeiro': _CorCategoria(
    Color(0xFF4E9462),
    Color(0xFF4E9462),
    Color(0xFFE8F3EA),
    Color(0xFF1F5B3A),
  ),
  'sustentabilidade': _CorCategoria(
    Color(0xFF8B6F47),
    Color(0xFF8B6F47),
    Color(0xFFF2ECE1),
    Color(0xFF6B5636),
  ),
  'geral': _CorCategoria(
    Color(0xFF1F5B3A),
    Color(0xFF1F5B3A),
    Color(0xFFE8F3EA),
    Color(0xFF1F5B3A),
  ),
};

const _statusOpcoes = <({String key, String label})>[
  (key: 'pendente', label: 'Pendente'),
  (key: 'em_andamento', label: 'Em andamento'),
  (key: 'concluida', label: 'Concluída'),
];

const _intervaloSincronia = Duration(milliseconds: 15000);

const _verde = Color(0xFF4E9462);
const _vermelho = Color(0xFFA8553E);
const _vermelhoBg = Color(0xFFF8ECE8);
const _spinner = Color(0xFF8CA88A);

String _str(dynamic v) => v?.toString() ?? '';

String _categoriaDe(Map<String, dynamic> m) {
  final c = _str(m['categoria']);
  return c.isNotEmpty ? c : 'geral';
}

_CorCategoria _corCategoria(Map<String, dynamic> m) =>
    _coresCategoria[_categoriaDe(m)] ?? _coresCategoria['geral']!;

String _formatPrazo(dynamic data) {
  if (_str(data).isEmpty) return 'Sem prazo definido';
  final d = parseData(data);
  if (d == null) return 'Sem prazo definido';
  final mes = formatPattern(d, 'MMM').replaceFirst('.', '');
  return '$mes/${d.toLocal().year}';
}

int _calcPercentual(Map<String, dynamic> m) {
  if (m['status'] == 'concluida') return 100;
  final alvo = toDoubleOrNull(m['valor_alvo']);
  final atual = toDoubleOrNull(m['valor_atual']);
  if (alvo != null && alvo > 0 && atual != null) {
    return math.min(100, math.max(0, (atual / alvo * 100).round()));
  }
  return 0;
}

bool _estaAtrasada(Map<String, dynamic> m) {
  if (m['status'] == 'concluida' || _str(m['prazo']).isEmpty) return false;
  final d = parseData(m['prazo']);
  return d != null && d.isBefore(DateTime.now());
}

({String label, Color bg, Color cor}) _statusInfo(Map<String, dynamic> m) {
  if (m['status'] == 'concluida') {
    return (
      label: 'Concluída',
      bg: AgroColors.badgeBg,
      cor: AgroColors.primary,
    );
  }
  if (_estaAtrasada(m)) {
    return (label: 'Atrasada', bg: _vermelhoBg, cor: _vermelho);
  }
  return (
    label: 'Dentro do prazo',
    bg: AgroColors.badgeBg,
    cor: AgroColors.primary,
  );
}

bool _estaNoTrimestreAtual(dynamic data) {
  if (_str(data).isEmpty) return false;
  final d = parseData(data)?.toLocal();
  if (d == null) return false;
  final agora = DateTime.now();
  return d.year == agora.year && (d.month - 1) ~/ 3 == (agora.month - 1) ~/ 3;
}

/// `String(n)` do JavaScript (120 → "120", 1.5 → "1.5").
String _jsNum(dynamic v) {
  final d = toDoubleOrNull(v);
  if (d == null) return '';
  return d == d.truncateToDouble() ? d.toInt().toString() : d.toString();
}

String _formatValorMeta(Map<String, dynamic> m) {
  final atual = toDouble(m['valor_atual']);
  final alvo = toDoubleOrNull(m['valor_alvo']);
  final temAlvo = alvo != null && alvo != 0;
  if (m['categoria'] == 'financeiro') {
    return temAlvo
        ? '${formatBRL(atual)} / ${formatBRL(alvo)}'
        : formatBRL(atual);
  }
  final un = _str(m['unidade']);
  final unidade = un.isNotEmpty ? ' $un' : '';
  return temAlvo
      ? '${_jsNum(atual)}$unidade / ${_jsNum(alvo)}$unidade'
      : '${_jsNum(atual)}$unidade';
}

/// `new Date(v).toISOString().split("T")[0]`
String _isoDia(dynamic v) {
  final d = parseData(v);
  return d == null ? '' : isoDate(d.toUtc());
}

class _FormMeta {
  String propriedadeId = '';
  String descricao = '';
  String categoria = 'geral';
  String valorAlvo = '';
  String valorAtual = '';
  String unidade = '';
  String responsavel = '';
  String prazo = '';
  String status = 'pendente';
}

// ============================================================
// Página
// ============================================================

class MetasPage extends StatefulWidget {
  const MetasPage({super.key});

  @override
  State<MetasPage> createState() => _MetasPageState();
}

class _MetasPageState extends State<MetasPage> {
  List<({String id, String nome})> _propriedades = [];
  List<Map<String, dynamic>> _metas = [];
  bool _loading = true;
  bool _sincronizando = false;
  bool _erroConexao = false;
  DateTime? _ultimaSincronia;
  int _segundosDesde = 0;

  String _abaCategoria = 'todas';
  String _busca = '';

  Timer? _intervalo;
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    _carregar();
    api
        .get('/propriedades')
        .then((res) {
          if (!mounted) return;
          setState(() {
            _propriedades = asList(res.data)
                .map((p) => (id: _str(p['id']), nome: _str(p['nome'])))
                .toList();
          });
        })
        .catchError((Object _) {});
    _intervalo = Timer.periodic(
      _intervaloSincronia,
      (_) => _carregar(silencioso: true),
    );
    _relogio = Timer.periodic(const Duration(seconds: 1), (_) {
      final u = _ultimaSincronia;
      if (u != null && mounted) {
        setState(() => _segundosDesde = DateTime.now().difference(u).inSeconds);
      }
    });
  }

  @override
  void dispose() {
    _intervalo?.cancel();
    _relogio?.cancel();
    super.dispose();
  }

  Future<void> _carregar({bool silencioso = false}) async {
    if (!mounted) return;
    setState(() {
      if (!silencioso) _loading = true;
      _sincronizando = true;
    });
    try {
      final res = await api.get('/metas');
      if (!mounted) return;
      setState(() {
        _metas = asList(res.data);
        _erroConexao = false;
        _ultimaSincronia = DateTime.now();
      });
    } catch (_) {
      if (mounted) setState(() => _erroConexao = true);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _sincronizando = false;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // CRUD — toda ação grava direto na API e depois re-sincroniza
  // ------------------------------------------------------------

  void _abrirNovo() {
    final form = _FormMeta()
      ..categoria = _abaCategoria == 'todas' ? 'geral' : _abaCategoria
      ..propriedadeId = _propriedades.length == 1 ? _propriedades.first.id : '';
    _abrirModal(null, form);
  }

  void _abrirEdicao(Map<String, dynamic> m) {
    final status = _str(m['status']);
    final form = _FormMeta()
      ..propriedadeId = _str(m['propriedade_id'])
      ..descricao = _str(m['descricao'])
      ..categoria = _categoriaDe(m)
      ..valorAlvo = m['valor_alvo'] != null ? _jsNum(m['valor_alvo']) : ''
      ..valorAtual = m['valor_atual'] != null ? _jsNum(m['valor_atual']) : ''
      ..unidade = _str(m['unidade'])
      ..responsavel = _str(m['responsavel'])
      ..prazo = _str(m['prazo']).isNotEmpty ? _isoDia(m['prazo']) : ''
      ..status = status.isNotEmpty ? status : 'pendente';
    _abrirModal(m, form);
  }

  void _abrirModal(Map<String, dynamic>? editando, _FormMeta form) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: .4),
      builder: (_) => _MetaModal(
        editando: editando,
        form: form,
        propriedades: _propriedades,
        carregar: () => _carregar(),
      ),
    );
  }

  Future<void> _deletar(dynamic id) async {
    if (!await confirmar(context, 'Deseja excluir esta meta?')) return;
    try {
      await api.delete('/metas/$id');
      await _carregar();
    } catch (_) {
      if (mounted) avisar(context, 'Erro ao excluir meta.');
    }
  }

  Future<void> _alternarConcluida(Map<String, dynamic> m) async {
    try {
      await api.put(
        '/metas/${m['id']}',
        data: {'status': m['status'] == 'concluida' ? 'pendente' : 'concluida'},
      );
      await _carregar();
    } catch (_) {
      if (mounted) avisar(context, 'Erro ao atualizar status da meta.');
    }
  }

  // ------------------------------------------------------------
  // Render
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final sm = w >= 640;
    final lg = w >= 1024;
    final hPad = lg ? 40.0 : (sm ? 24.0 : 16.0);
    final vPad = sm ? 32.0 : 24.0;

    // Dados derivados
    final b = _busca.toLowerCase();
    final metasFiltradas = _metas
        .where(
          (m) => _abaCategoria == 'todas' || _categoriaDe(m) == _abaCategoria,
        )
        .where((m) => _str(m['descricao']).toLowerCase().contains(b))
        .toList();

    final metasAtivas = _metas.where((m) => m['status'] != 'concluida').length;
    final progressoMedio = _metas.isNotEmpty
        ? (_metas.fold<int>(0, (s, m) => s + _calcPercentual(m)) /
                  _metas.length)
              .round()
        : 0;
    final concluidasTrimestre = _metas
        .where(
          (m) =>
              m['status'] == 'concluida' && _estaNoTrimestreAtual(m['prazo']),
        )
        .length;

    Map<String, dynamic>? destaque;
    final ativas = metasFiltradas
        .where((m) => m['status'] != 'concluida')
        .toList();
    if (ativas.isNotEmpty) {
      final ordenadas = [...ativas]
        ..sort((a, b) {
          final pa = parseData(a['prazo']);
          final pb = parseData(b['prazo']);
          if (_str(a['prazo']).isEmpty) return 1;
          if (_str(b['prazo']).isEmpty) return -1;
          if (pa == null || pb == null) return 0;
          return pa.compareTo(pb);
        });
      destaque = ordenadas.first;
    }
    final secundarias = metasFiltradas
        .where((m) => m['id'] != destaque?['id'])
        .take(4)
        .toList();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        PageHeader(
          title: 'Metas',
          subtitleWidget: _StatusSincronia(
            erroConexao: _erroConexao,
            sincronizando: _sincronizando,
            ultimaSincronia: _ultimaSincronia,
            segundosDesde: _segundosDesde,
          ),
          actions: [
            _BotaoAtualizar(
              sincronizando: _sincronizando,
              onTap: () => _carregar(),
            ),
            _BotaoNovo(label: 'Nova meta', onTap: _abrirNovo),
          ],
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, vPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Abas de categoria
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (i, c) in _categorias.indexed) ...[
                        if (i > 0) const SizedBox(width: 8),
                        _AbaCategoria(
                          label: c.label,
                          ativa: _abaCategoria == c.key,
                          onTap: () => setState(() => _abaCategoria = c.key),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Cards resumo
              ResponsiveGrid(
                sm: 3,
                md: 3,
                xl: 3,
                spacing: 16,
                children: [
                  for (final r in [
                    (label: 'Metas ativas', valor: '$metasAtivas'),
                    (label: 'Progresso médio', valor: '$progressoMedio%'),
                    (
                      label: 'Concluídas no trimestre',
                      valor: '$concluidasTrimestre',
                    ),
                  ])
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AgroColors.cardDivider,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.label,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AgroColors.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            r.valor,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AgroColors.text,
                              fontFamily: kTitleFont,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              if (_loading)
                const _EstadoCarregando('Carregando metas...')
              else if (_erroConexao && _metas.isEmpty)
                _EstadoErro(
                  texto: 'Não foi possível carregar as metas',
                  onRetry: () => _carregar(),
                )
              else ...[
                if (metasFiltradas.isNotEmpty) ...[
                  _gradeDestaque(lg, destaque, secundarias),
                  const SizedBox(height: 24),
                ],

                // Busca
                _CampoBusca(
                  hint: 'Buscar meta...',
                  onChanged: (v) => setState(() => _busca = v),
                  fullWidth: !sm,
                ),
                const SizedBox(height: 16),

                // Lista completa
                _listaCompleta(sm, metasFiltradas),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _gradeDestaque(
    bool lg,
    Map<String, dynamic>? destaque,
    List<Map<String, dynamic>> secundarias,
  ) {
    final cardDestaque = destaque != null
        ? _CardBordaTopo(
            corTopo: _corCategoria(destaque).linha,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _str(destaque['descricao']),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AgroColors.text,
                            fontFamily: kTitleFont,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _PillStatus(info: _statusInfo(destaque)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _AnelProgresso(
                        percentual: _calcPercentual(destaque),
                        cor: _corCategoria(destaque).linha,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatValorMeta(destaque),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AgroColors.text2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  LucideIcons.clock,
                                  size: 12,
                                  color: AgroColors.muted,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Prazo · ${_formatPrazo(destaque['prazo'])}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AgroColors.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_str(destaque['responsavel']).isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Responsável · ${_str(destaque['responsavel'])}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AgroColors.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (lg) const Spacer() else const SizedBox.shrink(),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () => _abrirEdicao(destaque),
                    child: Text(
                      'Ver detalhes',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _corCategoria(destaque).linha,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        : Container(
            constraints: const BoxConstraints(minHeight: 200),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AgroColors.border),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Todas as metas desta categoria foram concluídas 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AgroColors.muted),
            ),
          );

    final cardProgresso = _CardBordaTopo(
      corTopo: _verde,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Progresso geral',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AgroColors.text,
                fontFamily: kTitleFont,
              ),
            ),
            const SizedBox(height: 20),
            if (secundarias.isEmpty)
              const Text(
                'Sem outras metas nesta categoria.',
                style: TextStyle(fontSize: 14, color: AgroColors.muted),
              )
            else
              for (final (i, m) in secundarias.indexed) ...[
                if (i > 0) const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _str(m['descricao']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AgroColors.text2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_calcPercentual(m)}%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AgroColors.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _BarraProgresso(
                  percentual: _calcPercentual(m),
                  cor: _corCategoria(m).barra,
                ),
              ],
          ],
        ),
      ),
    );

    if (lg) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: cardDestaque),
            const SizedBox(width: 20),
            Expanded(child: cardProgresso),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [cardDestaque, const SizedBox(height: 20), cardProgresso],
    );
  }

  Widget _listaCompleta(bool sm, List<Map<String, dynamic>> metasFiltradas) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AgroColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: sm ? 24 : 20,
              vertical: 16,
            ),
            decoration: const BoxDecoration(
              color: AgroColors.canvas,
              border: Border(bottom: BorderSide(color: AgroColors.border)),
            ),
            child: const Text(
              'Todas as metas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AgroColors.text,
                fontFamily: kTitleFont,
              ),
            ),
          ),
          if (metasFiltradas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 80),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE9F1E8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.target,
                      size: 20,
                      color: _spinner,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nenhuma meta encontrada',
                    style: TextStyle(fontSize: 14, color: AgroColors.muted),
                  ),
                  const SizedBox(height: 12),
                  _BotaoSuave(
                    label: 'Criar meta',
                    icon: LucideIcons.plus,
                    onTap: _abrirNovo,
                  ),
                ],
              ),
            )
          else
            for (final (i, m) in metasFiltradas.indexed)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: sm ? 24 : 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: i < metasFiltradas.length - 1
                      ? const Border(
                          bottom: BorderSide(color: AgroColors.cardDivider),
                        )
                      : null,
                ),
                child: _linhaMeta(m, sm),
              ),
        ],
      ),
    );
  }

  Widget _linhaMeta(Map<String, dynamic> m, bool sm) {
    final pct = _calcPercentual(m);
    final info = _statusInfo(m);
    final cor = _corCategoria(m).barra;
    final concluida = m['status'] == 'concluida';

    final check = Tooltip(
      message: concluida ? 'Marcar como pendente' : 'Marcar como concluída',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _alternarConcluida(m),
        child: concluida
            ? const Icon(
                LucideIcons.checkCircle2,
                size: 20,
                color: AgroColors.primary,
              )
            : const Icon(
                LucideIcons.circle,
                size: 20,
                color: Color(0xFFC7D0C4),
              ),
      ),
    );

    final texto = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _str(m['descricao']),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AgroColors.text,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Prazo - ${_formatPrazo(m['prazo'])}',
          style: const TextStyle(fontSize: 12, color: AgroColors.muted),
        ),
      ],
    );

    final progresso = Row(
      children: [
        Expanded(
          child: _BarraProgresso(percentual: pct, cor: cor),
        ),
        const SizedBox(width: 12),
        if (concluida)
          _PillStatus(info: (label: 'Concluída', bg: info.bg, cor: info.cor))
        else
          SizedBox(
            width: 32,
            child: Text(
              '$pct%',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AgroColors.text,
              ),
            ),
          ),
      ],
    );

    final acoes = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BotaoIcone(
          icon: LucideIcons.pencil,
          cor: AgroColors.primary,
          bg: AgroColors.surfaceMuted,
          onTap: () => _abrirEdicao(m),
        ),
        const SizedBox(width: 8),
        _BotaoIcone(
          icon: LucideIcons.trash2,
          cor: _vermelho,
          bg: _vermelhoBg,
          onTap: () => _deletar(m['id']),
        ),
      ],
    );

    if (sm) {
      return Row(
        children: [
          check,
          const SizedBox(width: 16),
          Expanded(child: texto),
          const SizedBox(width: 16),
          SizedBox(width: 192, child: progresso),
          const SizedBox(width: 16),
          acoes,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: check),
        const SizedBox(height: 12),
        texto,
        const SizedBox(height: 12),
        progresso,
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerRight, child: acoes),
      ],
    );
  }
}

// ============================================================
// Modal
// ============================================================

class _MetaModal extends StatefulWidget {
  const _MetaModal({
    required this.editando,
    required this.form,
    required this.propriedades,
    required this.carregar,
  });

  final Map<String, dynamic>? editando;
  final _FormMeta form;
  final List<({String id, String nome})> propriedades;
  final Future<void> Function() carregar;

  @override
  State<_MetaModal> createState() => _MetaModalState();
}

class _MetaModalState extends State<_MetaModal> {
  late final _FormMeta _form = widget.form;
  late final _descricao = TextEditingController(text: _form.descricao);
  late final _valorAtual = TextEditingController(text: _form.valorAtual);
  late final _valorAlvo = TextEditingController(text: _form.valorAlvo);
  late final _unidade = TextEditingController(text: _form.unidade);
  late final _responsavel = TextEditingController(text: _form.responsavel);
  bool _salvando = false;
  String _erro = '';

  @override
  void dispose() {
    _descricao.dispose();
    _valorAtual.dispose();
    _valorAlvo.dispose();
    _unidade.dispose();
    _responsavel.dispose();
    super.dispose();
  }

  void _fechar() => Navigator.of(context).pop();

  Future<void> _salvar() async {
    _form
      ..descricao = _descricao.text
      ..valorAtual = _valorAtual.text
      ..valorAlvo = _valorAlvo.text
      ..unidade = _unidade.text
      ..responsavel = _responsavel.text;
    if (_form.descricao.trim().isEmpty || _form.prazo.isEmpty) {
      setState(() => _erro = 'Preencha ao menos a descrição e o prazo.');
      return;
    }

    setState(() {
      _salvando = true;
      _erro = '';
    });

    try {
      // Busca a propriedade direto do banco, ignora o form
      final props = asList((await api.get('/propriedades')).data);
      final propriedadeId = props.isNotEmpty ? props.first['id'] : null;

      if (propriedadeId == null) {
        if (mounted) {
          setState(() {
            _erro = 'Cadastre uma propriedade antes de criar metas.';
            _salvando = false;
          });
        }
        return;
      }

      final payload = <String, dynamic>{
        'propriedade_id': propriedadeId,
        'descricao': _form.descricao.trim(),
        'categoria': _form.categoria,
        'valor_alvo': _form.valorAlvo.isNotEmpty
            ? num.tryParse(_form.valorAlvo)
            : null,
        'valor_atual': _form.valorAtual.isNotEmpty
            ? num.tryParse(_form.valorAtual)
            : 0,
        'unidade': _form.unidade.isNotEmpty ? _form.unidade : null,
        'responsavel': _form.responsavel.isNotEmpty ? _form.responsavel : null,
        'prazo': _form.prazo,
        'status': _form.status,
      };

      final editando = widget.editando;
      if (editando != null) {
        await api.put('/metas/${editando['id']}', data: payload);
      } else {
        await api.post('/metas', data: payload);
      }

      await widget.carregar();
      if (mounted) _fechar();
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Erro ao salvar meta. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sm = MediaQuery.sizeOf(context).width >= 640;
    final editando = widget.editando != null;
    final idsValidos = widget.propriedades.map((p) => p.id).toSet();
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AgroColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 448),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(sm ? 24 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _CabecalhoModal(
                titulo: editando ? 'Editar meta' : 'Nova meta',
                onFechar: _fechar,
              ),
              const SizedBox(height: 16),

              const _RotuloModal('Propriedade *'),
              DropdownButtonFormField<String>(
                initialValue: idsValidos.contains(_form.propriedadeId)
                    ? _form.propriedadeId
                    : '',
                isExpanded: true,
                isDense: true,
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(8),
                style: const TextStyle(fontSize: 14, color: AgroColors.text),
                icon: const Icon(
                  LucideIcons.chevronDown,
                  size: 16,
                  color: AgroColors.text,
                ),
                decoration: _decoracaoModal(),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Selecione uma propriedade'),
                  ),
                  for (final p in widget.propriedades)
                    DropdownMenuItem(value: p.id, child: Text(p.nome)),
                ],
                onChanged: (v) => setState(() => _form.propriedadeId = v ?? ''),
              ),
              const SizedBox(height: 16),

              _CampoModal(
                label: 'Descrição *',
                controller: _descricao,
                hint: 'Ex: Produção anual de milho',
              ),
              const SizedBox(height: 12),

              const _RotuloModal('Categoria'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in const [
                    'producao',
                    'financeiro',
                    'sustentabilidade',
                    'geral',
                  ])
                    _Chip(
                      label: _categoriaLabel[c]!,
                      ativo: _form.categoria == c,
                      bg: _coresCategoria[c]!.bg,
                      texto: _coresCategoria[c]!.texto,
                      borda: _coresCategoria[c]!.linha,
                      onTap: () => setState(() => _form.categoria = c),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _CampoModal(
                      label: 'Valor atual',
                      controller: _valorAtual,
                      hint: '0',
                      numerico: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CampoModal(
                      label: 'Valor alvo',
                      controller: _valorAlvo,
                      hint: 'Ex: 800',
                      numerico: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _CampoModal(
                      label: 'Unidade',
                      controller: _unidade,
                      hint: 'ton, kg, %...',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CampoDataModal(
                      label: 'Prazo *',
                      value: _form.prazo,
                      onChanged: (v) => setState(() => _form.prazo = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _CampoModal(
                label: 'Responsável',
                controller: _responsavel,
                hint: 'Ex: Talhão 1 e 2',
              ),
              const SizedBox(height: 12),

              const _RotuloModal('Status'),
              Row(
                children: [
                  for (final (i, s) in _statusOpcoes.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _BotaoStatus(
                        label: s.label,
                        ativo: _form.status == s.key,
                        onTap: () => setState(() => _form.status = s.key),
                      ),
                    ),
                  ],
                ],
              ),

              if (_erro.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  _erro,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _RodapeModal(
                salvando: _salvando,
                labelSalvar: editando ? 'Salvar alterações' : 'Adicionar',
                onCancelar: _fechar,
                onSalvar: _salvar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Subcomponentes específicos de Metas
// ============================================================

class _AnelProgresso extends StatelessWidget {
  const _AnelProgresso({required this.percentual, required this.cor});
  final int percentual;
  final Color cor;
  static const double tamanho = 108;
  static const double espessura = 10;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: tamanho,
    height: tamanho,
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: percentual / 100),
      duration: const Duration(milliseconds: 600),
      curve: Curves.ease,
      builder: (context, v, child) =>
          CustomPaint(painter: _AnelPainter(v, cor, espessura), child: child),
      child: Center(
        child: Text(
          '$percentual%',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AgroColors.text,
            fontFamily: kTitleFont,
          ),
        ),
      ),
    ),
  );
}

class _AnelPainter extends CustomPainter {
  _AnelPainter(this.fracao, this.cor, this.espessura);
  final double fracao;
  final Color cor;
  final double espessura;

  @override
  void paint(Canvas canvas, Size size) {
    final raio = (size.width - espessura) / 2;
    final centro = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      centro,
      raio,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = espessura
        ..color = AgroColors.cardDivider,
    );
    if (fracao <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: centro, radius: raio),
      -math.pi / 2,
      2 * math.pi * fracao.clamp(0, 1),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = espessura
        ..strokeCap = StrokeCap.round
        ..color = cor,
    );
  }

  @override
  bool shouldRepaint(_AnelPainter old) =>
      old.fracao != fracao || old.cor != cor;
}

class _BarraProgresso extends StatelessWidget {
  const _BarraProgresso({required this.percentual, required this.cor});
  final int percentual;
  final Color cor;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: Container(
      height: 8,
      color: AgroColors.track,
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: percentual / 100),
        duration: const Duration(milliseconds: 600),
        curve: Curves.ease,
        builder: (context, v, _) => FractionallySizedBox(
          widthFactor: v.clamp(0, 1),
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Cartão branco com borda 1px #E1E6DF e borda superior de 4px colorida (rounded-lg).
class _CardBordaTopo extends StatelessWidget {
  const _CardBordaTopo({required this.corTopo, required this.child});
  final Color corTopo;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: corTopo, width: 4),
          left: const BorderSide(color: AgroColors.border),
          right: const BorderSide(color: AgroColors.border),
          bottom: const BorderSide(color: AgroColors.border),
        ),
      ),
      child: child,
    ),
  );
}

class _PillStatus extends StatelessWidget {
  const _PillStatus({required this.info});
  final ({String label, Color bg, Color cor}) info;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: info.bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      info.label,
      softWrap: false,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: info.cor,
      ),
    ),
  );
}

class _BotaoStatus extends StatelessWidget {
  const _BotaoStatus({
    required this.label,
    required this.ativo,
    required this.onTap,
  });
  final String label;
  final bool ativo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: ativo ? AgroColors.badgeBg : AgroColors.surfaceMuted,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: ativo ? AgroColors.primary : AgroColors.border),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: ativo ? AgroColors.primary : AgroColors.muted,
            ),
          ),
        ),
      ),
    ),
  );
}

class _AbaCategoria extends StatelessWidget {
  const _AbaCategoria({
    required this.label,
    required this.ativa,
    required this.onTap,
  });
  final String label;
  final bool ativa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: ativa ? AgroColors.primary : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
      side: const BorderSide(color: AgroColors.border),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: ativa ? Colors.white : AgroColors.text2,
          ),
        ),
      ),
    ),
  );
}

// ============================================================
// Subcomponentes visuais
// ============================================================

class _StatusSincronia extends StatelessWidget {
  const _StatusSincronia({
    required this.erroConexao,
    required this.sincronizando,
    required this.ultimaSincronia,
    required this.segundosDesde,
  });

  final bool erroConexao, sincronizando;
  final DateTime? ultimaSincronia;
  final int segundosDesde;

  @override
  Widget build(BuildContext context) {
    final texto = erroConexao
        ? 'Sem conexão com o servidor'
        : sincronizando
        ? 'Sincronizando...'
        : ultimaSincronia != null
        ? 'Atualizado em tempo real · há ${segundosDesde}s'
        : 'Conectando...';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: erroConexao ? const Color(0xFFE36C5C) : AgroColors.mint,
            boxShadow: erroConexao
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFF4FF47B).withValues(alpha: .25),
                      spreadRadius: 3,
                    ),
                  ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: .65),
            ),
          ),
        ),
      ],
    );
  }
}

/// Ícone girando (equivalente a `animate-spin`).
class _Spin extends StatefulWidget {
  const _Spin({required this.child});
  final Widget child;

  @override
  State<_Spin> createState() => _SpinState();
}

class _SpinState extends State<_Spin> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RotationTransition(turns: _c, child: widget.child);
}

class _BotaoAtualizar extends StatelessWidget {
  const _BotaoAtualizar({required this.sincronizando, required this.onTap});
  final bool sincronizando;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const icon = Icon(LucideIcons.refreshCw, size: 16, color: Colors.white);
    return Tooltip(
      message: 'Atualizar agora',
      child: Material(
        color: Colors.white.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: sincronizando ? const _Spin(child: icon) : icon,
            ),
          ),
        ),
      ),
    );
  }
}

class _BotaoNovo extends StatelessWidget {
  const _BotaoNovo({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AgroColors.mint,
    borderRadius: BorderRadius.circular(6),
    child: InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.plus, size: 16, color: AgroColors.primary),
            const SizedBox(width: 8),
            Text(
              label,
              softWrap: false,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AgroColors.primary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CampoBusca extends StatelessWidget {
  const _CampoBusca({
    required this.hint,
    required this.onChanged,
    required this.fullWidth,
  });
  final String hint;
  final ValueChanged<String> onChanged;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: fullWidth ? double.infinity : 384),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AgroColors.border),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.search, size: 16, color: AgroColors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: const TextStyle(fontSize: 14, color: AgroColors.text),
              decoration: InputDecoration(
                hintText: hint,
                isDense: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _EstadoCarregando extends StatelessWidget {
  const _EstadoCarregando(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 96),
    child: Center(
      child: Column(
        children: [
          const _Spin(
            child: Icon(LucideIcons.refreshCw, size: 22, color: _spinner),
          ),
          const SizedBox(height: 12),
          Text(
            texto,
            style: const TextStyle(fontSize: 14, color: AgroColors.muted),
          ),
        ],
      ),
    ),
  );
}

class _EstadoErro extends StatelessWidget {
  const _EstadoErro({required this.texto, required this.onRetry});
  final String texto;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 96),
    child: Center(
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: _vermelhoBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.alertCircle,
              size: 20,
              color: _vermelho,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AgroColors.muted),
          ),
          const SizedBox(height: 12),
          _BotaoSuave(label: 'Tentar novamente', onTap: onRetry),
        ],
      ),
    ),
  );
}

/// Botão pequeno verde-claro (text-xs font-semibold px-3 py-1.5, bg #E8F3EA).
class _BotaoSuave extends StatelessWidget {
  const _BotaoSuave({required this.label, required this.onTap, this.icon});
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AgroColors.badgeBg,
    borderRadius: BorderRadius.circular(6),
    child: InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: AgroColors.primary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AgroColors.primary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BotaoIcone extends StatelessWidget {
  const _BotaoIcone({
    required this.icon,
    required this.cor,
    required this.bg,
    required this.onTap,
  });
  final IconData icon;
  final Color cor, bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: bg,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 13, color: cor),
      ),
    ),
  );
}

// ---------- Peças do modal ----------

class _CabecalhoModal extends StatelessWidget {
  const _CabecalhoModal({required this.titulo, required this.onFechar});
  final String titulo;
  final VoidCallback onFechar;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          titulo,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AgroColors.text,
            fontFamily: kTitleFont,
          ),
        ),
      ),
      Transform.translate(
        offset: const Offset(8, 0),
        child: Tooltip(
          message: 'Fechar janela',
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onFechar,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(LucideIcons.x, size: 18, color: AgroColors.muted),
            ),
          ),
        ),
      ),
    ],
  );
}

class _RotuloModal extends StatelessWidget {
  const _RotuloModal(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      texto,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AgroColors.primary,
      ),
    ),
  );
}

InputDecoration _decoracaoModal({String? hint, Widget? suffix}) {
  OutlineInputBorder b() => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AgroColors.border),
  );
  return InputDecoration(
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: AgroColors.surfaceMuted,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    border: b(),
    enabledBorder: b(),
    focusedBorder: b(),
    suffixIcon: suffix,
    suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 16),
  );
}

class _CampoModal extends StatelessWidget {
  const _CampoModal({
    required this.label,
    required this.controller,
    this.hint,
    this.numerico = false,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool numerico;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      _RotuloModal(label),
      SizedBox(
        height: 40,
        child: TextField(
          controller: controller,
          keyboardType: numerico
              ? const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                )
              : null,
          style: const TextStyle(fontSize: 14, color: AgroColors.text),
          decoration: _decoracaoModal(hint: hint),
        ),
      ),
    ],
  );
}

/// `<input type="date">` — [value] em yyyy-MM-dd ('' = vazio).
class _CampoDataModal extends StatelessWidget {
  const _CampoDataModal({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final d = value.isEmpty ? null : DateTime.tryParse(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _RotuloModal(label),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final r = await showDatePicker(
              context: context,
              initialDate: d ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
              locale: const Locale('pt', 'BR'),
            );
            if (r != null) onChanged(isoDate(r));
          },
          child: SizedBox(
            height: 40,
            child: InputDecorator(
              decoration: _decoracaoModal(
                suffix: const Icon(
                  LucideIcons.calendar,
                  size: 15,
                  color: AgroColors.text,
                ),
              ),
              child: Text(
                d == null ? 'dd/mm/aaaa' : formatPattern(d, 'dd/MM/yyyy'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: d == null ? AgroColors.muted : AgroColors.text,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.ativo,
    required this.bg,
    required this.texto,
    required this.borda,
    required this.onTap,
  });

  final String label;
  final bool ativo;
  final Color bg, texto, borda;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: ativo ? bg : AgroColors.surfaceMuted,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: ativo ? borda : AgroColors.border),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: ativo ? texto : AgroColors.muted,
          ),
        ),
      ),
    ),
  );
}

class _RodapeModal extends StatelessWidget {
  const _RodapeModal({
    required this.salvando,
    required this.labelSalvar,
    required this.onCancelar,
    required this.onSalvar,
  });

  final bool salvando;
  final String labelSalvar;
  final VoidCallback onCancelar;
  final VoidCallback onSalvar;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Material(
          color: AgroColors.surfaceMuted,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onCancelar,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Text(
                  'Cancelar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AgroColors.text2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Opacity(
          opacity: salvando ? .6 : 1,
          child: Material(
            color: AgroColors.primary,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: salvando ? null : onSalvar,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Text(
                    salvando ? 'Salvando...' : labelSalvar,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
