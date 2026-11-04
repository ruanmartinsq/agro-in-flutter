import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api.dart';
import '../core/gps.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/analise_foliar_nav.dart';
import '../widgets/common.dart';

/// Port de src/pages/AnaliseFoliar.tsx
class AnaliseFoliarPage extends StatefulWidget {
  const AnaliseFoliarPage({super.key});

  @override
  State<AnaliseFoliarPage> createState() => _AnaliseFoliarPageState();
}

// ---------------------------------------------------------------------------
// Constantes (mesmas do React)
// ---------------------------------------------------------------------------

typedef _Meta = ({String titulo, Color cor, Color fundo});

const _processos = [
  (titulo: 'Qualidade da captura', detalhe: 'luz, foco e enquadramento'),
  (titulo: 'Leitura do tecido', detalhe: 'segmentação e padrões de cor'),
  (titulo: 'Hipóteses visuais', detalhe: 'saúde, doença e estresses'),
  (titulo: 'Plano de confirmação', detalhe: 'campo, laboratório e manejo'),
];

final Map<String, _Meta> _status = {
  'aparentemente_saudavel': (
    titulo: 'Aparentemente saudável',
    cor: hex('#0D6B32'),
    fundo: hex('#E5F7EA'),
  ),
  'possivel_doenca_fungica': (
    titulo: 'Possível doença fúngica',
    cor: hex('#9C4E12'),
    fundo: hex('#FFF0DE'),
  ),
  'possivel_doenca_bacteriana': (
    titulo: 'Possível doença bacteriana',
    cor: hex('#9C4E12'),
    fundo: hex('#FFF0DE'),
  ),
  'possivel_doenca_viral': (
    titulo: 'Possível doença viral',
    cor: hex('#A33A35'),
    fundo: hex('#FCE9E6'),
  ),
  'possivel_praga': (
    titulo: 'Possível presença de praga',
    cor: hex('#9C4E12'),
    fundo: hex('#FFF0DE'),
  ),
  'possivel_estresse_nutricional': (
    titulo: 'Possível estresse nutricional',
    cor: hex('#8A6500'),
    fundo: hex('#FFF5C8'),
  ),
  'possivel_necrose_ou_ressecamento': (
    titulo: 'Possível necrose ou ressecamento',
    cor: hex('#8D4B2A'),
    fundo: hex('#F7E8DD'),
  ),
  'possivel_doenca_ou_estresse': (
    titulo: 'Possível doença ou estresse',
    cor: hex('#9C4E12'),
    fundo: hex('#FFF0DE'),
  ),
  'inconclusivo': (
    titulo: 'Resultado inconclusivo',
    cor: hex('#5D675D'),
    fundo: hex('#EEF1EC'),
  ),
};

final Map<String, _Meta> _comparacao = {
  'melhora_visual': (
    titulo: 'Melhora visual',
    cor: hex('#176B35'),
    fundo: hex('#E4F5E7'),
  ),
  'estavel': (titulo: 'Estável', cor: hex('#526052'), fundo: hex('#EEF1EC')),
  'piora_visual': (
    titulo: 'Piora visual',
    cor: hex('#A0482C'),
    fundo: hex('#FBECE5'),
  ),
  'inconclusivo': (
    titulo: 'Comparação inconclusiva',
    cor: hex('#756320'),
    fundo: hex('#FFF7D8'),
  ),
};

const Map<String, ({String rotulo, IconData icone})> _etapaMeta = {
  'agora': (rotulo: 'Agora', icone: LucideIcons.crosshair),
  'confirmacao': (rotulo: 'Confirme no campo', icone: LucideIcons.circleHelp),
  'laboratorio': (rotulo: 'Decisão técnica', icone: LucideIcons.flaskConical),
};

_Meta _metaStatus(dynamic s) => _status['$s'] ?? _status['inconclusivo']!;

/// Intl.DateTimeFormat("pt-BR", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" })
String _formatarData(dynamic data) {
  final d = parseData(data);
  if (d == null) return '';
  return DateFormat("dd 'de' MMM, HH:mm", 'pt_BR').format(d.toLocal());
}

String _percentual(dynamic valor) => '${(toDouble(valor) * 100).round()}%';

double _fracao(dynamic valor) =>
    ((toDouble(valor) * 100).round() / 100).clamp(0.0, 1.0);

/// Atalho de TextStyle. [ls] em em (tracking do Tailwind); [h] = line-height em px.
TextStyle _t(
  double size, {
  FontWeight w = FontWeight.w400,
  Color? c,
  double? ls,
  double? h,
  FontStyle? st,
}) => TextStyle(
  fontSize: size,
  fontWeight: w,
  color: c ?? AgroColors.text,
  letterSpacing: ls == null ? null : ls * size,
  height: h == null ? null : h / size,
  fontStyle: st,
);

class _Falha implements Exception {
  _Falha(this.mensagem);
  final String mensagem;
}

/// Equivalente ao comprimirFoto: valida o tipo e o tamanho e gera o data URL.
/// O redimensionamento (lado maior 1600px, JPEG 0.86) é pedido ao image_picker;
/// se a plataforma não redimensionar e o arquivo continuar grande, reduz via dart:ui (PNG).
Future<String> _prepararFoto(Uint8List bytes) async {
  String? mime;
  if (bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
    mime = 'image/jpeg';
  } else if (bytes.length > 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    mime = 'image/png';
  } else if (bytes.length > 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    mime = 'image/webp';
  }
  if (mime == null) throw _Falha('Escolha uma foto válida.');
  if (bytes.length > 18 * 1024 * 1024) {
    throw _Falha('A foto original deve ter no máximo 18 MB.');
  }

  var dados = bytes;
  if (dados.length > 6 * 1024 * 1024) {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(dados);
      final descritor = await ui.ImageDescriptor.encoded(buffer);
      final maiorLado = math.max(descritor.width, descritor.height);
      final escala = maiorLado > 1600 ? 1600 / maiorLado : 1.0;
      final codec = await descritor.instantiateCodec(
        targetWidth: (descritor.width * escala).round(),
        targetHeight: (descritor.height * escala).round(),
      );
      final frame = await codec.getNextFrame();
      final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      descritor.dispose();
      buffer.dispose();
      if (png == null) {
        throw _Falha('O navegador não conseguiu preparar a foto.');
      }
      dados = png.buffer.asUint8List();
      mime = 'image/png';
    } on _Falha {
      rethrow;
    } catch (_) {
      throw _Falha('O navegador não conseguiu preparar a foto.');
    }
  }
  return 'data:$mime;base64,${base64Encode(dados)}';
}

// ---------------------------------------------------------------------------
// Página
// ---------------------------------------------------------------------------

class _AnaliseFoliarPageState extends State<AnaliseFoliarPage> {
  final _scroll = ScrollController();
  final _culturaCtrl = TextEditingController();
  final _observacoesCtrl = TextEditingController();
  final _diagnosticoCtrl = TextEditingController();

  List<Map<String, dynamic>> _propriedades = [];
  List<Map<String, dynamic>> _historico = [];
  Map<String, dynamic>? _capacidades;
  Map<String, dynamic>? _resultado;

  /// Bytes exibidos (equivale ao `imagem` usado no <img src>).
  Uint8List? _imagem;

  /// Data URL enviado ao backend (equivale ao `imagem` enviado no POST).
  String? _imagemPayload;

  String _propriedadeId = '';
  bool _consentimento = false;
  ({double latitude, double longitude, double precisao})? _coordenadas;
  ({String tipo, int id, String titulo, String retorno})? _contexto;
  bool _criandoQuarentena = false;
  bool _localizando = false;
  bool _processando = false;
  int _processoAtual = 0;
  String _erro = '';
  bool _carregandoPagina = true;
  Set<int> _perguntasMarcadas = {};
  bool _salvandoFeedback = false;
  Timer? _intervalo;
  double _alturaDireita = 0;

  String? _paramsCarregados;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final q = GoRouterState.of(context).uri.queryParameters;
    final chave = '${q['caso']}|${q['ponto']}|${q['vistoria']}';
    if (chave != _paramsCarregados) {
      _paramsCarregados = chave;
      int? numero(String? v) {
        final n = int.tryParse(v ?? '');
        return (n == null || n == 0) ? null : n;
      }

      final caso = numero(q['caso']);
      final ponto = numero(q['ponto']);
      final vistoria = numero(q['vistoria']);
      Future.microtask(() => _carregarDados(caso, ponto, vistoria));
    }
  }

  @override
  void dispose() {
    _intervalo?.cancel();
    _scroll.dispose();
    _culturaCtrl.dispose();
    _observacoesCtrl.dispose();
    _diagnosticoCtrl.dispose();
    super.dispose();
  }

  void _set(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  String _tratarErro(Object error, String padrao) {
    if (error is DioException) {
      if (error.response?.statusCode == 401) {
        if (mounted) context.go('/login');
        return 'Sua sessão expirou. Entre novamente.';
      }
      final data = error.response?.data;
      if (data is Map && data['error'] is String) {
        return data['error'] as String;
      }
      return padrao;
    }
    if (error is _Falha) return error.mensagem;
    return padrao;
  }

  Future<void> _carregarDados(
    int? casoParam,
    int? pontoParam,
    int? vistoriaParam,
  ) async {
    try {
      final res = await Future.wait([
        api.get('/propriedades'),
        api.get('/analise-foliar'),
        api.get('/analise-foliar/capacidades'),
      ]);
      _set(() {
        _propriedades = asList(res[0].data);
        _historico = asList(res[1].data);
        _capacidades = asMap(res[2].data);
      });

      if (casoParam != null) {
        final data = asMap(
          (await api.get('/analise-foliar/quarentenas/$casoParam')).data,
        );
        final id = toInt(data['id']);
        final prop = asMap(data['propriedade']);
        _set(() {
          _contexto = (
            tipo: 'caso',
            id: id,
            titulo: '${data['titulo'] ?? ''}',
            retorno: '/analise-foliar/quarentenas?id=$id',
          );
          _culturaCtrl.text = '${data['cultura'] ?? ''}';
          _propriedadeId = prop['id'] != null ? '${toInt(prop['id'])}' : '';
        });
      } else if (pontoParam != null && vistoriaParam != null) {
        final data = asMap(
          (await api.get('/analise-foliar/vistorias/$vistoriaParam')).data,
        );
        final pontos = asList(data['pontos']);
        final ponto = pontos
            .where((p) => toInt(p['id']) == pontoParam)
            .firstOrNull;
        if (ponto == null) throw _Falha('Ponto de vistoria não encontrado.');
        final prop = asMap(data['propriedade']);
        _set(() {
          _contexto = (
            tipo: 'ponto',
            id: toInt(ponto['id']),
            titulo: '${data['nome'] ?? ''} · ${ponto['nome'] ?? ''}',
            retorno: '/analise-foliar/vistorias?id=${toInt(data['id'])}',
          );
          _culturaCtrl.text = '${data['cultura'] ?? ''}';
          _propriedadeId = prop['id'] != null ? '${toInt(prop['id'])}' : '';
        });
      }
    } catch (e) {
      _set(() => _erro = _tratarErro(e, 'Não foi possível carregar o módulo.'));
    } finally {
      _set(() => _carregandoPagina = false);
    }
  }

  void _iniciarIntervalo() {
    _intervalo?.cancel();
    _intervalo = Timer.periodic(const Duration(milliseconds: 850), (_) {
      _set(
        () => _processoAtual = math.min(
          _processoAtual + 1,
          _processos.length - 1,
        ),
      );
    });
  }

  /// Equivale a inputRef.current?.click() — input com accept jpeg/png/webp e capture="environment".
  Future<void> _abrirCamera() async {
    final usaCamera =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    XFile? arquivo;
    try {
      arquivo = await ImagePicker().pickImage(
        source: usaCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 86,
        requestFullMetadata: false,
      );
    } catch (_) {
      _set(() => _erro = 'Não foi possível preparar a foto.');
      return;
    }
    if (arquivo == null) return;
    _set(() {
      _erro = '';
      _resultado = null;
      _perguntasMarcadas = {};
    });
    try {
      final bytes = await arquivo.readAsBytes();
      final payload = await _prepararFoto(bytes);
      _set(() {
        _imagem = bytes;
        _imagemPayload = payload;
      });
    } catch (e) {
      _set(
        () => _erro = e is _Falha
            ? e.mensagem
            : 'Não foi possível preparar a foto.',
      );
    }
  }

  Future<void> _obterLocalizacao() async {
    _set(() {
      _localizando = true;
      _erro = '';
    });
    try {
      final p = await obterPosicaoGps();
      _set(() {
        _coordenadas = (
          latitude: p.latitude,
          longitude: p.longitude,
          precisao: p.precisao,
        );
        _localizando = false;
      });
    } on GpsException catch (e) {
      _set(() {
        _erro = e.indisponivel ? 'Este navegador não oferece localização.' : 'Não foi possível obter a localização. Você pode continuar sem ela.';
        _localizando = false;
      });
    }
  }

  Future<void> _analisar() async {
    if (_imagem == null) {
      return _set(() => _erro = 'Tire ou selecione uma foto da folha.');
    }
    if (!_consentimento) {
      return _set(
        () =>
            _erro = 'Confirme o envio e armazenamento da foto para continuar.',
      );
    }
    _set(() {
      _processando = true;
      _processoAtual = 0;
      _erro = '';
    });
    _iniciarIntervalo();

    try {
      final cultura = _culturaCtrl.text.trim();
      final observacoes = _observacoesCtrl.text.trim();
      final ctx = _contexto;
      final coords = _coordenadas;
      final body = <String, dynamic>{
        'imagem': _imagemPayload ?? '',
        if (cultura.isNotEmpty) 'cultura': cultura,
        if (_propriedadeId.isNotEmpty)
          'propriedade_id': int.tryParse(_propriedadeId),
        if (coords != null) 'latitude': coords.latitude,
        if (coords != null) 'longitude': coords.longitude,
        if (coords != null) 'precisao_metros': coords.precisao,
        if (observacoes.isNotEmpty) 'observacoes': observacoes,
        'consentimento': _consentimento,
        if (ctx != null && ctx.tipo == 'caso') 'caso_id': ctx.id,
        if (ctx != null && ctx.tipo == 'ponto') 'ponto_vistoria_id': ctx.id,
      };
      final data = asMap((await api.post('/analise-foliar', data: body)).data);
      _set(() {
        _resultado = data;
        _historico = [data, ..._historico.where((i) => i['id'] != data['id'])];
        _perguntasMarcadas = {};
      });
    } catch (e) {
      _set(
        () => _erro = _tratarErro(e, 'Não foi possível concluir a análise.'),
      );
    } finally {
      _intervalo?.cancel();
      _set(() => _processando = false);
    }
  }

  Future<void> _abrirHistorico(Map<String, dynamic> analise) async {
    _set(() {
      _resultado = analise;
      _perguntasMarcadas = {};
      _diagnosticoCtrl.text = '${analise['diagnostico_confirmado'] ?? ''}';
      _erro = '';
    });
    try {
      final res = await api.get<List<int>>(
        '/analise-foliar/${analise['id']}/imagem',
        options: Options(responseType: ResponseType.bytes),
      );
      _set(() {
        _imagem = Uint8List.fromList(res.data ?? const []);
        _imagemPayload = null;
      });
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    } catch (e) {
      _set(
        () => _erro = _tratarErro(
          e,
          'Não foi possível abrir a foto desta análise.',
        ),
      );
    }
  }

  void _novaAnalise() {
    _set(() {
      _imagem = null;
      _imagemPayload = null;
      _resultado = null;
      if (_contexto == null) _culturaCtrl.text = '';
      _observacoesCtrl.text = '';
      _consentimento = false;
      _perguntasMarcadas = {};
      _diagnosticoCtrl.text = '';
      _erro = '';
    });
    _abrirCamera();
  }

  Future<void> _iniciarQuarentena() async {
    final r = _resultado;
    if (r == null || r['caso_id'] != null || r['ponto_vistoria_id'] != null) {
      return;
    }
    _set(() {
      _criandoQuarentena = true;
      _erro = '';
    });
    try {
      final data = asMap(
        (await api.post(
          '/analise-foliar/quarentenas',
          data: {'analise_id': r['id']},
        )).data,
      );
      if (mounted) context.go('/analise-foliar/quarentenas?id=${data['id']}');
    } catch (e) {
      _set(
        () => _erro = _tratarErro(
          e,
          'Não foi possível iniciar o acompanhamento.',
        ),
      );
    } finally {
      _set(() => _criandoQuarentena = false);
    }
  }

  Future<void> _enviarFeedback(bool util) async {
    final r = _resultado;
    if (r == null) return;
    _set(() => _salvandoFeedback = true);
    try {
      final diag = _diagnosticoCtrl.text.trim();
      final res = await api.patch(
        '/analise-foliar/${r['id']}/feedback',
        data: {
          'util': util,
          if (diag.isNotEmpty) 'diagnostico_confirmado': diag,
        },
      );
      final data = asMap(res.data);
      _set(() {
        _resultado = data;
        _historico = _historico
            .map((i) => i['id'] == data['id'] ? data : i)
            .toList();
      });
    } catch (e) {
      _set(
        () => _erro = _tratarErro(e, 'Não foi possível registrar o retorno.'),
      );
    } finally {
      _set(() => _salvandoFeedback = false);
    }
  }

  Future<void> _removerAnalise(Map<String, dynamic> analise) async {
    final ok = await confirmar(
      context,
      'Excluir esta análise e a foto armazenada? Essa ação não pode ser desfeita.',
    );
    if (!ok) return;
    try {
      await api.delete('/analise-foliar/${analise['id']}');
      _set(() {
        _historico = _historico.where((i) => i['id'] != analise['id']).toList();
        if (_resultado?['id'] == analise['id']) {
          _resultado = null;
          _imagem = null;
          _imagemPayload = null;
        }
      });
    } catch (e) {
      _set(() => _erro = _tratarErro(e, 'Não foi possível excluir a análise.'));
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_carregandoPagina) {
      return ColoredBox(
        color: hex('#F5F6F2'),
        child: Center(
          child: _Girando(
            LucideIcons.loaderCircle,
            size: 28,
            color: hex('#1F5B3A'),
          ),
        ),
      );
    }

    final w = MediaQuery.sizeOf(context).width;
    final md = w >= 768;
    final lg = w >= 1024;
    final contentH = lg ? 40.0 : (md ? 32.0 : 16.0);

    return ColoredBox(
      color: hex('#F5F6F2'),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: hex('#25352B')),
        child: SingleChildScrollView(
          controller: _scroll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1380),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      contentH,
                      md ? 32 : 20,
                      contentH,
                      md ? 32 : 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AnaliseFoliarNav(),
                        if (_contexto != null) _bannerContexto(context),
                        if (_erro.isNotEmpty) _bannerErro(),
                        _secaoPrincipal(context),
                        if (_capacidades?['diagnostico_especializado'] != true)
                          _bannerTriagem(context),
                        const SizedBox(height: 32),
                        _secaoHistorico(),
                        const SizedBox(height: 32),
                        _secaoDicas(context),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final md = w >= 768;
    final lg = w >= 1024;
    final especializado = _capacidades?['diagnostico_especializado'] == true;
    final provedor = _capacidades?['provedor_especializado'];

    final titulo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.microscope, size: 14, color: hex('#317244')),
            const SizedBox(width: 8),
            Text(
              'DIAGNÓSTICO FOLIAR',
              style: _t(11, w: FontWeight.w700, c: hex('#317244'), ls: .18),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Análise foliar',
          style: _t(
            md ? 36 : 30,
            w: FontWeight.w700,
            c: hex('#25352B'),
            ls: -.035,
            h: md ? 40 : 36,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 672),
          child: Text(
            'Registre a amostra, processe a imagem e acompanhe o resultado.',
            style: _t(14, c: hex('#687267'), h: 24),
          ),
        ),
      ],
    );

    final chip = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: hex('#D7DED2')),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: especializado ? hex('#30B85D') : hex('#D79A28'),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                especializado
                    ? '${provedor ?? 'Diagnóstico ampliado'} ativo'
                    : 'Triagem visual ativa',
                style: _t(12, w: FontWeight.w600, c: hex('#36533C')),
              ),
            ],
          ),
        ),
        if (provedor == 'Pl@ntNet Diseases') ...[
          const SizedBox(height: 6),
          InkWell(
            onTap: () => launchUrl(
              Uri.parse('https://my.plantnet.org/'),
              mode: LaunchMode.externalApplication,
            ),
            child: Text(
              'Identificação baseada na API Pl@ntNet',
              style: _t(10, w: FontWeight.w600, c: hex('#617263')).copyWith(
                decoration: TextDecoration.underline,
                decorationColor: hex('#AFC0B0'),
              ),
            ),
          ),
        ],
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: hex('#F8FAF5', .95),
        border: Border(bottom: BorderSide(color: hex('#DDE2D8'))),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: lg ? 40 : (md ? 32 : 20),
        vertical: 20,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1380),
          child: md
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: titulo),
                    const SizedBox(width: 16),
                    chip,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [titulo, const SizedBox(height: 16), chip],
                ),
        ),
      ),
    );
  }

  Widget _bannerContexto(BuildContext context) {
    final ctx = _contexto!;
    final sm = MediaQuery.sizeOf(context).width >= 640;
    final info = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            ctx.tipo == 'caso' ? LucideIcons.shieldCheck : LucideIcons.mapPin,
            size: 18,
            color: hex('#2D713D'),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ctx.tipo == 'caso'
                    ? 'Nova revisão da quarentena'
                    : 'Foto vinculada ao ponto da vistoria',
                style: _t(12, w: FontWeight.w700, c: hex('#285B34')),
              ),
              const SizedBox(height: 4),
              Text(ctx.titulo, style: _t(11, c: hex('#5E735F'))),
            ],
          ),
        ),
      ],
    );
    final voltar = InkWell(
      onTap: () => context.go(ctx.retorno),
      child: Text(
        'Voltar ao acompanhamento',
        textAlign: sm ? TextAlign.right : TextAlign.left,
        style: _t(12, w: FontWeight.w700, c: hex('#2C6638')),
      ),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: hex('#EDF6EA'),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: hex('#C9DEC8')),
      ),
      child: sm
          ? Row(
              children: [
                Expanded(child: info),
                const SizedBox(width: 12),
                voltar,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [info, const SizedBox(height: 12), voltar],
            ),
    );
  }

  Widget _bannerErro() {
    return _Entrada(
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: hex('#FFF4EC'),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: hex('#E9C1A8')),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                LucideIcons.triangleAlert,
                size: 17,
                color: hex('#8A431F'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_erro, style: _t(14, c: hex('#8A431F'))),
            ),
            const SizedBox(width: 12),
            Transform.translate(
              offset: const Offset(8, -8),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Tooltip(
                  message: 'Fechar aviso',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _set(() => _erro = ''),
                    child: Icon(LucideIcons.x, size: 16, color: hex('#8A431F')),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------- Seção principal -----------------------------

  Widget _secaoPrincipal(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final md = w >= 768;
    final xl = w >= 1280;
    final minH = md ? 620.0 : 520.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: hex('#CFD8CE')),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: xl
            ? LayoutBuilder(
                builder: (context, c) {
                  final direita = math.max(430.0, c.maxWidth * .92 / 2);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: math.max(minH, _alturaDireita),
                          child: _painelImagem(context),
                        ),
                      ),
                      SizedBox(
                        width: direita,
                        child: _Medir(
                          onSize: (s) {
                            if ((s.height - _alturaDireita).abs() > .5) {
                              _set(() => _alturaDireita = s.height);
                            }
                          },
                          child: _painelDireito(context, minH),
                        ),
                      ),
                    ],
                  );
                },
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: minH, child: _painelImagem(context)),
                  _painelDireito(context, 0),
                ],
              ),
      ),
    );
  }

  Widget _painelImagem(BuildContext context) {
    final md = MediaQuery.sizeOf(context).width >= 768;
    final r = _resultado;
    final img = _imagem;

    return Container(
      color: hex('#173A29'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (img != null) ...[
            Image.memory(img, fit: BoxFit.cover, gaplessPlayback: true),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    hex('#07150B', .35),
                    hex('#07150B', 0),
                    hex('#07150B', .85),
                  ],
                ),
              ),
            ),
            if (!_processando) const _LinhaScan(),
            Positioned(
              left: 20,
              top: 20,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        color: Colors.black.withValues(alpha: .45),
                        child: Text(
                          'CAPTURA ATUAL',
                          style: _t(
                            11,
                            w: FontWeight.w700,
                            c: Colors.white,
                            ls: .13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (r != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: hex('#B8E6A8'),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'PROCESSADA',
                        style: _t(
                          11,
                          w: FontWeight.w700,
                          c: hex('#12371B'),
                          ls: .13,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else
            Padding(
              padding: EdgeInsets.symmetric(horizontal: md ? 40 : 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .15),
                      ),
                    ),
                    child: Icon(
                      LucideIcons.camera,
                      size: 21,
                      color: hex('#B7F6A8'),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'NOVA AMOSTRA',
                    style: _t(
                      10,
                      w: FontWeight.w700,
                      c: hex('#A9CDB0'),
                      ls: .16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fotografe uma folha por vez',
                    style: _t(
                      md ? 30 : 24,
                      w: FontWeight.w600,
                      c: Colors.white,
                      ls: -.025,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 448),
                    child: Text(
                      'Use luz natural, preencha o quadro e mantenha a imagem em foco. Se houver manchas, registre também o verso.',
                      style: _t(
                        14,
                        c: Colors.white.withValues(alpha: .6),
                        h: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _Tap(
                    color: hex('#B8E6A8'),
                    hoverColor: hex('#A9DB99'),
                    radius: 6,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    onTap: _abrirCamera,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.camera,
                          size: 18,
                          color: hex('#12371B'),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Abrir câmera',
                          style: _t(14, w: FontWeight.w700, c: hex('#12371B')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (_processando) _overlayProcessando(context),
          if (img != null && !_processando)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: EdgeInsets.all(md ? 28 : 20),
                child: r != null
                    ? Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _QualidadeItem(
                                icone: LucideIcons.focus,
                                label: 'foco',
                                valor: _percentual(
                                  asMap(
                                    r['metricas_visuais'],
                                  )['foco_aproximado'],
                                ),
                              ),
                              const SizedBox(width: 16),
                              _QualidadeItem(
                                icone: LucideIcons.sunMedium,
                                label: 'luz',
                                valor: _percentual(
                                  asMap(r['metricas_visuais'])['luminosidade'],
                                ),
                              ),
                              const SizedBox(width: 16),
                              _QualidadeItem(
                                icone: LucideIcons.imagePlus,
                                label: 'folha',
                                valor: _percentual(
                                  asMap(
                                    r['metricas_visuais'],
                                  )['area_foliar_aproximada'],
                                ),
                                ultimo: true,
                              ),
                            ],
                          ),
                          _botaoBranco(
                            LucideIcons.camera,
                            'Nova foto',
                            _novaAnalise,
                          ),
                        ],
                      )
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: _botaoBranco(
                          LucideIcons.refreshCw,
                          'Trocar foto',
                          _abrirCamera,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _botaoBranco(IconData icone, String texto, VoidCallback onTap) => _Tap(
    color: Colors.white,
    radius: 6,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    onTap: onTap,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 15, color: hex('#18351F')),
        const SizedBox(width: 8),
        Text(
          texto,
          style: _t(12, w: FontWeight.w700, c: hex('#18351F')),
        ),
      ],
    ),
  );

  Widget _overlayProcessando(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final md = w >= 768;
    final sm = w >= 640;

    Widget passo(int indice) {
      final p = _processos[indice];
      final feito = indice < _processoAtual;
      final atual = indice == _processoAtual;
      Widget bolinha = Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: feito ? hex('#B8E6A8') : null,
          border: feito
              ? null
              : Border.all(
                  color: atual
                      ? hex('#B8E6A8')
                      : Colors.white.withValues(alpha: .3),
                ),
        ),
        child: feito
            ? Icon(LucideIcons.check, size: 13, color: hex('#12371B'))
            : Text(
                '${indice + 1}',
                style: _t(
                  10,
                  c: atual
                      ? hex('#B8E6A8')
                      : Colors.white.withValues(alpha: .4),
                ),
              ),
      );
      if (atual) bolinha = _PontoPulsando(child: bolinha);
      return AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        opacity: indice <= _processoAtual ? 1 : .3,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 2), child: bolinha),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.titulo,
                    style: _t(14, w: FontWeight.w600, c: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.detalhe,
                    style: _t(12, c: Colors.white.withValues(alpha: .5)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: Container(
            color: hex('#07150B', .82),
            padding: EdgeInsets.all(md ? 32 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'PROCESSANDO IMAGEM',
                        style: _t(
                          12,
                          w: FontWeight.w700,
                          c: Colors.white.withValues(alpha: .7),
                          ls: .17,
                        ),
                      ),
                    ),
                    _Girando(
                      LucideIcons.loaderCircle,
                      size: 20,
                      color: hex('#B8E6A8'),
                    ),
                  ],
                ),
                const Spacer(),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 512),
                  child: Text(
                    'Analisando a amostra',
                    style: _t(
                      30,
                      w: FontWeight.w600,
                      c: Colors.white,
                      ls: -.04,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                LayoutBuilder(
                  builder: (context, c) {
                    final itemW = sm ? (c.maxWidth - 16) / 2 : c.maxWidth;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (var i = 0; i < _processos.length; i++)
                          SizedBox(width: itemW, child: passo(i)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _painelDireito(BuildContext context, double minH) {
    final r = _resultado;
    if (r == null) return _formulario(context, minH);
    return _Entrada(child: _painelResultado(context, r));
  }

  InputDecoration _decoracao(
    String hint, {
    double radius = 6,
    Color? borda,
    Color? foco,
    Color? fundo,
  }) {
    final b = borda ?? hex('#DCE2D8');
    final f = foco ?? hex('#4A8A55');
    final bg = fundo ?? hex('#F8FAF6');
    return InputDecoration(
      hintText: hint,
      hintStyle: _t(14, c: hex('#9DAA9F')),
      isDense: true,
      filled: true,
      fillColor: WidgetStateColor.resolveWith(
        (s) => s.contains(WidgetState.focused) ? Colors.white : bg,
      ),
      hoverColor: Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: b),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: b),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: f),
      ),
    );
  }

  Widget _rotulo(String texto, {String? extra}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text.rich(
      TextSpan(
        text: texto,
        style: _t(12, w: FontWeight.w600, c: hex('#405043')),
        children: [
          if (extra != null)
            TextSpan(
              text: ' $extra',
              style: _t(12, c: hex('#8A9588')),
            ),
        ],
      ),
    ),
  );

  Widget _formulario(BuildContext context, double minH) {
    final w = MediaQuery.sizeOf(context).width;
    final md = w >= 768;
    final lg = w >= 1024;
    final provedor = _capacidades?['provedor_especializado'];
    final ids = _propriedades.map((p) => '${toInt(p['id'])}').toSet();
    final valorSelect = ids.contains(_propriedadeId) ? _propriedadeId : '';
    final podeAnalisar = _imagem != null && !_processando;

    final topo = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONTEXTO DA AMOSTRA',
                    style: _t(
                      11,
                      w: FontWeight.w700,
                      c: hex('#3A7949'),
                      ls: .16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Informações da amostra',
                    style: _t(24, w: FontWeight.w700, ls: -.03),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hex('#E9F4E7'),
              ),
              child: Icon(LucideIcons.sprout, size: 19, color: hex('#27693A')),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _rotulo('Cultura ou planta', extra: '(se souber)'),
        SizedBox(
          height: 48,
          child: TextField(
            controller: _culturaCtrl,
            style: _t(14),
            decoration: _decoracao('Ex.: soja, café, tomate'),
            textAlignVertical: TextAlignVertical.center,
            expands: true,
            maxLines: null,
          ),
        ),
        const SizedBox(height: 20),
        _rotulo('Propriedade'),
        SizedBox(
          height: 48,
          child: DropdownButtonFormField<String>(
            key: ValueKey('prop-$valorSelect-${_propriedades.length}'),
            initialValue: valorSelect,
            isExpanded: true,
            style: _t(14),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(6),
            decoration: _decoracao(''),
            items: [
              DropdownMenuItem(
                value: '',
                child: Text('Sem vínculo', style: _t(14)),
              ),
              for (final p in _propriedades)
                DropdownMenuItem(
                  value: '${toInt(p['id'])}',
                  child: Text('${p['nome'] ?? ''}', style: _t(14)),
                ),
            ],
            onChanged: (v) => _set(() => _propriedadeId = v ?? ''),
          ),
        ),
        const SizedBox(height: 20),
        _rotulo('O que você observou?'),
        TextField(
          controller: _observacoesCtrl,
          minLines: 4,
          maxLines: 4,
          inputFormatters: [LengthLimitingTextInputFormatter(600)],
          style: _t(14, h: 20),
          decoration:
              _decoracao('Quando começou, onde apareceu e como está o clima...')
                  .copyWith(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
        ),
        const SizedBox(height: 20),
        _Tap(
          color: Colors.white,
          hoverColor: hex('#F7FAF4'),
          border: BorderSide(color: hex('#DCE2D8')),
          radius: 6,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          onTap: _localizando ? null : _obterLocalizacao,
          child: Row(
            children: [
              Icon(
                _coordenadas != null
                    ? LucideIcons.mapPin
                    : LucideIcons.locateFixed,
                size: 18,
                color: _coordenadas != null ? hex('#268448') : hex('#647365'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _coordenadas != null
                          ? 'Localização adicionada'
                          : 'Adicionar localização',
                      style: _t(12, w: FontWeight.w600, c: hex('#344438')),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _coordenadas != null
                          ? 'Ajuda a considerar o contexto regional'
                          : 'Opcional e usada somente nesta análise',
                      style: _t(11, c: hex('#849084')),
                    ),
                  ],
                ),
              ),
              _localizando
                  ? _Girando(
                      LucideIcons.loaderCircle,
                      size: 17,
                      color: hex('#25352B'),
                    )
                  : Icon(
                      LucideIcons.chevronRight,
                      size: 17,
                      color: hex('#A0AAA0'),
                    ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _Tap(
          color: hex('#F3F6F0'),
          radius: 6,
          padding: const EdgeInsets.all(14),
          onTap: () => _set(() => _consentimento = !_consentimento),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: Checkbox(
                    value: _consentimento,
                    onChanged: (v) => _set(() => _consentimento = v ?? false),
                    activeColor: hex('#175F2D'),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3),
                    ),
                    side: BorderSide(color: hex('#767676')),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Autorizo o processamento e armazenamento desta foto no meu histórico'
                  '${provedor != null ? ' e seu envio ao $provedor para identificação visual' : ''}'
                  '. Posso excluí-la a qualquer momento.',
                  style: _t(11, c: hex('#617063'), h: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final rodape = Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: podeAnalisar ? 1 : .45,
            child: _Tap(
              color: hex('#1F5B3A'),
              hoverColor: hex('#17482F'),
              radius: 6,
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              onTap: podeAnalisar ? _analisar : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    LucideIcons.microscope,
                    size: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Processar análise',
                    style: _t(14, w: FontWeight.w700, c: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Resultado de triagem. Não substitui diagnóstico agronômico, fitopatológico ou análise laboratorial.',
            textAlign: TextAlign.center,
            style: _t(10, c: hex('#8A9588'), h: 16),
          ),
        ],
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minH),
      child: Padding(
        padding: EdgeInsets.all(lg ? 36 : (md ? 32 : 20)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [topo, rodape],
        ),
      ),
    );
  }

  Widget _painelResultado(BuildContext context, Map<String, dynamic> r) {
    final md = MediaQuery.sizeOf(context).width >= 768;
    final pad = EdgeInsets.all(md ? 28 : 20);
    final status = _metaStatus(r['status_geral']);
    final hipoteses = asList(r['hipoteses']);
    final recomendacoes = asList(r['recomendacoes']);
    final perguntas = (r['perguntas_confirmacao'] is List)
        ? (r['perguntas_confirmacao'] as List).map((e) => '$e').toList()
        : <String>[];
    final metricas = asMap(r['metricas_visuais']);
    final cultura = r['cultura_detectada'] ?? r['cultura_informada'];
    final cientifica = r['cultura_cientifica'];
    final divisor = BorderSide(color: hex('#E3E8DF'));
    final feedback = r['feedback_util'];
    final semVinculo = r['caso_id'] == null && r['ponto_vistoria_id'] == null;

    Widget bloco(Widget child, {bool borda = true}) => Container(
      width: double.infinity,
      padding: pad,
      decoration: BoxDecoration(border: borda ? Border(bottom: divisor) : null),
      child: child,
    );

    final cabecalho = bloco(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: status.fundo,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        status.titulo.toUpperCase(),
                        style: _t(
                          10,
                          w: FontWeight.w700,
                          c: status.cor,
                          ls: .12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      hipoteses.isNotEmpty
                          ? '${hipoteses.first['nome']}'
                          : 'Análise concluída',
                      style: _t(md ? 30 : 24, w: FontWeight.w700, ls: -.035),
                    ),
                    if (cultura != null && '$cultura'.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '$cultura${cientifica != null && '$cientifica'.isNotEmpty ? ' · $cientifica' : ''}',
                        style: _t(14, c: hex('#657064')),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _AnelConfianca(
                valor: _fracao(r['confianca']),
                cor: status.cor,
                texto: _percentual(r['confianca']),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hex('#FFF9E5'),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: hex('#E8DDAA')),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    LucideIcons.shieldCheck,
                    size: 17,
                    color: hex('#705C16'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: _t(11, c: hex('#705C16'), h: 20),
                      children: const [
                        TextSpan(
                          text: 'Hipótese, não laudo.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: ' Confiança indica semelhança visual, não certeza da causa. Use os diferenciais e perguntas abaixo.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final tecido = bloco(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Leitura visual do tecido',
                  style: _t(14, w: FontWeight.w700),
                ),
              ),
              Text(
                'PRÉ-ANÁLISE',
                style: _t(10, w: FontWeight.w600, c: hex('#778277'), ls: .12),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _BarraTecido(
            label: 'Verde',
            valor: metricas['tecido_verde'],
            cor: hex('#3A9C55'),
          ),
          const SizedBox(height: 12),
          _BarraTecido(
            label: 'Amarelado',
            valor: metricas['tecido_amarelado'],
            cor: hex('#D5B23C'),
          ),
          const SizedBox(height: 12),
          _BarraTecido(
            label: 'Marrom / necrosado',
            valor: metricas['tecido_marrom'],
            cor: hex('#9B6740'),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hex('#F4F6F1'),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    LucideIcons.flaskConical,
                    size: 14,
                    color: hex('#697369'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cor foliar pode sugerir estresse, mas não estima NPK, pH ou fertilidade do solo.',
                    style: _t(10, c: hex('#697369'), h: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    Widget? comparacao;
    final comp = r['comparacao_anterior'];
    if (comp is Map) {
      final meta =
          _comparacao['${comp['estado']}'] ?? _comparacao['inconclusivo']!;
      comparacao = bloco(
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: meta.fundo,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  LucideIcons.arrowLeftRight,
                  size: 19,
                  color: meta.cor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${meta.titulo} · ${comp['dias_desde']} dias',
                      style: _t(12, w: FontWeight.w700, c: meta.cor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${comp['resumo'] ?? ''}',
                      style: _t(11, c: meta.cor, h: 20),
                    ),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: .8,
                      child: Text(
                        '${comp['aviso'] ?? ''}',
                        style: _t(10, c: meta.cor, h: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget hipotese(int i) {
      final h = hipoteses[i];
      final cientificoH = h['nome_cientifico'];
      final descricao = h['descricao'];
      return Container(
        padding: EdgeInsets.only(top: i == 0 ? 0 : 16, bottom: 16),
        decoration: BoxDecoration(
          border: i == 0
              ? null
              : Border(top: BorderSide(color: hex('#E6EAE2'))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hex('#EEF4EB'),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: _t(11, w: FontWeight.w700, c: hex('#2F683B')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${h['nome'] ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _t(14, w: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _percentual(h['probabilidade']),
                            style: _t(
                              12,
                              w: FontWeight.w700,
                              c: hex('#47624C'),
                            ),
                          ),
                        ],
                      ),
                      if (cientificoH != null && '$cientificoH'.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '$cientificoH',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _t(
                            11,
                            c: hex('#879087'),
                            st: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (i == 0 && descricao != null && '$descricao'.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('$descricao', style: _t(12, c: hex('#697369'), h: 20)),
            ],
          ],
        ),
      );
    }

    final listaHipoteses = bloco(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Hipóteses e diferenciais', style: _t(14, w: FontWeight.w700)),
          const SizedBox(height: 16),
          for (var i = 0; i < hipoteses.length; i++) hipotese(i),
        ],
      ),
    );

    Widget pergunta(int i) {
      final marcada = _perguntasMarcadas.contains(i);
      return _Tap(
        key: ValueKey(perguntas[i]),
        color: marcada ? hex('#F0F8ED') : Colors.white,
        border: BorderSide(color: marcada ? hex('#7FAD79') : hex('#E1E6DD')),
        radius: 6,
        padding: const EdgeInsets.all(12),
        onTap: () => _set(() {
          final proximo = {..._perguntasMarcadas};
          if (!proximo.remove(i)) proximo.add(i);
          _perguntasMarcadas = proximo;
        }),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: marcada ? hex('#2F743D') : hex('#EEF1EC'),
                borderRadius: BorderRadius.circular(4),
              ),
              child: marcada
                  ? const Icon(LucideIcons.check, size: 11, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                perguntas[i],
                style: _t(12, c: hex('#536055'), h: 20),
              ),
            ),
          ],
        ),
      );
    }

    final confirme = bloco(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Confirme no campo', style: _t(14, w: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Marque o que você realmente observou. Essas respostas ajudam a separar causas parecidas.',
            style: _t(11, c: hex('#7D887D'), h: 20),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < perguntas.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            pergunta(i),
          ],
        ],
      ),
    );

    Widget recomendacao(Map<String, dynamic> rec) {
      final meta = _etapaMeta['${rec['etapa']}'] ?? _etapaMeta['agora']!;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hex('#EAF3E7'),
            ),
            child: Icon(meta.icone, size: 15, color: hex('#2C6C3A')),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta.rotulo.toUpperCase(),
                  style: _t(10, w: FontWeight.w700, c: hex('#50805A'), ls: .12),
                ),
                const SizedBox(height: 4),
                Text(
                  '${rec['titulo'] ?? ''}',
                  style: _t(12, w: FontWeight.w700, c: hex('#28372B')),
                ),
                const SizedBox(height: 4),
                Text(
                  '${rec['descricao'] ?? ''}',
                  style: _t(11, c: hex('#707B70'), h: 20),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final plano = bloco(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Plano recomendado', style: _t(14, w: FontWeight.w700)),
          const SizedBox(height: 16),
          for (var i = 0; i < recomendacoes.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            recomendacao(recomendacoes[i]),
          ],
        ],
      ),
      borda: false,
    );

    Widget botaoFeedback(bool util) {
      final ativo = feedback == util;
      return Opacity(
        opacity: _salvandoFeedback ? .6 : 1,
        child: _Tap(
          color: ativo
              ? (util ? hex('#EAF6E8') : hex('#FAEEE9'))
              : Colors.white,
          border: BorderSide(
            color: ativo
                ? (util ? hex('#4B8B57') : hex('#A4674C'))
                : hex('#DDE3D9'),
          ),
          radius: 8,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          onTap: _salvandoFeedback ? null : () => _enviarFeedback(util),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                util ? LucideIcons.thumbsUp : LucideIcons.thumbsDown,
                size: 14,
                color: hex('#25352B'),
              ),
              const SizedBox(width: 8),
              Text(util ? 'Sim' : 'Não', style: _t(12, w: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    final rodape = Container(
      width: double.infinity,
      padding: pad,
      decoration: BoxDecoration(
        color: hex('#F8FAF6'),
        border: Border(top: divisor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Essa triagem foi útil?', style: _t(12, w: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              botaoFeedback(true),
              const SizedBox(width: 8),
              botaoFeedback(false),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: TextField(
              controller: _diagnosticoCtrl,
              inputFormatters: [LengthLimitingTextInputFormatter(160)],
              style: _t(12),
              textAlignVertical: TextAlignVertical.center,
              expands: true,
              maxLines: null,
              decoration:
                  _decoracao(
                    'Diagnóstico confirmado depois (opcional)',
                    radius: 8,
                    borda: hex('#DDE3D9'),
                    foco: hex('#5D8C63'),
                    fundo: Colors.white,
                  ).copyWith(
                    hintStyle: _t(12, c: hex('#9DAA9F')),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
            ),
          ),
          if (semVinculo) ...[
            const SizedBox(height: 16),
            Opacity(
              opacity: _criandoQuarentena ? .5 : 1,
              child: _Tap(
                color: hex('#1F5B3A'),
                radius: 6,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                onTap: _criandoQuarentena ? null : _iniciarQuarentena,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _criandoQuarentena
                        ? const _Girando(
                            LucideIcons.loaderCircle,
                            size: 16,
                            color: Colors.white,
                          )
                        : const Icon(
                            LucideIcons.shieldCheck,
                            size: 16,
                            color: Colors.white,
                          ),
                    const SizedBox(width: 8),
                    Text(
                      'Acompanhar tratamento',
                      style: _t(12, w: FontWeight.w700, c: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_contexto != null) ...[
            const SizedBox(height: 16),
            _Tap(
              color: Colors.white,
              border: BorderSide(color: hex('#C8D5C6')),
              radius: 6,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              onTap: () => context.go(_contexto!.retorno),
              child: Center(
                child: Text(
                  'Ver histórico e comparação',
                  style: _t(12, w: FontWeight.w700, c: hex('#31533A')),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        cabecalho,
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 680),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tecido,
                ?comparacao,
                listaHipoteses,
                confirme,
                plano,
                rodape,
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------- Rodapés ----------------------------------

  Widget _bannerTriagem(BuildContext context) {
    final md = MediaQuery.sizeOf(context).width >= 768;
    final info = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(LucideIcons.shieldCheck, size: 20, color: hex('#8A6A10')),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Modo atual: triagem visual segura',
                style: _t(12, w: FontWeight.w700, c: hex('#665215')),
              ),
              const SizedBox(height: 4),
              Text(
                'Qualidade e sinais cromáticos estão ativos. Espécie, fungos, bactérias, vírus e pragas serão liberados ao conectar a chave do classificador especializado.',
                style: _t(11, c: hex('#7E6D3C'), h: 20),
              ),
            ],
          ),
        ),
      ],
    );
    final selo = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: hex('#E1CC8F')),
      ),
      child: Text(
        'INTEGRAÇÃO PREPARADA',
        style: _t(10, w: FontWeight.w700, c: hex('#7A6012'), ls: .12),
      ),
    );
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: EdgeInsets.symmetric(horizontal: md ? 20 : 16, vertical: 16),
      decoration: BoxDecoration(
        color: hex('#FFFAEB'),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: hex('#E5D5AA')),
      ),
      child: md
          ? Row(
              children: [
                Expanded(child: info),
                const SizedBox(width: 16),
                selo,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [info, const SizedBox(height: 16), selo],
            ),
    );
  }

  Widget _secaoHistorico() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LINHA DO TEMPO',
                      style: _t(
                        10,
                        w: FontWeight.w700,
                        c: hex('#638069'),
                        ls: .16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Análises recentes',
                      style: _t(20, w: FontWeight.w700, ls: -.025),
                    ),
                  ],
                ),
              ),
              Text(
                '${_historico.length} registros',
                style: _t(12, c: hex('#7E887E')),
              ),
            ],
          ),
        ),
        if (_historico.isEmpty)
          CustomPaint(
            painter: _BordaTracejada(color: hex('#CBD4C7'), radius: 8),
            child: Container(
              constraints: const BoxConstraints(minHeight: 144),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Sua primeira análise aparecerá aqui.',
                textAlign: TextAlign.center,
                style: _t(14, c: hex('#7C897B')),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: hex('#DDE3D9')),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Column(
                children: [
                  for (var i = 0; i < _historico.length; i++)
                    _LinhaHistorico(
                      key: ValueKey(_historico[i]['id']),
                      analise: _historico[i],
                      primeira: i == 0,
                      onAbrir: () => _abrirHistorico(_historico[i]),
                      onRemover: () => _removerAnalise(_historico[i]),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _secaoDicas(BuildContext context) {
    final md = MediaQuery.sizeOf(context).width >= 768;
    Widget dica(IconData icone, String titulo, String texto) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icone, size: 17, color: hex('#3E7648')),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: _t(12, w: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(texto, style: _t(11, c: hex('#737E73'), h: 20)),
            ],
          ),
        ),
      ],
    );
    final dicas = [
      dica(
        LucideIcons.upload,
        '2 a 3 fotos ajudam',
        'Faça análises separadas da planta inteira, frente e verso da folha.',
      ),
      dica(
        LucideIcons.microscope,
        'Confirme antes de tratar',
        'Doenças e estresses podem produzir sintomas visualmente semelhantes.',
      ),
      dica(
        LucideIcons.flaskConical,
        'Solo precisa de laboratório',
        'Recomendação de adubo depende de solo, tecido, cultura, fase e histórico.',
      ),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: hex('#D8DED4'))),
      ),
      child: md
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < dicas.length; i++) ...[
                  if (i > 0) const SizedBox(width: 16),
                  Expanded(child: dicas[i]),
                ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < dicas.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  dicas[i],
                ],
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets privados
// ---------------------------------------------------------------------------

/// Superfície clicável com fundo, borda e cor de hover (equivale aos <button> com classes Tailwind).
class _Tap extends StatelessWidget {
  const _Tap({
    super.key,
    required this.child,
    required this.onTap,
    this.color = Colors.transparent,
    this.hoverColor,
    this.border,
    this.radius = 6,
    this.padding = EdgeInsets.zero,
    this.height,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final Color? hoverColor;
  final BorderSide? border;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: border ?? BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: hoverColor,
        mouseCursor: onTap == null
            ? SystemMouseCursors.forbidden
            : SystemMouseCursors.click,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: height ?? 0),
          child: Padding(
            padding: padding,
            child: height == null ? child : Align(widthFactor: 1, child: child),
          ),
        ),
      ),
    );
  }
}

/// BarraTecido
class _BarraTecido extends StatelessWidget {
  const _BarraTecido({
    required this.label,
    required this.valor,
    required this.cor,
  });
  final String label;
  final dynamic valor;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: _t(12, c: hex('#566156'))),
            ),
            Text(
              _percentual(valor),
              style: _t(12, w: FontWeight.w600, c: hex('#25352B')),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 8,
            color: hex('#E8ECE5'),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _fracao(valor)),
              duration: const Duration(milliseconds: 700),
              curve: Curves.ease,
              builder: (_, v, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: v,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// QualidadeItem
class _QualidadeItem extends StatelessWidget {
  const _QualidadeItem({
    required this.icone,
    required this.label,
    required this.valor,
    this.ultimo = false,
  });
  final IconData icone;
  final String label;
  final String valor;
  final bool ultimo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(right: ultimo ? 0 : 16),
      decoration: BoxDecoration(
        border: ultimo
            ? null
            : Border(
                right: BorderSide(color: Colors.white.withValues(alpha: .1)),
              ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 16, color: hex('#B7F6A8')),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: _t(10, c: Colors.white.withValues(alpha: .45), ls: .13),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: _t(12, w: FontWeight.w600, c: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Anel com conic-gradient (confiança).
class _AnelConfianca extends StatelessWidget {
  const _AnelConfianca({
    required this.valor,
    required this.cor,
    required this.texto,
  });
  final double valor;
  final Color cor;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final trilho = hex('#E7EBE4');
    return Container(
      width: 68,
      height: 68,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [cor, cor, trilho, trilho],
          stops: [0, valor, valor, 1],
          transform: const GradientRotation(-math.pi / 2),
        ),
      ),
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: Text(texto, style: _t(14, w: FontWeight.w700)),
      ),
    );
  }
}

/// Linha do histórico (com botão de excluir que aparece no hover em telas md+).
class _LinhaHistorico extends StatefulWidget {
  const _LinhaHistorico({
    super.key,
    required this.analise,
    required this.primeira,
    required this.onAbrir,
    required this.onRemover,
  });

  final Map<String, dynamic> analise;
  final bool primeira;
  final VoidCallback onAbrir;
  final VoidCallback onRemover;

  @override
  State<_LinhaHistorico> createState() => _LinhaHistoricoState();
}

class _LinhaHistoricoState extends State<_LinhaHistorico> {
  bool _hover = false;
  bool _hoverLixeira = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.analise;
    final md = MediaQuery.sizeOf(context).width >= 768;
    final meta = _metaStatus(a['status_geral']);
    final hipoteses = asList(a['hipoteses']);
    final propNome = asMap(a['propriedade'])['nome'];
    final cultura =
        a['cultura_detectada'] ??
        a['cultura_informada'] ??
        'Cultura não informada';
    final subtitulo =
        '$cultura${propNome != null && '$propNome'.isNotEmpty ? ' · $propNome' : ''} · ${_formatarData(a['criado_em'])}';
    final podeExcluir = a['caso_id'] == null && a['ponto_vistoria_id'] == null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: md ? 20 : 16, vertical: 16),
        decoration: BoxDecoration(
          border: widget.primeira
              ? null
              : Border(top: BorderSide(color: hex('#E8ECE5'))),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onAbrir,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: meta.fundo,
                        ),
                        child: Icon(
                          LucideIcons.leaf,
                          size: 18,
                          color: meta.cor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hipoteses.isNotEmpty
                                  ? '${hipoteses.first['nome']}'
                                  : meta.titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _t(
                                14,
                                w: FontWeight.w600,
                                c: hex('#27352A'),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _t(11, c: hex('#818C81')),
                            ),
                          ],
                        ),
                      ),
                      if (md) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: meta.fundo,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _percentual(a['confianca']),
                            style: _t(10, w: FontWeight.w700, c: meta.cor),
                          ),
                        ),
                      ],
                      const SizedBox(width: 12),
                      Icon(
                        LucideIcons.chevronRight,
                        size: 17,
                        color: hex('#A1AAA0'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (podeExcluir) ...[
              const SizedBox(width: 12),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: !md || _hover ? 1 : 0,
                child: Tooltip(
                  message: 'Excluir análise',
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _hoverLixeira = true),
                    onExit: (_) => setState(() => _hoverLixeira = false),
                    child: _Tap(
                      color: _hoverLixeira
                          ? hex('#F9EDE8')
                          : Colors.transparent,
                      radius: 8,
                      onTap: widget.onRemover,
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          LucideIcons.trash2,
                          size: 15,
                          color: _hoverLixeira
                              ? hex('#A14D37')
                              : hex('#9AA39A'),
                        ),
                      ),
                    ),
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

/// Mede o tamanho do filho após o layout (para igualar a altura das colunas no xl).
class _Medir extends StatefulWidget {
  const _Medir({required this.child, required this.onSize});
  final Widget child;
  final ValueChanged<Size> onSize;

  @override
  State<_Medir> createState() => _MedirState();
}

class _MedirState extends State<_Medir> {
  Size? _ultimo;

  void _agendar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = context.size;
      if (s != null && s != _ultimo) {
        _ultimo = s;
        widget.onSize(s);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _agendar();
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _agendar();
        return true;
      },
      child: SizeChangedLayoutNotifier(child: widget.child),
    );
  }
}

/// animate-spin
class _Girando extends StatefulWidget {
  const _Girando(this.icone, {required this.size, required this.color});
  final IconData icone;
  final double size;
  final Color color;

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
  Widget build(BuildContext context) => RotationTransition(
    turns: _c,
    child: Icon(widget.icone, size: widget.size, color: widget.color),
  );
}

/// .foliar-enter — 320ms ease-out, translateY(8px) → 0 e opacidade 0 → 1.
class _Entrada extends StatefulWidget {
  const _Entrada({required this.child});
  final Widget child;

  @override
  State<_Entrada> createState() => _EntradaState();
}

class _EntradaState extends State<_Entrada>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..forward();
  late final Animation<double> _a = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOut,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    child: widget.child,
    builder: (_, child) => Opacity(
      opacity: _a.value,
      child: Transform.translate(
        offset: Offset(0, 8 * (1 - _a.value)),
        child: child,
      ),
    ),
  );
}

/// Valor 0→1→0 com ease-in-out em cada metade (keyframes 0%, 50%, 100%).
double _vaiEVolta(double t) {
  final fase = t < .5 ? t * 2 : (1 - t) * 2;
  return Curves.easeInOut.transform(fase.clamp(0.0, 1.0));
}

/// .foliar-scan — linha verde que desce 320px e volta em 3.6s, opacidade .35 ↔ .9.
class _LinhaScan extends StatefulWidget {
  const _LinhaScan();

  @override
  State<_LinhaScan> createState() => _LinhaScanState();
}

class _LinhaScanState extends State<_LinhaScan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) {
          return AnimatedBuilder(
            animation: _c,
            builder: (_, _) {
              final v = _vaiEVolta(_c.value);
              return Stack(
                children: [
                  Positioned(
                    left: c.maxWidth * .08,
                    right: c.maxWidth * .08,
                    top: c.maxHeight * .18 + 320 * v,
                    height: 1,
                    child: Opacity(
                      opacity: .35 + (.9 - .35) * v,
                      child: Container(
                        decoration: BoxDecoration(
                          color: hex('#8AFF72'),
                          boxShadow: const [
                            BoxShadow(
                              color: Color.fromRGBO(138, 255, 114, .75),
                              blurRadius: 18,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// .foliar-processing-dot — pulso de box-shadow 0 → 6px rgba(185,255,158,.12) em 1.25s.
class _PontoPulsando extends StatefulWidget {
  const _PontoPulsando({required this.child});
  final Widget child;

  @override
  State<_PontoPulsando> createState() => _PontoPulsandoState();
}

class _PontoPulsandoState extends State<_PontoPulsando>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (_, child) {
      final v = _vaiEVolta(_c.value);
      return DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(185, 255, 158, .12 * v),
              spreadRadius: 6 * v,
            ),
          ],
        ),
        child: child,
      );
    },
  );
}

/// Borda tracejada (border-dashed).
class _BordaTracejada extends CustomPainter {
  _BordaTracejada({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(.5);
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + 4, metric.length)),
          paint,
        );
        d += 7;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BordaTracejada old) =>
      old.color != color || old.radius != radius;
}
