import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Port de src/pages/Producao.tsx

// ============================================================
// Tipos e constantes
// ============================================================

/// Categorias: "plantio" | "colheita" | "criacao_animal" | "geral"; aba extra "todas".
const _categorias = <({String key, String label})>[
  (key: 'todas', label: 'Todas'),
  (key: 'plantio', label: 'Plantio'),
  (key: 'colheita', label: 'Colheitas'),
  (key: 'criacao_animal', label: 'Criação animal'),
];

const _categoriaLabel = <String, String>{
  'plantio': 'Plantio',
  'colheita': 'Colheita',
  'criacao_animal': 'Criação animal',
  'geral': 'Geral',
};

class _CorCategoria {
  const _CorCategoria(this.bg, this.texto, this.borda);
  final Color bg, texto, borda;
}

const _coresCategoria = <String, _CorCategoria>{
  'plantio': _CorCategoria(
    Color(0xFFE8F3EA),
    Color(0xFF1F5B3A),
    Color(0xFF4E9462),
  ),
  'colheita': _CorCategoria(
    Color(0xFFFDF3E6),
    Color(0xFF8A5A17),
    Color(0xFFE0A94C),
  ),
  'criacao_animal': _CorCategoria(
    Color(0xFFF2ECE1),
    Color(0xFF6B5636),
    Color(0xFF8B6F47),
  ),
  'geral': _CorCategoria(
    Color(0xFFE8F3EA),
    Color(0xFF1F5B3A),
    Color(0xFF4E9462),
  ),
};

const _statusPresets = ['Plantio', 'Crescimento', 'Colheita', 'Finalizado'];

const _animalKeywords = [
  'gado', 'boi', 'boiada', 'vaca', 'ave', 'aves', 'frango', 'galinha', //
  'suíno', 'suino', 'porco', 'ovino', 'caprino', 'peixe', 'piscicultura', //
  'abelha', 'apicultura', 'leite',
];

const _intervaloSincronia = Duration(milliseconds: 15000);

const _verde = Color(0xFF4E9462);
const _vermelho = Color(0xFFA8553E);
const _vermelhoBg = Color(0xFFF8ECE8);
const _spinner = Color(0xFF8CA88A);
const _divisor = Color(0xFFE3E6DE);

String _categoriaValida(dynamic c) {
  final s = c?.toString() ?? '';
  return _categoriaLabel.containsKey(s) ? s : '';
}

String _inferCategoria(Map<String, dynamic> p) {
  final cat = _categoriaValida(p['categoria']);
  if (cat.isNotEmpty) return cat;
  final tipo = (p['tipo'] ?? '').toString().toLowerCase();
  final status = (p['status'] ?? '').toString().toLowerCase();
  if (_animalKeywords.any((k) => tipo.contains(k))) return 'criacao_animal';
  if (status.contains('colheita')) return 'colheita';
  if (status.contains('plantio')) return 'plantio';
  return 'geral';
}

final _numPt = NumberFormat('#,##0.##', 'pt_BR');

String _formatNumeroPt(num n) => _numPt.format(n);

String _formatValorProducao(Map<String, dynamic> p) {
  final area = toDoubleOrNull(p['area_utilizada']);
  if (area != null) return '${_formatNumeroPt(area)}ha';
  final qtd = toDoubleOrNull(p['quantidade']);
  if (qtd != null) {
    final un = (p['unidade'] ?? '').toString();
    final unidade = un.isNotEmpty ? ' $un' : '';
    return '${_formatNumeroPt(qtd)}$unidade';
  }
  return 'Sem valor registrado';
}

/// `String(n)` do JavaScript (120 → "120", 1.5 → "1.5").
String _jsNum(dynamic v) {
  final d = toDoubleOrNull(v);
  if (d == null) return '';
  return d == d.truncateToDouble() ? d.toInt().toString() : d.toString();
}

/// `new Date(v).toISOString().split("T")[0]`
String _isoDia(dynamic v) {
  final d = parseData(v);
  return d == null ? '' : isoDate(d.toUtc());
}

class _FormProducao {
  String tipo = '';
  String categoria = 'plantio';
  String areaUtilizada = '';
  String quantidade = '';
  String unidade = '';
  String dataInicio = '';
  String dataFim = '';
  String status = 'Plantio';
}

// ============================================================
// Página
// ============================================================

class ProducaoPage extends StatefulWidget {
  const ProducaoPage({super.key});

  @override
  State<ProducaoPage> createState() => _ProducaoPageState();
}

class _ProducaoPageState extends State<ProducaoPage> {
  List<Map<String, dynamic>> _producoes = [];
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
      final res = await api.get('/producao');
      if (!mounted) return;
      setState(() {
        _producoes = asList(res.data);
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
    final form = _FormProducao()
      ..categoria = _abaCategoria == 'todas' ? 'plantio' : _abaCategoria;
    _abrirModal(null, form);
  }

  void _abrirEdicao(Map<String, dynamic> p) {
    final status = (p['status'] ?? '').toString();
    final form = _FormProducao()
      ..tipo = (p['tipo'] ?? '').toString()
      ..categoria = _inferCategoria(p)
      ..areaUtilizada = p['area_utilizada'] != null
          ? _jsNum(p['area_utilizada'])
          : ''
      ..quantidade = p['quantidade'] != null ? _jsNum(p['quantidade']) : ''
      ..unidade = (p['unidade'] ?? '').toString()
      ..dataInicio = p['data_inicio'] != null ? _isoDia(p['data_inicio']) : ''
      ..dataFim = p['data_fim'] != null ? _isoDia(p['data_fim']) : ''
      ..status = status.isNotEmpty ? status : 'Plantio';
    _abrirModal(p, form);
  }

  void _abrirModal(Map<String, dynamic>? editando, _FormProducao form) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: .4),
      builder: (_) => _ProducaoModal(
        editando: editando,
        form: form,
        carregar: () => _carregar(),
      ),
    );
  }

  Future<void> _deletar(dynamic id) async {
    if (!await confirmar(
      context,
      'Deseja excluir este registro de produção?',
    )) {
      return;
    }
    try {
      await api.delete('/producao/$id');
      await _carregar();
    } catch (_) {
      if (mounted) avisar(context, 'Erro ao excluir produção.');
    }
  }

  List<Map<String, dynamic>> get _producoesFiltradas {
    final b = _busca.toLowerCase();
    return _producoes
        .where(
          (p) =>
              _abaCategoria == 'todas' || _inferCategoria(p) == _abaCategoria,
        )
        .where(
          (p) =>
              (p['tipo'] ?? '').toString().toLowerCase().contains(b) ||
              (p['status'] ?? '').toString().toLowerCase().contains(b),
        )
        .toList();
  }

  // ------------------------------------------------------------
  // Render
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final sm = w >= 640;
    final hPad = w >= 1024 ? 40.0 : (sm ? 24.0 : 16.0);
    final vPad = sm ? 32.0 : 24.0;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        PageHeader(
          title: 'Produção',
          subtitleWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Gerencie suas atividades produtivas',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: .65),
                ),
              ),
              const SizedBox(height: 6),
              _StatusSincronia(
                erroConexao: _erroConexao,
                sincronizando: _sincronizando,
                ultimaSincronia: _ultimaSincronia,
                segundosDesde: _segundosDesde,
              ),
            ],
          ),
          actions: [
            _BotaoAtualizar(
              sincronizando: _sincronizando,
              onTap: () => _carregar(),
            ),
            _BotaoNovo(label: 'Nova produção', onTap: _abrirNovo),
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

              // Busca
              _CampoBusca(
                hint: 'Buscar por tipo ou status...',
                onChanged: (v) => setState(() => _busca = v),
                fullWidth: !sm,
              ),
              const SizedBox(height: 24),

              if (_loading)
                const _EstadoCarregando('Carregando produções...')
              else if (_erroConexao && _producoes.isEmpty)
                _EstadoErro(
                  texto: 'Não foi possível carregar as produções',
                  onRetry: () => _carregar(),
                )
              else
                _lista(sm),
            ],
          ),
        ),
      ],
    );
  }

  Widget _lista(bool sm) {
    final filtradas = _producoesFiltradas;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _verde, width: 2),
      ),
      child: filtradas.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 80),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AgroColors.badgeBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.sprout,
                      size: 20,
                      color: _verde,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nenhuma produção encontrada',
                    style: TextStyle(fontSize: 14, color: AgroColors.muted),
                  ),
                  const SizedBox(height: 12),
                  _BotaoSuave(
                    label: 'Registrar produção',
                    icon: LucideIcons.plus,
                    onTap: _abrirNovo,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                for (final (i, p) in filtradas.indexed)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: sm ? 32 : 20,
                      vertical: sm ? 28 : 20,
                    ),
                    decoration: BoxDecoration(
                      border: i < filtradas.length - 1
                          ? const Border(bottom: BorderSide(color: _divisor))
                          : null,
                    ),
                    child: _linha(p, sm),
                  ),
              ],
            ),
    );
  }

  Widget _linha(Map<String, dynamic> p, bool sm) {
    final status = (p['status'] ?? '').toString();
    final fs = sm ? 18.0 : 16.0;
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${p['tipo'] ?? ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: fs,
            fontWeight: FontWeight.w700,
            color: AgroColors.text,
            fontFamily: kTitleFont,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          status.isNotEmpty ? status : _categoriaLabel[_inferCategoria(p)]!,
          style: const TextStyle(fontSize: 14, color: AgroColors.muted),
        ),
      ],
    );
    final valor = Text(
      _formatValorProducao(p),
      softWrap: false,
      style: TextStyle(
        fontSize: fs,
        fontWeight: FontWeight.w700,
        color: AgroColors.text,
      ),
    );
    final botoes = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BotaoIcone(
          icon: LucideIcons.pencil,
          cor: AgroColors.primary,
          bg: AgroColors.surfaceMuted,
          onTap: () => _abrirEdicao(p),
        ),
        const SizedBox(width: 8),
        _BotaoIcone(
          icon: LucideIcons.trash2,
          cor: _vermelho,
          bg: _vermelhoBg,
          onTap: () => _deletar(p['id']),
        ),
      ],
    );

    if (sm) {
      return Row(
        children: [
          Expanded(child: info),
          const SizedBox(width: 12),
          valor,
          const SizedBox(width: 16),
          botoes,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        info,
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: valor),
            botoes,
          ],
        ),
      ],
    );
  }
}

// ============================================================
// Modal
// ============================================================

class _ProducaoModal extends StatefulWidget {
  const _ProducaoModal({
    required this.editando,
    required this.form,
    required this.carregar,
  });

  final Map<String, dynamic>? editando;
  final _FormProducao form;
  final Future<void> Function() carregar;

  @override
  State<_ProducaoModal> createState() => _ProducaoModalState();
}

class _ProducaoModalState extends State<_ProducaoModal> {
  late final _FormProducao _form = widget.form;
  late final _tipo = TextEditingController(text: _form.tipo);
  late final _area = TextEditingController(text: _form.areaUtilizada);
  late final _qtd = TextEditingController(text: _form.quantidade);
  bool _salvando = false;
  String _erro = '';

  @override
  void dispose() {
    _tipo.dispose();
    _area.dispose();
    _qtd.dispose();
    super.dispose();
  }

  void _fechar() => Navigator.of(context).pop();

  Future<void> _salvar() async {
    _form
      ..tipo = _tipo.text
      ..areaUtilizada = _area.text
      ..quantidade = _qtd.text;
    if (_form.tipo.isEmpty) {
      setState(() => _erro = 'Preencha ao menos o nome/tipo da produção.');
      return;
    }

    setState(() {
      _salvando = true;
      _erro = '';
    });

    try {
      // Busca a propriedade direto do banco
      final props = asList((await api.get('/propriedades')).data);
      final propriedadeId = props.isNotEmpty ? props.first['id'] : null;

      if (propriedadeId == null) {
        if (mounted) {
          setState(() {
            _erro = 'Cadastre uma propriedade antes de registrar produções.';
            _salvando = false;
          });
        }
        return;
      }

      final payload = <String, dynamic>{
        'tipo': _form.tipo,
        'area_utilizada': _form.areaUtilizada.isNotEmpty
            ? num.tryParse(_form.areaUtilizada)
            : null,
        'quantidade': _form.quantidade.isNotEmpty
            ? num.tryParse(_form.quantidade)
            : null,
        'data_inicio': _form.dataInicio.isNotEmpty ? _form.dataInicio : null,
        'data_fim': _form.dataFim.isNotEmpty ? _form.dataFim : null,
        'status': _form.status,
      };

      final editando = widget.editando;
      if (editando != null) {
        await api.put('/producao/${editando['id']}', data: payload);
      } else {
        await api.post(
          '/producao',
          data: {'propriedade_id': propriedadeId, ...payload},
        );
      }

      await widget.carregar();
      if (mounted) _fechar();
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Erro ao salvar produção. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sm = MediaQuery.sizeOf(context).width >= 640;
    final editando = widget.editando != null;
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
                titulo: editando ? 'Editar produção' : 'Nova produção',
                onFechar: _fechar,
              ),
              const SizedBox(height: 16),
              _CampoModal(
                label: 'Tipo / nome *',
                controller: _tipo,
                hint: 'Ex: Soja 2025/2026',
              ),
              const SizedBox(height: 12),
              const _RotuloModal('Categoria'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in const [
                    'plantio',
                    'colheita',
                    'criacao_animal',
                    'geral',
                  ])
                    _Chip(
                      label: _categoriaLabel[c]!,
                      ativo: _form.categoria == c,
                      bg: _coresCategoria[c]!.bg,
                      texto: _coresCategoria[c]!.texto,
                      borda: _coresCategoria[c]!.borda,
                      onTap: () => setState(() => _form.categoria = c),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const _RotuloModal('Status'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in _statusPresets)
                    _Chip(
                      label: s,
                      ativo: _form.status == s,
                      bg: AgroColors.badgeBg,
                      texto: AgroColors.primary,
                      borda: AgroColors.primary,
                      onTap: () => setState(() => _form.status = s),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _CampoModal(
                      label: 'Área utilizada (ha)',
                      controller: _area,
                      hint: 'Ex: 120',
                      numerico: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CampoModal(
                      label: 'Quantidade',
                      controller: _qtd,
                      hint: 'Ex: 150',
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
                    child: _CampoDataModal(
                      label: 'Início',
                      value: _form.dataInicio,
                      onChanged: (v) => setState(() => _form.dataInicio = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CampoDataModal(
                      label: 'Término previsto',
                      value: _form.dataFim,
                      onChanged: (v) => setState(() => _form.dataFim = v),
                    ),
                  ),
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
      side: BorderSide(color: ativa ? AgroColors.primary : _verde, width: 1.5),
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
            color: ativa ? Colors.white : AgroColors.text,
          ),
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
