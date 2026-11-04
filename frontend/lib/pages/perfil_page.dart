import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Port de src/pages/Perfil.tsx
class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _AlertaEstoque {
  _AlertaEstoque(this.nome, this.percentual);
  final String nome;
  final int percentual;
}

/// Imprime um valor como o JS faria em `{valor}` (120.0 → "120").
String _jsValor(dynamic v) {
  if (v == null) return '';
  if (v is double && v == v.truncateToDouble()) return v.toInt().toString();
  return '$v';
}

class _PerfilPageState extends State<PerfilPage> {
  Map<String, dynamic>? _usuario;
  List<Map<String, dynamic>> _propriedades = [];
  bool _loading = true;
  bool _editando = false;
  final _formNome = TextEditingController();
  final _formEmail = TextEditingController();
  bool _salvando = false;
  String _erro = '';
  String _sucesso = '';

  final _senhaAtual = TextEditingController();
  final _novaSenha = TextEditingController();
  final _confirmarSenha = TextEditingController();

  bool _notificacoes = true;
  bool _alertaEstoque = true;
  bool _modoEscuro = false;
  List<_AlertaEstoque> _alertasEstoque = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _formNome.dispose();
    _formEmail.dispose();
    _senhaAtual.dispose();
    _novaSenha.dispose();
    _confirmarSenha.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final res = await Future.wait([
        api.get('/auth/me'),
        api.get('/propriedades'),
      ]);
      final user = asMap(res[0].data);
      if (!mounted) return;
      setState(() {
        _usuario = user;
        _propriedades = asList(res[1].data);
        _formNome.text = '${user['nome'] ?? ''}';
        _formEmail.text = '${user['email'] ?? ''}';
      });
    } catch (_) {
      if (mounted) context.go('/login');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _mostrarSucesso(String msg) {
    setState(() => _sucesso = msg);
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) setState(() => _sucesso = '');
    });
  }

  Future<void> _salvarPerfil() async {
    if (_formNome.text.isEmpty || _formEmail.text.isEmpty) {
      setState(() => _erro = 'Preencha todos os campos.');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = '';
    });
    try {
      final res = await api.put(
        '/auth/me',
        data: {'nome': _formNome.text, 'email': _formEmail.text},
      );
      if (!mounted) return;
      setState(() {
        _usuario = asMap(res.data);
        _editando = false;
      });
      _mostrarSucesso('Perfil atualizado com sucesso!');
    } catch (_) {
      if (mounted) setState(() => _erro = 'Erro ao salvar perfil.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _cancelarEdicao() {
    setState(() {
      _editando = false;
      _erro = '';
      _formNome.text = '${_usuario?['nome'] ?? ''}';
      _formEmail.text = '${_usuario?['email'] ?? ''}';
    });
  }

  Future<void> _toggleAlertaEstoque() async {
    final novoValor = !_alertaEstoque;
    setState(() => _alertaEstoque = novoValor);

    if (novoValor) {
      try {
        final res = await api.get('/estoque');
        final baixos = asList(res.data)
            .where(
              (item) =>
                  toDouble(item['quantidade_minima']) > 0 &&
                  toDouble(item['quantidade']) <=
                      toDouble(item['quantidade_minima']),
            )
            .map(
              (item) => _AlertaEstoque(
                '${item['item'] ?? ''}',
                (toDouble(item['quantidade']) /
                        toDouble(item['quantidade_minima']) *
                        100)
                    .round(),
              ),
            )
            .toList();
        if (!mounted) return;
        setState(() => _alertasEstoque = baixos);
        Future.delayed(const Duration(milliseconds: 6000), () {
          if (mounted) setState(() => _alertasEstoque = []);
        });
      } catch (_) {
        // silencioso
      }
    } else {
      setState(() => _alertasEstoque = []);
    }
  }

  Future<void> _abrirModalSenha() async {
    String erroSenha = '';
    bool salvandoSenha = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: .4),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          void fechar() => Navigator.of(ctx).pop();

          Future<void> salvarSenha() async {
            if (_senhaAtual.text.isEmpty ||
                _novaSenha.text.isEmpty ||
                _confirmarSenha.text.isEmpty) {
              setModal(() => erroSenha = 'Preencha todos os campos.');
              return;
            }
            if (_novaSenha.text != _confirmarSenha.text) {
              setModal(() => erroSenha = 'As senhas não coincidem.');
              return;
            }
            if (_novaSenha.text.length < 4) {
              setModal(
                () =>
                    erroSenha = 'A nova senha deve ter ao menos 4 caracteres.',
              );
              return;
            }
            setModal(() {
              salvandoSenha = true;
              erroSenha = '';
            });
            try {
              await api.put(
                '/auth/senha',
                data: {
                  'senhaAtual': _senhaAtual.text,
                  'novaSenha': _novaSenha.text,
                },
              );
              _senhaAtual.clear();
              _novaSenha.clear();
              _confirmarSenha.clear();
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) _mostrarSucesso('Senha alterada com sucesso!');
            } catch (_) {
              if (ctx.mounted) {
                setModal(() => erroSenha = 'Senha atual incorreta.');
              }
            } finally {
              if (ctx.mounted) setModal(() => salvandoSenha = false);
            }
          }

          final sm = MediaQuery.sizeOf(ctx).width >= 640;
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AgroColors.border),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 384),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(sm ? 24 : 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Alterar senha',
                            style: TextStyle(
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
                              onPressed: fechar,
                              style: IconButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              icon: const Icon(
                                LucideIcons.x,
                                size: 18,
                                color: AgroColors.muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    for (final (i, campo) in [
                      ('Senha atual', _senhaAtual),
                      ('Nova senha', _novaSenha),
                      ('Confirmar nova senha', _confirmarSenha),
                    ].indexed) ...[
                      if (i > 0) const SizedBox(height: 12),
                      Text(
                        campo.$1,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AgroColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _CampoPerfil(controller: campo.$2, obscure: true),
                    ],
                    if (erroSenha.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        erroSenha,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _BotaoAcao(
                            label: 'Cancelar',
                            background: AgroColors.surfaceMuted,
                            foreground: AgroColors.text2,
                            weight: FontWeight.w500,
                            onPressed: fechar,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _BotaoAcao(
                            label: salvandoSenha ? 'Salvando...' : 'Alterar',
                            background: AgroColors.primary,
                            foreground: Colors.white,
                            weight: FontWeight.w600,
                            onPressed: salvandoSenha ? null : salvarSenha,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String get _iniciais {
    final nome = _usuario?['nome'];
    if (nome == null) return '';
    return '$nome'
        .split(' ')
        .map((n) => n.isEmpty ? '' : n[0])
        .take(2)
        .join()
        .toUpperCase();
  }

  String get _membroDesde {
    final d = parseData(_usuario?['criado_em']);
    return d == null ? '' : formatPattern(d, "MMMM 'de' y");
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView('Carregando perfil...');

    final w = MediaQuery.sizeOf(context).width;
    final lg = w >= 1024;
    final sm = w >= 640;
    final hPad = lg ? 40.0 : 24.0;

    final colunaEsquerda = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dadosPessoais(sm),
        const SizedBox(height: 20),
        _propriedadesVinculadas(),
      ],
    );
    final colunaDireita = _preferencias();

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: AgroColors.primary,
              padding: EdgeInsets.fromLTRB(hPad, 32, hPad, 24),
              child: const Text(
                'Perfil',
                style: TextStyle(
                  fontFamily: kTitleFont,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 32, hPad, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_sucesso.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AgroColors.badgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _sucesso,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AgroColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _cartaoUsuario(sm),
                  const SizedBox(height: 20),
                  if (lg)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: colunaEsquerda),
                        const SizedBox(width: 20),
                        Expanded(child: colunaDireita),
                      ],
                    )
                  else ...[
                    colunaEsquerda,
                    const SizedBox(height: 20),
                    colunaDireita,
                  ],
                ],
              ),
            ),
          ],
        ),
        // Popups de estoque baixo
        Positioned(
          right: 24,
          bottom: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, alerta) in _alertasEstoque.indexed) ...[
                if (i > 0) const SizedBox(height: 8),
                _PopupEstoque(alerta),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _cartaoUsuario(bool sm) {
    final avatar = Container(
      width: 80,
      height: 80,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AgroColors.primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        _iniciais,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${_usuario?['nome'] ?? ''}',
          style: const TextStyle(
            fontFamily: kTitleFont,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AgroColors.text,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Proprietário · Administrator',
          style: TextStyle(fontSize: 14, color: AgroColors.muted),
        ),
        if (_propriedades.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '${_propriedades[0]['nome'] ?? ''} · Membro desde $_membroDesde',
            style: const TextStyle(fontSize: 12, color: AgroColors.muted),
          ),
        ],
      ],
    );

    final botoes = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(
          onPressed: _abrirModalSenha,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AgroColors.text2,
            side: const BorderSide(color: AgroColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minimumSize: const Size(0, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          child: const Text('Alterar Senha'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () => setState(() => _editando = true),
          style: FilledButton.styleFrom(
            backgroundColor: AgroColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minimumSize: const Size(0, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.pencil, size: 14),
              SizedBox(width: 8),
              Text('Editar perfil'),
            ],
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AgroColors.border),
      ),
      child: sm
          ? Row(
              children: [
                avatar,
                const SizedBox(width: 20),
                Expanded(child: info),
                const SizedBox(width: 20),
                botoes,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                avatar,
                const SizedBox(height: 20),
                info,
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: botoes,
                ),
              ],
            ),
    );
  }

  Widget _dadosPessoais(bool sm) {
    Widget campo(
      String label,
      String valor,
      TextEditingController ctrl,
      bool email,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AgroColors.muted,
          ),
        ),
        const SizedBox(height: 4),
        if (_editando)
          _CampoPerfil(
            controller: ctrl,
            keyboardType: email
                ? TextInputType.emailAddress
                : TextInputType.text,
          )
        else
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: AgroColors.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              valor,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: AgroColors.text),
            ),
          ),
      ],
    );

    final nome = campo(
      'NOME COMPLETO',
      '${_usuario?['nome'] ?? ''}',
      _formNome,
      false,
    );
    final email = campo(
      'E-MAIL',
      '${_usuario?['email'] ?? ''}',
      _formEmail,
      true,
    );

    return _Secao(
      titulo: 'Dados pessoais',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sm)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: nome),
                const SizedBox(width: 16),
                Expanded(child: email),
              ],
            )
          else ...[
            nome,
            const SizedBox(height: 16),
            email,
          ],
          if (_editando) ...[
            if (_erro.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _erro,
                style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _BotaoAcao(
                    label: 'Cancelar',
                    background: AgroColors.surfaceMuted,
                    foreground: AgroColors.text2,
                    weight: FontWeight.w500,
                    onPressed: _cancelarEdicao,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _BotaoAcao(
                    label: _salvando ? 'Salvando...' : 'Salvar alterações',
                    background: AgroColors.primary,
                    foreground: Colors.white,
                    weight: FontWeight.w600,
                    onPressed: _salvando ? null : _salvarPerfil,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _propriedadesVinculadas() {
    return _Secao(
      titulo: 'Propriedades vinculadas',
      child: _propriedades.isEmpty
          ? const Text(
              'Nenhuma propriedade cadastrada.',
              style: TextStyle(fontSize: 14, color: AgroColors.muted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, p) in _propriedades.indexed) ...[
                  if (i > 0) const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AgroColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${p['nome'] ?? ''}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AgroColors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_jsValor(p['area_total'])} ha',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AgroColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: i == 0 ? AgroColors.badgeBg : hex('#FDF3E6'),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            i == 0 ? 'Principal' : 'Secundária',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: i == 0
                                  ? AgroColors.primary
                                  : hex('#8A5A17'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _preferencias() {
    final itens = [
      (
        icon: LucideIcons.bell,
        label: 'Notificações por e-mail',
        desc: 'Resumo semanal da propriedade',
        value: _notificacoes,
        onClick: () => setState(() => _notificacoes = !_notificacoes),
      ),
      (
        icon: LucideIcons.package,
        label: 'Alertas de estoque baixo',
        desc: 'Avisa quando um item atinge o mínimo',
        value: _alertaEstoque,
        onClick: _toggleAlertaEstoque,
      ),
      (
        icon: LucideIcons.keyRound,
        label: 'Modo escuro',
        desc: 'Aplica tema escuro ao painel',
        value: _modoEscuro,
        onClick: () => setState(() => _modoEscuro = !_modoEscuro),
      ),
    ];

    return _Secao(
      titulo: 'Preferências',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, item) in itens.indexed) ...[
            if (i > 0) const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          item.icon,
                          size: 16,
                          color: AgroColors.muted,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AgroColors.text,
                              ),
                            ),
                            Text(
                              item.desc,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AgroColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _Toggle(
                  label: item.label,
                  value: item.value,
                  onTap: item.onClick,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Cartão de seção: rounded-lg, borda #DCE3DB, p-6, título Montserrat.
class _Secao extends StatelessWidget {
  const _Secao({required this.titulo, required this.child});
  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: hex('#DCE3DB')),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontFamily: kTitleFont,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AgroColors.text,
          ),
        ),
        const SizedBox(height: 20),
        child,
      ],
    ),
  );
}

/// Input h-10 rounded-lg bg #F2F5F0 borda #E1E6DF (sem anel de foco).
class _CampoPerfil extends StatelessWidget {
  const _CampoPerfil({
    required this.controller,
    this.obscure = false,
    this.keyboardType,
  });
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final borda = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AgroColors.border),
    );
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, color: AgroColors.text),
        decoration: InputDecoration(
          filled: true,
          fillColor: AgroColors.surfaceMuted,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          border: borda,
          enabledBorder: borda,
          focusedBorder: borda,
        ),
      ),
    );
  }
}

/// Botões flex-1 py-2.5 rounded-md dos formulários.
class _BotaoAcao extends StatelessWidget {
  const _BotaoAcao({
    required this.label,
    required this.background,
    required this.foreground,
    required this.weight,
    required this.onPressed,
  });

  final String label;
  final Color background;
  final Color foreground;
  final FontWeight weight;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      disabledBackgroundColor: background.withValues(alpha: .6),
      disabledForegroundColor: foreground.withValues(alpha: .6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      minimumSize: const Size(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      textStyle: TextStyle(fontSize: 14, fontWeight: weight),
    ),
    child: Text(label, overflow: TextOverflow.ellipsis),
  );
}

/// Interruptor 48x44 com trilho de 28px (#1F5B3A / #D1D5DB) e bolinha branca de 16px.
class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: value,
    label: '$label: ${value ? 'ativado' : 'desativado'}',
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          width: 48,
          height: 44,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 8,
                height: 28,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: value ? AgroColors.primary : hex('#D1D5DB'),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 150),
                top: 14,
                left: value ? 48 - 20 : 4,
                width: 16,
                height: 16,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PopupEstoque extends StatelessWidget {
  const _PopupEstoque(this.alerta);
  final _AlertaEstoque alerta;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 240, maxWidth: 300),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: AgroColors.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1A000000),
          blurRadius: 15,
          spreadRadius: -3,
          offset: Offset(0, 10),
        ),
        BoxShadow(
          color: Color(0x1A000000),
          blurRadius: 6,
          spreadRadius: -4,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: alerta.percentual <= 30 ? hex('#A8553E') : hex('#B49A45'),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                alerta.nome,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AgroColors.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Estoque em ${alerta.percentual}% do mínimo',
                style: const TextStyle(fontSize: 12, color: AgroColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
