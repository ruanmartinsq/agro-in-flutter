import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Port de src/pages/Financeiro.tsx
class FinanceiroPage extends StatefulWidget {
  const FinanceiroPage({super.key});

  @override
  State<FinanceiroPage> createState() => _FinanceiroPageState();
}

/// "entrada" | "saida" | "fluxo"
typedef _Aba = String;

const _corSaida = Color(0xFFA8553E);
const _bgSaida = Color(0xFFF8ECE8);
const _vermelhoResumo = Color(0xFFE36C5C);

class _Lancamento {
  _Lancamento(Map<String, dynamic> j)
    : id = toInt(j['id']),
      propriedadeId = toInt(j['propriedade_id']),
      tipo = '${j['tipo'] ?? ''}',
      categoria = '${j['categoria'] ?? ''}',
      descricao = '${j['descricao'] ?? ''}',
      valorRaw = j['valor'],
      data = '${j['data'] ?? ''}';

  final int id;
  final int propriedadeId;
  final String tipo;
  final String categoria;
  final String descricao;
  final dynamic valorRaw;
  final String data;

  double get valor => toDouble(valorRaw);
}

/// `new Date(data).toLocaleDateString("pt-BR", { timeZone: "UTC" })`
String _formatData(String data) {
  final d = DateTime.tryParse(data);
  if (d == null) return 'Invalid Date';
  return DateFormat('dd/MM/yyyy', 'pt_BR').format(d.toUtc());
}

/// `new Date(x).toISOString().split("T")[0]`
String _isoUtc(DateTime d) => isoDate(d.toUtc());

String _mensagemErroApi(Object error, String fallback) =>
    apiErrorMessage(error) ?? fallback;

class _FinanceiroPageState extends State<FinanceiroPage> {
  List<_Lancamento> _lancamentos = [];
  bool _loading = true;
  _Aba _aba = 'fluxo';
  String _busca = '';
  String _propriedadeId = '';
  String _erroCarregamento = '';

  @override
  void initState() {
    super.initState();
    _carregar();
    api
        .get('/propriedades')
        .then((res) {
          final data = asList(res.data);
          if (mounted && data.isNotEmpty) {
            setState(() => _propriedadeId = '${data.first['id']}');
          }
        })
        .catchError((_) {
          if (mounted) setState(() => _propriedadeId = '');
        });
  }

  Future<void> _carregar() async {
    try {
      final res = await api.get('/financeiro');
      final lista = asList(res.data).map(_Lancamento.new).toList();
      if (mounted) {
        setState(() {
          _lancamentos = lista;
          _erroCarregamento = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _erroCarregamento = _mensagemErroApi(
            e,
            'Não foi possível carregar os lançamentos financeiros.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _recarregar() {
    setState(() => _loading = true);
    _carregar();
  }

  Future<void> _abrirModal([_Lancamento? editando]) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .4),
      builder: (_) => _LancamentoModal(
        editando: editando,
        propriedadeId: editando != null
            ? '${editando.propriedadeId}'
            : _propriedadeId,
        tipoInicial: editando?.tipo ?? (_aba == 'fluxo' ? 'entrada' : _aba),
        onSalvo: _carregar,
      ),
    );
  }

  Future<void> _deletar(int id) async {
    final ok = await confirmar(context, 'Deseja excluir este lançamento?');
    if (!ok) return;
    try {
      await api.delete('/financeiro/$id');
      await _carregar();
    } catch (e) {
      if (mounted) {
        avisar(context, _mensagemErroApi(e, 'Erro ao excluir lançamento.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final sm = w >= 640;
    final hPad = w >= 1024 ? 40.0 : (sm ? 24.0 : 16.0);

    final totalEntradas = _lancamentos
        .where((l) => l.tipo == 'entrada')
        .fold<double>(0, (s, l) => s + l.valor);
    final totalSaidas = _lancamentos
        .where((l) => l.tipo == 'saida')
        .fold<double>(0, (s, l) => s + l.valor);
    final saldo = totalEntradas - totalSaidas;

    final listaAtiva = _aba == 'fluxo'
        ? _lancamentos
        : _lancamentos.where((l) => l.tipo == _aba).toList();
    final b = _busca.toLowerCase();
    final filtrados = listaAtiva
        .where(
          (l) =>
              l.descricao.toLowerCase().contains(b) ||
              l.categoria.toLowerCase().contains(b),
        )
        .toList();

    Widget conteudo;
    if (_loading) {
      conteudo = const Text(
        'Carregando...',
        style: TextStyle(fontSize: 14, color: AgroColors.muted),
      );
    } else if (_erroCarregamento.isNotEmpty) {
      conteudo = Container(
        padding: const EdgeInsets.symmetric(vertical: 64),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFDDE4DC))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _erroCarregamento,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFFB91C1C),
              ),
            ),
            const SizedBox(height: 12),
            _SmallOutlineButton(
              label: 'Tentar novamente',
              onPressed: _recarregar,
            ),
          ],
        ),
      );
    } else if (filtrados.isEmpty) {
      conteudo = _EmptyState(
        titulo: 'Nenhum lançamento encontrado',
        descricao:
            'Registre uma entrada ou saída para iniciar o controle financeiro.',
        cta: 'Adicionar lançamento',
        onClick: () => _abrirModal(),
      );
    } else {
      conteudo = _Tabela(
        lancamentos: filtrados,
        onEditar: _abrirModal,
        onExcluir: _deletar,
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        PageHeader(
          title: 'Financeiro',
          subtitle: 'Gerencie entradas, saídas e fluxos financeiros',
          actions: [
            _MintButton(
              label: 'Novo lançamento',
              expand: !sm,
              onPressed: () => _abrirModal(),
            ),
          ],
          bottom: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _Resumo(
              itens: [
                (
                  label: 'Total Entradas',
                  valor: totalEntradas,
                  cor: AgroColors.mint,
                  icon: LucideIcons.trendingUp,
                ),
                (
                  label: 'Total Saídas',
                  valor: totalSaidas,
                  cor: _vermelhoResumo,
                  icon: LucideIcons.trendingDown,
                ),
                (
                  label: 'Saldo',
                  valor: saldo,
                  cor: saldo >= 0 ? AgroColors.mint : _vermelhoResumo,
                  icon: null,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, sm ? 32 : 24, hPad, sm ? 32 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Abas
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (key, label) in const [
                    ('entrada', 'Entrada'),
                    ('saida', 'Saída'),
                    ('fluxo', 'Fluxo de Caixa'),
                  ])
                    _AbaButton(
                      label: label,
                      ativa: _aba == key,
                      onTap: () => setState(() => _aba = key),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: _SearchBox(
                  hint: 'Buscar por descrição ou categoria...',
                  onChanged: (v) => setState(() => _busca = v),
                ),
              ),
              const SizedBox(height: 24),
              conteudo,
            ],
          ),
        ),
      ],
    );
  }
}

class _Resumo extends StatelessWidget {
  const _Resumo({required this.itens});
  final List<({String label, double valor, Color cor, IconData? icon})> itens;

  @override
  Widget build(BuildContext context) {
    final sm = MediaQuery.sizeOf(context).width >= 640;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: .10)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < itens.length; i++) ...[
              if (i > 0) const SizedBox(width: 1),
              Expanded(
                child: Container(
                  color: Colors.white.withValues(alpha: .06),
                  padding: EdgeInsets.symmetric(
                    horizontal: sm ? 16 : 12,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (itens[i].icon != null) ...[
                            Icon(itens[i].icon, size: 16, color: itens[i].cor),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              itens[i].label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: .65),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatBRL(itens[i].valor),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: itens[i].cor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AbaButton extends StatelessWidget {
  const _AbaButton({
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

class _Tabela extends StatelessWidget {
  const _Tabela({
    required this.lancamentos,
    required this.onEditar,
    required this.onExcluir,
  });
  final List<_Lancamento> lancamentos;
  final ValueChanged<_Lancamento> onEditar;
  final ValueChanged<int> onExcluir;

  static const _larguraMinima = 720.0;

  Widget _cell(Widget child, {double vPad = 16}) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: vPad),
    child: child,
  );

  Widget _iconBtn(IconData icon, Color bg, Color fg, VoidCallback onTap) =>
      Material(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 13, color: fg),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final total = lancamentos.fold<double>(
      0,
      (s, l) => s + (l.tipo == 'entrada' ? l.valor : -l.valor),
    );
    const header = ['Data', 'Descrição', 'Categoria', 'Tipo', 'Valor', 'Ações'];

    final table = Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(1.4),
        3: IntrinsicColumnWidth(),
        4: IntrinsicColumnWidth(),
        5: IntrinsicColumnWidth(),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(
            color: AgroColors.canvas,
            border: Border(bottom: BorderSide(color: AgroColors.border)),
          ),
          children: [
            for (final h in header)
              _cell(
                Text(
                  h,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AgroColors.muted,
                  ),
                ),
                vPad: 12,
              ),
          ],
        ),
        for (var i = 0; i < lancamentos.length; i++)
          _linha(lancamentos[i], ultima: i == lancamentos.length - 1),
        TableRow(
          decoration: const BoxDecoration(
            color: AgroColors.canvas,
            border: Border(top: BorderSide(color: AgroColors.border, width: 2)),
          ),
          children: [
            _cell(
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AgroColors.text,
                ),
              ),
              vPad: 12,
            ),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            _cell(
              Text(
                formatBRL(total),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AgroColors.text,
                ),
              ),
              vPad: 12,
            ),
            const SizedBox.shrink(),
          ],
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AgroColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, c) => c.maxWidth >= _larguraMinima
            ? table
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: _larguraMinima, child: table),
              ),
      ),
    );
  }

  TableRow _linha(_Lancamento l, {required bool ultima}) {
    final entrada = l.tipo == 'entrada';
    return TableRow(
      decoration: BoxDecoration(
        border: ultima
            ? null
            : const Border(bottom: BorderSide(color: AgroColors.cardDivider)),
      ),
      children: [
        _cell(
          Text(
            _formatData(l.data),
            style: const TextStyle(fontSize: 14, color: AgroColors.text2),
          ),
        ),
        _cell(
          Text(
            l.descricao,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AgroColors.text,
            ),
          ),
        ),
        _cell(
          Align(
            alignment: Alignment.centerLeft,
            child: _Badge(
              l.categoria,
              background: AgroColors.badgeBg,
              color: AgroColors.primary,
              vPad: 4,
            ),
          ),
        ),
        _cell(
          Align(
            alignment: Alignment.centerLeft,
            child: _Badge(
              entrada ? 'Entrada' : 'Saída',
              background: entrada ? AgroColors.badgeBg : _bgSaida,
              color: entrada ? AgroColors.primary : _corSaida,
              vPad: 4,
            ),
          ),
        ),
        _cell(
          Text(
            '${l.tipo == 'saida' ? '- ' : ''}${formatBRL(l.valor)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: entrada ? AgroColors.primary : _corSaida,
            ),
          ),
        ),
        _cell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _iconBtn(
                LucideIcons.pencil,
                AgroColors.surfaceMuted,
                AgroColors.primary,
                () => onEditar(l),
              ),
              const SizedBox(width: 8),
              _iconBtn(
                LucideIcons.trash2,
                _bgSaida,
                _corSaida,
                () => onExcluir(l.id),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Modal
// ============================================================

class _LancamentoModal extends StatefulWidget {
  const _LancamentoModal({
    required this.editando,
    required this.propriedadeId,
    required this.tipoInicial,
    required this.onSalvo,
  });
  final _Lancamento? editando;
  final String propriedadeId;
  final String tipoInicial;
  final Future<void> Function() onSalvo;

  @override
  State<_LancamentoModal> createState() => _LancamentoModalState();
}

class _LancamentoModalState extends State<_LancamentoModal> {
  late String _tipo;
  late final TextEditingController _descricao;
  late final TextEditingController _categoria;
  late final TextEditingController _valor;
  late final TextEditingController _dataCtrl;
  late String _data; // yyyy-MM-dd
  bool _salvando = false;
  String _erro = '';

  @override
  void initState() {
    super.initState();
    final l = widget.editando;
    _tipo = widget.tipoInicial;
    _descricao = TextEditingController(text: l?.descricao ?? '');
    _categoria = TextEditingController(text: l?.categoria ?? '');
    _valor = TextEditingController(text: l == null ? '' : _jsNum(l.valorRaw));
    if (l != null) {
      final d = DateTime.tryParse(l.data);
      _data = d == null ? '' : _isoUtc(d);
    } else {
      _data = _isoUtc(DateTime.now());
    }
    _dataCtrl = TextEditingController(text: _dataExibicao());
  }

  String _dataExibicao() {
    final d = DateTime.tryParse(_data);
    return d == null ? '' : DateFormat('dd/MM/yyyy').format(d);
  }

  @override
  void dispose() {
    _descricao.dispose();
    _categoria.dispose();
    _valor.dispose();
    _dataCtrl.dispose();
    super.dispose();
  }

  Future<void> _escolherData() async {
    final atual = DateTime.tryParse(_data) ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (d != null && mounted) {
      setState(() {
        _data = isoDate(d);
        _dataCtrl.text = _dataExibicao();
      });
    }
  }

  Future<void> _salvar() async {
    if (_categoria.text.isEmpty ||
        _descricao.text.isEmpty ||
        _valor.text.isEmpty ||
        _data.isEmpty) {
      setState(() => _erro = 'Preencha todos os campos obrigatórios.');
      return;
    }
    final editando = widget.editando;
    if (editando == null && widget.propriedadeId.isEmpty) {
      setState(
        () => _erro = 'Não foi possível identificar sua propriedade. Recarregue a página.',
      );
      return;
    }
    setState(() {
      _salvando = true;
      _erro = '';
    });
    try {
      if (editando != null) {
        await api.put(
          '/financeiro/${editando.id}',
          data: {
            'tipo': _tipo,
            'categoria': _categoria.text,
            'descricao': _descricao.text,
            'valor': _jsNumber(_valor.text),
            'data': _data,
          },
        );
      } else {
        await api.post(
          '/financeiro',
          data: {
            'propriedade_id': _jsNumber(widget.propriedadeId),
            'tipo': _tipo,
            'categoria': _categoria.text,
            'descricao': _descricao.text,
            'valor': _jsNumber(_valor.text),
            'data': _data,
          },
        );
      }
      await widget.onSalvo();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(
          () => _erro = _mensagemErroApi(
            e,
            'Erro ao salvar lançamento. Tente novamente.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Widget _tipoBtn(String t) {
    final sel = _tipo == t;
    final entrada = t == 'entrada';
    final bg = sel
        ? (entrada ? AgroColors.badgeBg : _bgSaida)
        : AgroColors.surfaceMuted;
    final fg = sel
        ? (entrada ? AgroColors.primary : _corSaida)
        : AgroColors.muted;
    final borda = sel
        ? (entrada ? AgroColors.primary : _corSaida)
        : AgroColors.border;
    return Expanded(
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: borda),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _tipo = t),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              entrada ? 'Entrada' : 'Saída',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.editando != null;
    return _ModalFrame(
      titulo: editando ? 'Editar lançamento' : 'Novo lançamento',
      children: [
        const Text(
          'Tipo *',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AgroColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _tipoBtn('entrada'),
            const SizedBox(width: 8),
            _tipoBtn('saida'),
          ],
        ),
        const SizedBox(height: 12),
        _ModalInput(
          label: 'Descrição *',
          controller: _descricao,
          hint: 'Ex: Venda de Soja',
        ),
        const SizedBox(height: 12),
        _ModalInput(
          label: 'Categoria *',
          controller: _categoria,
          hint: 'Ex: Varejo, Insumos',
        ),
        const SizedBox(height: 12),
        _ModalInput(
          label: 'Valor *',
          controller: _valor,
          hint: 'Ex: 25000',
          number: true,
        ),
        const SizedBox(height: 12),
        _ModalInput(
          label: 'Data *',
          controller: _dataCtrl,
          hint: 'dd/mm/aaaa',
          readOnly: true,
          onTap: _escolherData,
          suffix: const Icon(
            LucideIcons.calendar,
            size: 16,
            color: AgroColors.text,
          ),
        ),
        if (_erro.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            _erro,
            style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
          ),
        ],
        const SizedBox(height: 20),
        _ModalActions(
          salvando: _salvando,
          labelSalvar: editando ? 'Salvar alterações' : 'Adicionar',
          onCancelar: () => Navigator.of(context).pop(),
          onSalvar: _salvar,
        ),
      ],
    );
  }
}

// ============================================================
// Peças visuais
// ============================================================

/// Exibe um número como o JavaScript faria em `{valor}` (500 → "500", 2.5 → "2.5").
String _jsNum(dynamic v) {
  if (v == null) return '';
  if (v is double && v.isFinite && v == v.truncateToDouble()) {
    return v.toInt().toString();
  }
  return v.toString();
}

/// `Number(str)` do JS: "" → 0, inválido → null (NaN vira null no JSON).
num? _jsNumber(String s) {
  final t = s.trim();
  if (t.isEmpty) return 0;
  return num.tryParse(t);
}

/// Botão do cabeçalho (bg #9AE6A6, texto #1F5B3A, rounded-md).
class _MintButton extends StatelessWidget {
  const _MintButton({
    required this.label,
    required this.onPressed,
    this.expand = false,
  });
  final String label;
  final VoidCallback onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final btn = FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AgroColors.mint,
        foregroundColor: AgroColors.primary,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.plus, size: 16),
          const SizedBox(width: 8),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// Campo de busca (bg branco, rounded-md, max-w-sm).
class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.hint, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 384),
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
            decoration: InputDecoration.collapsed(
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 14,
                color: AgroColors.chevron,
              ),
            ).copyWith(filled: false),
          ),
        ),
      ],
    ),
  );
}

/// Estado vazio (border-t #DDE4DC, py-16).
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.titulo,
    required this.descricao,
    required this.cta,
    required this.onClick,
  });
  final String titulo, descricao, cta;
  final VoidCallback onClick;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 64),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0xFFDDE4DC))),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AgroColors.text2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          descricao,
          style: const TextStyle(fontSize: 12, color: Color(0xFF7A877E)),
        ),
        const SizedBox(height: 12),
        _SmallOutlineButton(
          label: cta,
          icon: LucideIcons.plus,
          onPressed: onClick,
        ),
      ],
    ),
  );
}

/// Botão pequeno com borda (#C7D5C7, hover #EDF3EC).
class _SmallOutlineButton extends StatelessWidget {
  const _SmallOutlineButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: AgroColors.primary,
      backgroundColor: Colors.white,
      overlayColor: AgroColors.emptyHover,
      side: const BorderSide(color: AgroColors.emptyBorder),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 13), const SizedBox(width: 6)],
        Text(label),
      ],
    ),
  );
}

/// Pílula arredondada (rounded-full).
class _Badge extends StatelessWidget {
  const _Badge(
    this.text, {
    required this.background,
    required this.color,
    this.vPad = 2,
  });
  final String text;
  final Color background, color;
  final double vPad;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: vPad),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
    ),
  );
}

/// Caixa do modal: max-w-md, rounded-lg, p-5 sm:p-6, borda #E1E6DF.
class _ModalFrame extends StatelessWidget {
  const _ModalFrame({required this.titulo, required this.children});
  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final sm = MediaQuery.sizeOf(context).width >= 640;
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      titulo,
                      style: const TextStyle(
                        fontFamily: kTitleFont,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AgroColors.text,
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(8, 0),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        tooltip: 'Fechar janela',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          LucideIcons.x,
                          size: 18,
                          color: AgroColors.muted,
                        ),
                        style: IconButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _modalInputDecoration(String hint, {Widget? suffix}) {
  final borda = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AgroColors.border),
  );
  return InputDecoration(
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: AgroColors.surfaceMuted,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    border: borda,
    enabledBorder: borda,
    focusedBorder: borda,
    suffixIcon: suffix,
  );
}

/// Rótulo + input do modal (label text-xs #1F5B3A, input h-10 rounded-lg bg #F2F5F0).
class _ModalInput extends StatelessWidget {
  const _ModalInput({
    required this.label,
    required this.controller,
    required this.hint,
    this.number = false,
    this.readOnly = false,
    this.onTap,
    this.suffix,
  });
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool number;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AgroColors.primary,
        ),
      ),
      const SizedBox(height: 4),
      SizedBox(
        height: 40,
        child: TextField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          keyboardType: number
              ? const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                )
              : null,
          style: const TextStyle(fontSize: 14, color: AgroColors.text),
          decoration: _modalInputDecoration(hint, suffix: suffix),
        ),
      ),
    ],
  );
}

/// Botões "Cancelar" / salvar do modal.
class _ModalActions extends StatelessWidget {
  const _ModalActions({
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
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
    );
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: onCancelar,
            style: TextButton.styleFrom(
              backgroundColor: AgroColors.surfaceMuted,
              foregroundColor: AgroColors.text2,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: shape,
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: const Text('Cancelar'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            onPressed: salvando ? null : onSalvar,
            style: FilledButton.styleFrom(
              backgroundColor: AgroColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AgroColors.primary.withValues(alpha: .6),
              disabledForegroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: shape,
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(salvando ? 'Salvando...' : labelSalvar),
          ),
        ),
      ],
    );
  }
}
