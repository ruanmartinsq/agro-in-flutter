import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Port de src/pages/Estoque.tsx
class EstoquePage extends StatefulWidget {
  const EstoquePage({super.key});

  @override
  State<EstoquePage> createState() => _EstoquePageState();
}

class _EstoqueItem {
  _EstoqueItem(Map<String, dynamic> j)
    : id = toInt(j['id']),
      propriedadeId = toInt(j['propriedade_id']),
      item = '${j['item'] ?? ''}',
      categoria = '${j['categoria'] ?? ''}',
      quantidadeRaw = j['quantidade'],
      unidade = '${j['unidade'] ?? ''}',
      quantidadeMinimaRaw = j['quantidade_minima'];

  final int id;
  final int propriedadeId;
  final String item;
  final String categoria;
  final dynamic quantidadeRaw;
  final String unidade;
  final dynamic quantidadeMinimaRaw;

  double get quantidade => toDouble(quantidadeRaw);
  double get quantidadeMinima => toDouble(quantidadeMinimaRaw);
}

class _EstoquePageState extends State<EstoquePage> {
  List<_EstoqueItem> _itens = [];
  bool _loading = true;
  String _busca = '';
  String _propriedadeId = '';

  @override
  void initState() {
    super.initState();
    _carregarItens();
    _carregarPropriedade();
  }

  Future<void> _carregarItens() async {
    try {
      final res = await api.get('/estoque');
      final lista = asList(res.data).map(_EstoqueItem.new).toList();
      if (mounted) setState(() => _itens = lista);
    } catch (_) {
      if (mounted) setState(() => _itens = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _carregarPropriedade() async {
    try {
      final data = asList((await api.get('/propriedades')).data);
      if (data.isNotEmpty && mounted) {
        setState(() => _propriedadeId = '${data.first['id']}');
      }
    } catch (_) {
      if (mounted) setState(() => _propriedadeId = '');
    }
  }

  Future<void> _abrirModal([_EstoqueItem? editando]) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .4),
      builder: (_) => _EstoqueModal(
        editando: editando,
        propriedadeId: editando != null
            ? '${editando.propriedadeId}'
            : _propriedadeId,
        onSalvo: _carregarItens,
      ),
    );
  }

  Future<void> _deletar(int id) async {
    final ok = await confirmar(context, 'Deseja excluir este item do estoque?');
    if (!ok) return;
    try {
      await api.delete('/estoque/$id');
      await _carregarItens();
    } catch (_) {
      if (mounted) avisar(context, 'Erro ao excluir item.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final sm = w >= 640;
    final hPad = w >= 1024 ? 40.0 : (sm ? 24.0 : 16.0);
    final b = _busca.toLowerCase();
    final filtrados = _itens
        .where(
          (i) =>
              i.item.toLowerCase().contains(b) ||
              i.categoria.toLowerCase().contains(b),
        )
        .toList();

    Widget conteudo;
    if (_loading) {
      conteudo = const Text(
        'Carregando...',
        style: TextStyle(fontSize: 14, color: AgroColors.muted),
      );
    } else if (filtrados.isEmpty) {
      conteudo = _EmptyState(
        titulo: 'Nenhum item cadastrado',
        descricao:
            'Cadastre insumos ou materiais para acompanhar o saldo do estoque.',
        cta: 'Adicionar item',
        onClick: () => _abrirModal(),
      );
    } else {
      conteudo = ResponsiveGrid(
        sm: 1,
        md: 2,
        xl: 3,
        children: [
          for (final item in filtrados)
            _EstoqueCard(
              item: item,
              onEditar: () => _abrirModal(item),
              onExcluir: () => _deletar(item.id),
            ),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        PageHeader(
          title: 'Estoque',
          subtitle: 'Gerencie os itens do seu estoque',
          actions: [
            _MintButton(
              label: 'Novo item',
              expand: !sm,
              onPressed: () => _abrirModal(),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, sm ? 32 : 24, hPad, sm ? 32 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _SearchBox(
                  hint: 'Buscar item ou categoria...',
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

class _EstoqueCard extends StatelessWidget {
  const _EstoqueCard({
    required this.item,
    required this.onEditar,
    required this.onExcluir,
  });
  final _EstoqueItem item;
  final VoidCallback onEditar, onExcluir;

  int get _percentual {
    if (item.quantidadeMinima == 0) return 100;
    final pct = (item.quantidade / item.quantidadeMinima * 100).round();
    return pct > 100 ? 100 : pct;
  }

  Color _corBarra(int pct) {
    if (pct <= 30) return const Color(0xFFA8553E);
    if (pct <= 60) return const Color(0xFFB49A45);
    return AgroColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final pct = _percentual;
    final cor = _corBarra(pct);
    final baixo = item.quantidade <= item.quantidadeMinima;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AgroColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.item,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AgroColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.categoria,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AgroColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (baixo) ...[
                const SizedBox(width: 8),
                const _Badge(
                  'Estoque baixo',
                  background: Color(0xFFF8ECE8),
                  color: Color(0xFFA8553E),
                  fontSize: 10,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: _jsNum(item.quantidadeRaw),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AgroColors.text,
                    ),
                    children: [
                      TextSpan(
                        text: ' ${item.unidade}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AgroColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  'Mínimo: ${_jsNum(item.quantidadeMinimaRaw)} ${item.unidade}',
                  style: const TextStyle(fontSize: 12, color: AgroColors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 8,
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: AgroColors.track,
              borderRadius: BorderRadius.circular(999),
            ),
            child: FractionallySizedBox(
              widthFactor: pct.clamp(0, 100) / 100,
              heightFactor: 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: cor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$pct% do mínimo',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11, color: AgroColors.muted),
          ),
          const SizedBox(height: 16),
          _CardActions(onEditar: onEditar, onExcluir: onExcluir),
        ],
      ),
    );
  }
}

// ============================================================
// Modal
// ============================================================

class _EstoqueModal extends StatefulWidget {
  const _EstoqueModal({
    required this.editando,
    required this.propriedadeId,
    required this.onSalvo,
  });
  final _EstoqueItem? editando;
  final String propriedadeId;
  final Future<void> Function() onSalvo;

  @override
  State<_EstoqueModal> createState() => _EstoqueModalState();
}

class _EstoqueModalState extends State<_EstoqueModal> {
  late final TextEditingController _item;
  late final TextEditingController _categoria;
  late final TextEditingController _quantidade;
  late final TextEditingController _unidade;
  late final TextEditingController _quantidadeMinima;
  bool _salvando = false;
  String _erro = '';

  @override
  void initState() {
    super.initState();
    final e = widget.editando;
    _item = TextEditingController(text: e?.item ?? '');
    _categoria = TextEditingController(text: e?.categoria ?? '');
    _quantidade = TextEditingController(
      text: e == null ? '' : _jsNum(e.quantidadeRaw),
    );
    _unidade = TextEditingController(text: e?.unidade ?? '');
    _quantidadeMinima = TextEditingController(
      text: e == null ? '' : _jsNum(e.quantidadeMinimaRaw),
    );
  }

  @override
  void dispose() {
    _item.dispose();
    _categoria.dispose();
    _quantidade.dispose();
    _unidade.dispose();
    _quantidadeMinima.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_item.text.isEmpty ||
        _categoria.text.isEmpty ||
        _quantidade.text.isEmpty ||
        _unidade.text.isEmpty) {
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
        // PUT — sem propriedade_id
        await api.put(
          '/estoque/${editando.id}',
          data: {
            'item': _item.text,
            'categoria': _categoria.text,
            'quantidade': _jsNumber(_quantidade.text),
            'unidade': _unidade.text,
            'quantidade_minima': _jsNumber(_quantidadeMinima.text),
          },
        );
      } else {
        // POST — com propriedade_id
        await api.post(
          '/estoque',
          data: {
            'propriedade_id': _jsNumber(widget.propriedadeId),
            'item': _item.text,
            'categoria': _categoria.text,
            'quantidade': _jsNumber(_quantidade.text),
            'unidade': _unidade.text,
            'quantidade_minima': _jsNumber(_quantidadeMinima.text),
          },
        );
      }
      await widget.onSalvo();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Erro ao salvar item. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.editando != null;
    return _ModalFrame(
      titulo: editando ? 'Editar item' : 'Novo item',
      children: [
        _ModalInput(
          label: 'Item *',
          controller: _item,
          hint: 'Ex: Fertilizante NPK',
        ),
        const SizedBox(height: 12),
        _ModalInput(
          label: 'Categoria *',
          controller: _categoria,
          hint: 'Ex: Fertilizante',
        ),
        const SizedBox(height: 12),
        _ModalInput(
          label: 'Quantidade *',
          controller: _quantidade,
          hint: 'Ex: 500',
          number: true,
        ),
        const SizedBox(height: 12),
        _ModalInput(
          label: 'Unidade *',
          controller: _unidade,
          hint: 'Ex: kg, L, sacas',
        ),
        const SizedBox(height: 12),
        _ModalInput(
          label: 'Quantidade mínima',
          controller: _quantidadeMinima,
          hint: 'Ex: 100',
          number: true,
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
    this.fontSize = 12,
  });
  final String text;
  final Color background, color;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );
}

/// Botões "Editar" / "Excluir" dos cartões.
class _CardActions extends StatelessWidget {
  const _CardActions({required this.onEditar, required this.onExcluir});
  final VoidCallback onEditar, onExcluir;

  Widget _btn(
    String label,
    IconData icon,
    Color bg,
    Color fg,
    VoidCallback onTap,
  ) => Expanded(
    child: Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _btn(
        'Editar',
        LucideIcons.pencil,
        AgroColors.surfaceMuted,
        AgroColors.primary,
        onEditar,
      ),
      const SizedBox(width: 8),
      _btn(
        'Excluir',
        LucideIcons.trash2,
        const Color(0xFFF8ECE8),
        const Color(0xFFA8553E),
        onExcluir,
      ),
    ],
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

InputDecoration _modalInputDecoration(String hint) {
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
  );
}

/// Rótulo + input do modal (label text-xs #1F5B3A, input h-10 rounded-lg bg #F2F5F0).
class _ModalInput extends StatelessWidget {
  const _ModalInput({
    required this.label,
    required this.controller,
    required this.hint,
    this.number = false,
  });
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool number;

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
          keyboardType: number
              ? const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                )
              : null,
          style: const TextStyle(fontSize: 14, color: AgroColors.text),
          decoration: _modalInputDecoration(hint),
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
