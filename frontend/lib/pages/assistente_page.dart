import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Port de src/pages/Assistente.tsx
class AssistentePage extends StatefulWidget {
  const AssistentePage({super.key});

  @override
  State<AssistentePage> createState() => _AssistentePageState();
}

class _Fonte {
  _Fonte({
    required this.id,
    required this.titulo,
    required this.organizacao,
    required this.url,
  });
  final int id;
  final String titulo, organizacao, url;

  factory _Fonte.fromJson(Map<String, dynamic> j) => _Fonte(
    id: toInt(j['id']),
    titulo: '${j['titulo'] ?? ''}',
    organizacao: '${j['organizacao'] ?? ''}',
    url: '${j['url'] ?? ''}',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'titulo': titulo,
    'organizacao': organizacao,
    'url': url,
  };
}

class _Mensagem {
  _Mensagem({
    required this.id,
    required this.papel,
    required this.conteudo,
    this.fontes,
    this.aviso,
    this.introducao = false,
  });

  final String id;
  final String papel; // 'usuario' | 'assistente'
  final String conteudo;
  final List<_Fonte>? fontes;
  final String? aviso;
  final bool introducao;

  bool get doUsuario => papel == 'usuario';

  factory _Mensagem.fromJson(Map<String, dynamic> j) => _Mensagem(
    id: '${j['id']}',
    papel: j['papel'] == 'usuario' ? 'usuario' : 'assistente',
    conteudo: '${j['conteudo'] ?? ''}',
    fontes: j['fontes'] is List
        ? asList(j['fontes']).map(_Fonte.fromJson).toList()
        : null,
    aviso: j['aviso'] is String ? j['aviso'] as String : null,
    introducao: j['introducao'] == true,
  );

  // Mesmo formato do JSON.stringify do React (campos ausentes são omitidos).
  Map<String, dynamic> toJson() => {
    'id': id,
    'papel': papel,
    'conteudo': conteudo,
    if (fontes != null) 'fontes': fontes!.map((f) => f.toJson()).toList(),
    if (aviso != null) 'aviso': aviso,
    if (introducao) 'introducao': true,
  };
}

const _chaveConversa = 'agroin_assistente_conversa_v1';

final _mensagemInicial = _Mensagem(
  id: 'boas-vindas',
  papel: 'assistente',
  introducao: true,
  conteudo: 'Olá! Sou o assistente agronômico do Agro.in. Posso ajudar a organizar observações de campo, explicar conceitos e preparar próximos passos seguros. Para uma orientação melhor, diga a cultura, o estágio e sua região.',
);

const _sugestoes = [
  'Como diferenciar estresse hídrico de doença na soja?',
  'O que registrar antes de coletar uma amostra de solo?',
  'Como organizar o monitoramento de pragas no talhão?',
];

const _maxCaracteres = 1800;

List<_Mensagem> _ultimas30(List<_Mensagem> l) =>
    l.length > 30 ? l.sublist(l.length - 30) : l;

List<_Mensagem> _carregarConversa() {
  try {
    final salvo = Storage.getString(_chaveConversa);
    if (salvo == null || salvo.isEmpty) return [_mensagemInicial];
    final bruto = jsonDecode(salvo);
    if (bruto is List && bruto.isNotEmpty) {
      return _ultimas30(asList(bruto).map(_Mensagem.fromJson).toList());
    }
    return [_mensagemInicial];
  } catch (_) {
    return [_mensagemInicial];
  }
}

final _rand = math.Random();
String _criarId() =>
    '${DateTime.now().millisecondsSinceEpoch}-${_rand.nextDouble()}';

class _AssistentePageState extends State<AssistentePage> {
  final _scroll = ScrollController();
  final _entradaCtrl = TextEditingController();
  late final FocusNode _entradaFocus = FocusNode(onKeyEvent: _onKey);
  late List<_Mensagem> _mensagens;
  bool? _ativo; // capacidades?.ativo (null = ainda não carregado / erro)
  bool _enviando = false;
  bool _carregando = true;
  String _erro = '';
  bool _focado = false;

  bool get _disponivel => _ativo == true;

  @override
  void initState() {
    super.initState();
    _mensagens = _carregarConversa();
    _entradaCtrl.addListener(() => setState(() {}));
    _entradaFocus.addListener(
      () => setState(() => _focado = _entradaFocus.hasFocus),
    );
    _carregar();
    _persistirERolar();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _entradaCtrl.dispose();
    _entradaFocus.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final res = await api.get('/assistente/capacidades');
      if (mounted) setState(() => _ativo = asMap(res.data)['ativo'] == true);
    } catch (e) {
      if (apiStatus(e) == 401) {
        if (mounted) context.go('/login');
        return;
      }
      if (mounted) {
        setState(
          () => _erro =
              'Não foi possível verificar a disponibilidade do assistente.',
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  // useEffect([mensagens, enviando]): persiste e rola até o fim.
  void _persistirERolar() {
    Storage.setString(
      _chaveConversa,
      jsonEncode(_ultimas30(_mensagens).map((m) => m.toJson()).toList()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _limparConversa() {
    setState(() {
      _mensagens = [_mensagemInicial];
      _entradaCtrl.clear();
      _erro = '';
    });
    _persistirERolar();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent evento) {
    if (evento is KeyDownEvent &&
        evento.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _enviar();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _enviar([String? sugestao]) async {
    final pergunta = (sugestao ?? _entradaCtrl.text).trim();
    if (pergunta.isEmpty || _enviando || !_disponivel) return;

    final historico = _mensagens
        .where((m) => !m.introducao)
        .toList()
        .reversed
        .take(8)
        .toList()
        .reversed
        .map((m) => {'papel': m.papel, 'conteudo': m.conteudo})
        .toList();
    final mensagemUsuario = _Mensagem(
      id: _criarId(),
      papel: 'usuario',
      conteudo: pergunta,
    );

    setState(() {
      _mensagens = [..._mensagens, mensagemUsuario];
      _entradaCtrl.clear();
      _erro = '';
      _enviando = true;
    });
    _persistirERolar();

    try {
      final res = await api.post(
        '/assistente/perguntar',
        data: {'mensagem': pergunta, 'historico': historico},
      );
      final data = asMap(res.data);
      if (!mounted) return;
      setState(() {
        _mensagens = [
          ..._mensagens,
          _Mensagem(
            id: _criarId(),
            papel: 'assistente',
            conteudo: '${data['resposta'] ?? ''}',
            fontes: data['fontes'] is List
                ? asList(data['fontes']).map(_Fonte.fromJson).toList()
                : null,
            aviso: data['aviso'] is String ? data['aviso'] as String : null,
          ),
        ];
      });
    } catch (e) {
      if (apiStatus(e) == 401) {
        if (mounted) context.go('/login');
        return;
      }
      if (mounted) {
        setState(
          () => _erro =
              apiErrorMessage(e) ??
              'Não foi possível obter uma resposta. Tente novamente.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
        _persistirERolar();
      }
    }
  }

  // Links externos (target=_blank): abre no navegador/app padrão.
  Future<void> _abrirFonte(_Fonte f) async {
    final uri = Uri.tryParse(f.url);
    final ok =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      await Clipboard.setData(ClipboardData(text: f.url));
      if (mounted) avisar(context, 'Link da fonte copiado: ${f.url}');
    }
  }

  // ------------------------------------------------------------
  // Render
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final w = size.width;
    final sm = w >= 640, md = w >= 768, lg = w >= 1024;
    final hPadHeader = lg ? 40.0 : (md ? 32.0 : 20.0);
    final hPad = lg ? 40.0 : (md ? 32.0 : (sm ? 20.0 : 12.0));
    final alturaChat = (size.height - 240).clamp(560.0, 790.0);

    final statusTexto = _carregando
        ? 'Conectando...'
        : _disponivel
        ? 'Pronto para orientar'
        : 'Temporariamente indisponível';

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Header
        Container(
          decoration: BoxDecoration(
            color: hex('#163B2A'),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: .1)),
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: hPadHeader,
            vertical: lg ? 32 : 28,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              LucideIcons.leaf,
                              size: 13,
                              color: hex('#A7DBAE'),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'SUPORTE TÉCNICO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 9 * .2,
                                color: hex('#A7DBAE'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Orientação agronômica',
                          style: TextStyle(
                            fontSize: md ? 32 : 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: (md ? 32 : 24) * -.04,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 672),
                          child: Text(
                            'Consulte referências técnicas e registre observações da lavoura.',
                            style: TextStyle(
                              fontSize: md ? 13 : 12,
                              height: 20 / (md ? 13 : 12),
                              color: Colors.white.withValues(alpha: .62),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (sm) ...[
                    const SizedBox(width: 32),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _disponivel
                                  ? hex('#63DB7B')
                                  : hex('#E2B95B'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            statusTexto,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: .72),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: hPad,
                vertical: md ? 24 : 16,
              ),
              child: lg
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _chat(alturaChat, sm, md)),
                        const SizedBox(width: 24),
                        SizedBox(width: 250, child: _aside()),
                      ],
                    )
                  : _chat(alturaChat, sm, md),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chat(double altura, bool sm, bool md) {
    final hPadMsgs = md ? 24.0 : (sm ? 16.0 : 12.0);
    return Container(
      height: altura,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: hex('#D1DAD0')),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Topo do chat
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: md ? 20 : 16,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: hex('#E5E9E2'))),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: hex('#E8F3E5'),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          LucideIcons.bot,
                          size: 17,
                          color: hex('#236537'),
                        ),
                      ),
                      if (_disponivel)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hex('#4DBD65'),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assistente Agro.in',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: hex('#25362A'),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _carregando
                            ? 'Preparando a conversa...'
                            : _disponivel
                            ? 'Orientação com referências técnicas'
                            : 'Serviço temporariamente indisponível',
                        style: TextStyle(fontSize: 10, color: hex('#7A867A')),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: 'Iniciar nova conversa',
                  child: TextButton(
                    onPressed: _limparConversa,
                    style:
                        TextButton.styleFrom(
                          foregroundColor: hex('#687568'),
                          minimumSize: Size(sm ? 0 : 40, sm ? 36 : 40),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ).copyWith(
                          backgroundColor: WidgetStateProperty.resolveWith(
                            (s) => s.contains(WidgetState.hovered)
                                ? hex('#F1F4EF')
                                : Colors.transparent,
                          ),
                          foregroundColor: WidgetStateProperty.resolveWith(
                            (s) => s.contains(WidgetState.hovered)
                                ? hex('#34513A')
                                : hex('#687568'),
                          ),
                          overlayColor: const WidgetStatePropertyAll(
                            Colors.transparent,
                          ),
                        ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.rotateCcw, size: 13),
                        if (sm) ...[
                          const SizedBox(width: 6),
                          const Text('Nova conversa'),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Mensagens
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: EdgeInsets.symmetric(horizontal: hPadMsgs, vertical: 20),
              children: [
                if (!_carregando && !_disponivel) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: hex('#FFF9E7'),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: hex('#E7D8A8')),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            LucideIcons.circleAlert,
                            size: 18,
                            color: hex('#6E591B'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assistente indisponível neste momento',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: hex('#6E591B'),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tente novamente em alguns instantes. Seus outros módulos continuam funcionando.',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 20 / 11,
                                  color: hex('#6E591B'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                for (final m in _mensagens) ...[
                  _Entrada(
                    key: ValueKey(m.id),
                    child: _MensagemView(mensagem: m, onFonte: _abrirFonte),
                  ),
                  const SizedBox(height: 20),
                ],
                if (_enviando)
                  _Entrada(
                    child: Row(
                      children: [
                        const _AvatarBot(),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: hex('#F4F7F1'),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                              bottomLeft: Radius.circular(6),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _Girando(
                                child: Icon(
                                  LucideIcons.loaderCircle,
                                  size: 14,
                                  color: hex('#6D786D'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Consultando referências técnicas...',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: hex('#6D786D'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Sugestões
          if (_mensagens.length == 1 && _disponivel)
            Container(
              padding: EdgeInsets.symmetric(horizontal: hPadMsgs, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: hex('#E8ECE5'))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PERGUNTAS PARA COMEÇAR',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 9 * .14,
                      color: hex('#8A9589'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, c) {
                      const gap = 8.0;
                      final largura = math.max(
                        210.0,
                        (c.maxWidth - gap * (_sugestoes.length - 1)) /
                            _sugestoes.length,
                      );
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(bottom: 4),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < _sugestoes.length; i++) ...[
                                if (i > 0) const SizedBox(width: gap),
                                SizedBox(
                                  width: largura,
                                  child: _BotaoSugestao(
                                    texto: _sugestoes[i],
                                    onTap: () => _enviar(_sugestoes[i]),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

          // Erro
          if (_erro.isNotEmpty)
            Container(
              margin: EdgeInsets.fromLTRB(hPadMsgs, 0, hPadMsgs, 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: hex('#FFF0EB'),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      LucideIcons.circleAlert,
                      size: 14,
                      color: hex('#95492F'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _erro,
                      style: TextStyle(
                        fontSize: 10,
                        height: 16 / 10,
                        color: hex('#95492F'),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Formulário
          Container(
            padding: EdgeInsets.all(md ? 16 : 12),
            decoration: BoxDecoration(
              color: hex('#FAFBF8'),
              border: Border(top: BorderSide(color: hex('#E2E7DF'))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _focado ? hex('#70A276') : hex('#C9D4C8'),
                    ),
                    boxShadow: _focado
                        ? [
                            BoxShadow(
                              color: hex('#70A276', .1),
                              spreadRadius: 3,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: 48,
                            maxHeight: 128,
                          ),
                          child: TextField(
                            controller: _entradaCtrl,
                            focusNode: _entradaFocus,
                            enabled: _disponivel && !_enviando,
                            minLines: 2,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(_maxCaracteres),
                            ],
                            style: TextStyle(
                              fontSize: 12,
                              height: 20 / 12,
                              color: hex('#26352A'),
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: false,
                              hintText: _disponivel
                                  ? 'Conte o que observou na lavoura...'
                                  : 'Assistente temporariamente indisponível',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: hex('#9AA39A'),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _BotaoEnviar(
                        enviando: _enviando,
                        onTap:
                            (_entradaCtrl.text.trim().isEmpty ||
                                !_disponivel ||
                                _enviando)
                            ? null
                            : _enviar,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          sm
                              ? 'Enter envia · Shift + Enter quebra a linha'
                              : 'Digite sua dúvida com detalhes',
                          style: TextStyle(fontSize: 9, color: hex('#929C91')),
                        ),
                      ),
                      Text(
                        '${_entradaCtrl.text.length}/1.800',
                        style: TextStyle(fontSize: 9, color: hex('#929C91')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _aside() {
    const passos = [
      ('01', 'Cultura e fase', 'Ex.: soja em floração'),
      ('02', 'Local e clima', 'Região, chuva ou seca recente'),
      ('03', 'Sinais observados', 'Onde começou e como evoluiu'),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(left: 20),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: hex('#CBD7C7'))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UMA BOA PERGUNTA INCLUI',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 9 * .18,
                    color: hex('#66806A'),
                  ),
                ),
                for (final (numero, titulo, detalhe) in passos) ...[
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          numero,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: hex('#8AA08C'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titulo,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: hex('#2C3E31'),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              detalhe,
                              style: TextStyle(
                                fontSize: 10,
                                height: 16 / 10,
                                color: hex('#7B877B'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          _CartaoAnaliseFoliar(onTap: () => context.go('/analise-foliar')),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  LucideIcons.shieldCheck,
                  size: 17,
                  color: hex('#78652E'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Orientação responsável',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: hex('#78652E'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Confirme diagnósticos, defensivos e doses com análise e responsável técnico.',
                      style: TextStyle(
                        fontSize: 10,
                        height: 2,
                        color: hex('#82764F'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Icon(LucideIcons.mapPin, size: 12, color: hex('#8A948A')),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Informe apenas a região necessária para contextualizar a resposta.',
                  style: TextStyle(
                    fontSize: 9,
                    height: 16 / 9,
                    color: hex('#8A948A'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Widgets privados
// ------------------------------------------------------------

class _AvatarBot extends StatelessWidget {
  const _AvatarBot();

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      color: hex('#E8F3E5'),
      borderRadius: BorderRadius.circular(6),
    ),
    alignment: Alignment.center,
    child: Icon(LucideIcons.bot, size: 15, color: hex('#286738')),
  );
}

class _MensagemView extends StatelessWidget {
  const _MensagemView({required this.mensagem, required this.onFonte});
  final _Mensagem mensagem;
  final ValueChanged<_Fonte> onFonte;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final sm = w >= 640, md = w >= 768;
    final usuario = mensagem.doUsuario;
    final fontes = mensagem.fontes ?? const <_Fonte>[];

    final balao = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: usuario ? hex('#164D28') : hex('#F4F7F1'),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(6),
          topRight: const Radius.circular(6),
          bottomLeft: const Radius.circular(6),
          bottomRight: Radius.circular(usuario ? 0 : 6),
        ),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontSize: sm ? 13 : 12,
          height: 24 / (sm ? 13 : 12),
          color: usuario ? Colors.white : hex('#354239'),
        ),
        child: _ConteudoMensagem(texto: mensagem.conteudo),
      ),
    );

    final corpo = Column(
      crossAxisAlignment: usuario
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        balao,
        if (fontes.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: hex('#B7CDB4'), width: 2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.bookOpen, size: 12, color: hex('#738073')),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'FONTES USADAS NESTA RESPOSTA',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 9 * .14,
                          color: hex('#738073'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final f in fontes)
                  _LinkFonte(fonte: f, onTap: () => onFonte(f)),
              ],
            ),
          ),
        if (mensagem.aviso != null && mensagem.aviso!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 4, right: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    LucideIcons.shieldCheck,
                    size: 11,
                    color: hex('#846E3D'),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    mensagem.aviso!,
                    style: TextStyle(
                      fontSize: 9,
                      height: 16 / 9,
                      color: hex('#846E3D'),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, c) {
        final maxLargura = c.maxWidth * (md ? .78 : .88);
        final limitado = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxLargura),
          child: corpo,
        );
        return Row(
          mainAxisAlignment: usuario
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!usuario) ...[
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: _AvatarBot(),
              ),
              SizedBox(width: sm ? 12 : 10),
            ],
            Flexible(child: limitado),
          ],
        );
      },
    );
  }
}

class _LinkFonte extends StatefulWidget {
  const _LinkFonte({required this.fonte, required this.onTap});
  final _Fonte fonte;
  final VoidCallback onTap;

  @override
  State<_LinkFonte> createState() => _LinkFonteState();
}

class _LinkFonteState extends State<_LinkFonte> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cor = _hover ? hex('#1F5B3A') : hex('#376244');
    final f = widget.fonte;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Tooltip(
          message: f.url,
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6, right: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '[${f.id}] ${f.titulo}'),
                        TextSpan(
                          text: ' · ${f.organizacao}',
                          style: TextStyle(color: hex('#8C958B')),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: cor),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(LucideIcons.externalLink, size: 11, color: cor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Port de ConteudoMensagem: listas com marcador, numeradas e parágrafos.
class _ConteudoMensagem extends StatelessWidget {
  const _ConteudoMensagem({required this.texto});
  final String texto;

  static final _marcador = RegExp(r'^[-•]\s');
  static final _numerado = RegExp(r'^\d+\.\s');

  @override
  Widget build(BuildContext context) {
    final estilo = DefaultTextStyle.of(context).style;
    final fonte = estilo.fontSize ?? 13;
    final linhas = texto.split('\n');
    final filhos = <Widget>[];
    for (var i = 0; i < linhas.length; i++) {
      if (i > 0) filhos.add(const SizedBox(height: 10));
      final limpa = linhas[i].trim();
      if (limpa.isEmpty) {
        filhos.add(const SizedBox(height: 4));
      } else if (_marcador.hasMatch(limpa)) {
        filhos.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  top: fonte * .65 + ((estilo.height ?? 1.5) - 1) * fonte / 2,
                ),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (estilo.color ?? AgroColors.text).withValues(
                      alpha: .45,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(limpa.replaceFirst(RegExp(r'^[-•]\s*'), '')),
              ),
            ],
          ),
        );
      } else if (_numerado.hasMatch(limpa)) {
        final numero = RegExp(r'^\d+').firstMatch(limpa)?.group(0);
        filhos.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 16),
                child: Text(
                  '$numero.',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(limpa.replaceFirst(RegExp(r'^\d+\.\s*'), '')),
              ),
            ],
          ),
        );
      } else {
        filhos.add(Text(limpa.replaceAll('**', '')));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: filhos,
    );
  }
}

class _BotaoSugestao extends StatefulWidget {
  const _BotaoSugestao({required this.texto, required this.onTap});
  final String texto;
  final VoidCallback onTap;

  @override
  State<_BotaoSugestao> createState() => _BotaoSugestaoState();
}

class _BotaoSugestaoState extends State<_BotaoSugestao> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _hover ? hex('#EAF3E7') : hex('#F2F5F0'),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          widget.texto,
          style: TextStyle(
            fontSize: 10,
            height: 16 / 10,
            color: _hover ? hex('#1F5B3A') : hex('#3F5D46'),
          ),
        ),
      ),
    ),
  );
}

class _BotaoEnviar extends StatefulWidget {
  const _BotaoEnviar({required this.enviando, required this.onTap});
  final bool enviando;
  final VoidCallback? onTap;

  @override
  State<_BotaoEnviar> createState() => _BotaoEnviarState();
}

class _BotaoEnviarState extends State<_BotaoEnviar> {
  bool _hover = false;
  bool _pressionado = false;

  @override
  Widget build(BuildContext context) {
    final ativo = widget.onTap != null;
    return Tooltip(
      message: 'Enviar pergunta',
      child: MouseRegion(
        cursor: ativo ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTapDown: ativo ? (_) => setState(() => _pressionado = true) : null,
          onTapUp: ativo ? (_) => setState(() => _pressionado = false) : null,
          onTapCancel: () => setState(() => _pressionado = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _pressionado ? .95 : 1,
            duration: const Duration(milliseconds: 100),
            child: Opacity(
              opacity: ativo ? 1 : .35,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ativo && _hover ? hex('#17482F') : hex('#1F5B3A'),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: widget.enviando
                    ? const _Girando(
                        child: Icon(
                          LucideIcons.loaderCircle,
                          size: 17,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        LucideIcons.send,
                        size: 17,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CartaoAnaliseFoliar extends StatefulWidget {
  const _CartaoAnaliseFoliar({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_CartaoAnaliseFoliar> createState() => _CartaoAnaliseFoliarState();
}

class _CartaoAnaliseFoliarState extends State<_CartaoAnaliseFoliar> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final borda = BorderSide(color: hex('#D7DED3'));
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            border: Border(top: borda, bottom: borda),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: hex('#E7F2E4'),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      LucideIcons.sprout,
                      size: 17,
                      color: hex('#2B6B39'),
                    ),
                  ),
                  const Spacer(),
                  AnimatedSlide(
                    offset: _hover ? const Offset(.125, -.125) : Offset.zero,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      LucideIcons.arrowUpRight,
                      size: 16,
                      color: _hover ? hex('#275D34') : hex('#859087'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Tem uma foto da folha?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: hex('#293A2E'),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Abra a análise foliar para registrar a imagem e acompanhar a evolução.',
                style: TextStyle(
                  fontSize: 10,
                  height: 2,
                  color: hex('#758176'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// .assistente-enter: translateY(6px) + opacity 0 → 1 em 260ms ease-out.
class _Entrada extends StatelessWidget {
  const _Entrada({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOut,
    builder: (_, t, filho) => Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 6 * (1 - t)), child: filho),
    ),
    child: child,
  );
}

/// animate-spin
class _Girando extends StatefulWidget {
  const _Girando({required this.child});
  final Widget child;

  @override
  State<_Girando> createState() => _GirandoState();
}

class _GirandoState extends State<_Girando>
    with SingleTickerProviderStateMixin {
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
