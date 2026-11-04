import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Port de src/pages/Propriedade.tsx
class PropriedadePage extends StatefulWidget {
  const PropriedadePage({super.key});

  @override
  State<PropriedadePage> createState() => _PropriedadePageState();
}

class _Propriedade {
  _Propriedade(Map<String, dynamic> j)
    : id = toInt(j['id']),
      usuarioId = toInt(j['usuario_id']),
      nome = '${j['nome'] ?? ''}',
      areaTotal = j['area_total'],
      tipoProducao = '${j['tipo_producao'] ?? ''}',
      localizacao = '${j['localizacao'] ?? ''}';

  final int id;
  final int usuarioId;
  final String nome;
  final dynamic areaTotal;
  final String tipoProducao;
  final String localizacao;
}

class _PropriedadePageState extends State<PropriedadePage> {
  List<_Propriedade> _propriedades = [];
  bool _loading = true;
  String _busca = '';

  @override
  void initState() {
    super.initState();
    _carregarPropriedades();
  }

  Future<void> _carregarPropriedades() async {
    try {
      final res = await api.get('/propriedades');
      final lista = asList(res.data).map(_Propriedade.new).toList();
      if (mounted) setState(() => _propriedades = lista);
    } catch (_) {
      if (mounted) setState(() => _propriedades = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _abrirModal([_Propriedade? editando]) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .4),
      builder: (_) =>
          _PropriedadeModal(editando: editando, onSalvo: _carregarPropriedades),
    );
  }

  Future<void> _deletar(int id) async {
    final ok = await confirmar(context, 'Deseja excluir esta propriedade?');
    if (!ok) return;
    try {
      await api.delete('/propriedades/$id');
      await _carregarPropriedades();
    } catch (_) {
      if (mounted) avisar(context, 'Erro ao excluir propriedade.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final sm = w >= 640;
    final hPad = w >= 1024 ? 40.0 : (sm ? 24.0 : 16.0);
    final b = _busca.toLowerCase();
    final filtradas = _propriedades
        .where(
          (p) =>
              p.nome.toLowerCase().contains(b) ||
              p.localizacao.toLowerCase().contains(b) ||
              p.tipoProducao.toLowerCase().contains(b),
        )
        .toList();

    Widget conteudo;
    if (_loading) {
      conteudo = const Text(
        'Carregando...',
        style: TextStyle(fontSize: 14, color: AgroColors.muted),
      );
    } else if (filtradas.isEmpty) {
      conteudo = _EmptyState(
        titulo: 'Nenhuma propriedade cadastrada',
        descricao: 'Cadastre a primeira área para organizar produção, estoque e análises.',
        cta: 'Cadastrar propriedade',
        onClick: () => _abrirModal(),
      );
    } else {
      conteudo = ResponsiveGrid(
        sm: 1,
        md: 2,
        xl: 3,
        children: [
          for (final p in filtradas)
            _PropriedadeCard(
              p: p,
              onEditar: () => _abrirModal(p),
              onExcluir: () => _deletar(p.id),
            ),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        PageHeader(
          title: 'Propriedades',
          subtitle: 'Gerencie suas propriedades rurais',
          actions: [
            _MintButton(
              label: 'Nova propriedade',
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
                  hint: 'Buscar por nome ou local...',
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

class _PropriedadeCard extends StatelessWidget {
  const _PropriedadeCard({
    required this.p,
    required this.onEditar,
    required this.onExcluir,
  });
  final _Propriedade p;
  final VoidCallback onEditar, onExcluir;

  @override
  Widget build(BuildContext context) {
    Widget tile(Widget rotulo, String valor) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AgroColors.surfaceMuted,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            rotulo,
            const SizedBox(height: 2),
            Text(
              valor,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AgroColors.text,
              ),
            ),
          ],
        ),
      ),
    );

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
                      p.nome,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AgroColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.mapPin,
                          size: 11,
                          color: AgroColors.muted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            p.localizacao,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AgroColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _Badge(
                'Ativa',
                background: AgroColors.badgeBg,
                color: AgroColors.primary,
                fontSize: 11,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              tile(
                const Text(
                  'Área Total',
                  style: TextStyle(fontSize: 11, color: AgroColors.muted),
                ),
                '${_jsNum(p.areaTotal)} ha',
              ),
              const SizedBox(width: 8),
              tile(
                const Row(
                  children: [
                    Icon(LucideIcons.sprout, size: 11, color: AgroColors.muted),
                    SizedBox(width: 4),
                    Text(
                      'Produção',
                      style: TextStyle(fontSize: 11, color: AgroColors.muted),
                    ),
                  ],
                ),
                p.tipoProducao,
              ),
            ],
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

class _PropriedadeModal extends StatefulWidget {
  const _PropriedadeModal({required this.editando, required this.onSalvo});
  final _Propriedade? editando;
  final Future<void> Function() onSalvo;

  @override
  State<_PropriedadeModal> createState() => _PropriedadeModalState();
}

class _PropriedadeModalState extends State<_PropriedadeModal> {
  late final TextEditingController _nome;
  late final TextEditingController _area;
  late final TextEditingController _tipo;
  late final TextEditingController _local;
  late final String _usuarioId;
  bool _salvando = false;
  String _erro = '';

  @override
  void initState() {
    super.initState();
    final p = widget.editando;
    _nome = TextEditingController(text: p?.nome ?? '');
    _area = TextEditingController(text: p == null ? '' : _jsNum(p.areaTotal));
    _tipo = TextEditingController(text: p?.tipoProducao ?? '');
    _local = TextEditingController(text: p?.localizacao ?? '');
    _usuarioId = p == null ? '1' : '${p.usuarioId}';
  }

  @override
  void dispose() {
    _nome.dispose();
    _area.dispose();
    _tipo.dispose();
    _local.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_nome.text.isEmpty ||
        _area.text.isEmpty ||
        _tipo.text.isEmpty ||
        _local.text.isEmpty) {
      setState(() => _erro = 'Preencha todos os campos obrigatórios.');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = '';
    });
    try {
      final editando = widget.editando;
      if (editando != null) {
        // PUT — sem usuario_id
        await api.put(
          '/propriedades/${editando.id}',
          data: {
            'nome': _nome.text,
            'area_total': _jsNumber(_area.text),
            'tipo_producao': _tipo.text,
            'localizacao': _local.text,
          },
        );
      } else {
        // POST — com usuario_id
        await api.post(
          '/propriedades',
          data: {
            'nome': _nome.text,
            'area_total': _jsNumber(_area.text),
            'tipo_producao': _tipo.text,
            'localizacao': _local.text,
            'usuario_id': _jsNumber(_usuarioId),
          },
        );
      }
      await widget.onSalvo();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Erro ao salvar propriedade. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.editando != null;
    return _ModalFrame(
      titulo: editando ? 'Editar propriedade' : 'Nova propriedade',
      children: [
        _ModalInput(
          label: 'Nome *',
          controller: _nome,
          hint: 'Ex: Fazenda São João',
        ),
        const SizedBox(height: 12),
        _ModalInput(
          label: 'Área total (ha) *',
          controller: _area,
          hint: 'Ex: 340',
          number: true,
        ),
        const SizedBox(height: 12),
        _ModalInput(
          label: 'Tipo de produção *',
          controller: _tipo,
          hint: 'Ex: Soja, Milho, Gado',
        ),
        const SizedBox(height: 12),
        _ModalInput(
          label: 'Localização *',
          controller: _local,
          hint: 'Ex: Mato Grosso, BR',
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
          labelSalvar: editando ? 'Salvar alterações' : 'Cadastrar',
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
