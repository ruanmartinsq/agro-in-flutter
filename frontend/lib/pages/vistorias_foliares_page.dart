import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/geolocalizacao_stub.dart'
    if (dart.library.js_interop) '../core/geolocalizacao_web.dart';
import '../core/theme.dart';
import '../widgets/analise_foliar_nav.dart';
import '../widgets/common.dart';

/// Port de src/pages/VistoriasFoliares.tsx
class VistoriasFoliaresPage extends StatefulWidget {
  const VistoriasFoliaresPage({super.key});

  @override
  State<VistoriasFoliaresPage> createState() => _VistoriasFoliaresPageState();
}

// ---------------------------------------------------------------------------
// Modelos
// ---------------------------------------------------------------------------

class _AnalisePonto {
  _AnalisePonto(Map<String, dynamic> j)
    : id = toInt(j['id']),
      statusGeral = j['status_geral']?.toString() ?? '',
      criadoEm = j['criado_em']?.toString() ?? '';
  final int id;
  final String statusGeral;
  final String criadoEm;
}

class _PontoVistoria {
  _PontoVistoria(Map<String, dynamic> j)
    : id = toInt(j['id']),
      nome = j['nome']?.toString() ?? '',
      setor = j['setor']?.toString(),
      ordem = toInt(j['ordem']),
      latitude = toDoubleOrNull(j['latitude']),
      longitude = toDoubleOrNull(j['longitude']),
      precisaoMetros = toDoubleOrNull(j['precisao_metros']),
      analises = asList(j['analises']).map(_AnalisePonto.new).toList();
  final int id;
  final String nome;
  final String? setor;
  final int ordem;
  final double? latitude;
  final double? longitude;
  final double? precisaoMetros;
  final List<_AnalisePonto> analises;
}

class _Vistoria {
  _Vistoria(Map<String, dynamic> j)
    : id = toInt(j['id']),
      nome = j['nome']?.toString() ?? '',
      cultura = j['cultura']?.toString(),
      status = j['status']?.toString() ?? 'em_andamento',
      propriedadeNome = j['propriedade'] is Map
          ? asMap(j['propriedade'])['nome']?.toString()
          : null,
      pontos = asList(j['pontos']).map(_PontoVistoria.new).toList(),
      resumo = asMap(j['resumo']);
  final int id;
  final String nome;
  final String? cultura;
  final String status;
  final String? propriedadeNome;
  final List<_PontoVistoria> pontos;
  final Map<String, dynamic> resumo;

  bool get emAndamento => status == 'em_andamento';
}

/// `Intl.DateTimeFormat("pt-BR", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" })`
String _dataCurta(String valor) {
  final d = parseData(valor);
  return d == null ? valor : formatPattern(d, "dd 'de' MMM, HH:mm");
}

double _distanciaMetros(PosicaoGps a, double bLat, double bLon) {
  const raio = 6371000.0;
  double rad(double v) => v * math.pi / 180;
  final deltaLat = rad(bLat - a.latitude);
  final deltaLon = rad(bLon - a.longitude);
  final valor =
      math.pow(math.sin(deltaLat / 2), 2) +
      math.cos(rad(a.latitude)) *
          math.cos(rad(bLat)) *
          math.pow(math.sin(deltaLon / 2), 2);
  return raio * 2 * math.atan2(math.sqrt(valor), math.sqrt(1 - valor));
}

String _rotuloStatus(String? status) {
  if (status == null || status.isEmpty) return 'Aguardando foto';
  if (status == 'aparentemente_saudavel') return 'Aparentemente saudável';
  if (status == 'inconclusivo') return 'Inconclusivo';
  return 'Sinal para verificar';
}

const _primary = Color(0xFF1F5B3A);

// ---------------------------------------------------------------------------
// Página
// ---------------------------------------------------------------------------

class _VistoriasFoliaresPageState extends State<VistoriasFoliaresPage> {
  List<_Vistoria> _vistorias = [];
  List<({int id, String nome})> _propriedades = [];
  bool _carregando = true;
  bool _ocupado = false;
  String _erro = '';
  bool _criando = false;
  final _nome = TextEditingController();
  final _cultura = TextEditingController();
  String _propriedadeId = '';
  final _novoPonto = TextEditingController();
  final Map<int, double> _distancias = {};
  bool _online = conectado;
  late final void Function() _pararConexao;

  @override
  void initState() {
    super.initState();
    _pararConexao = ouvirConexao((online) {
      if (mounted) setState(() => _online = online);
    });
    _novoPonto.addListener(() => setState(() {}));
    _carregar();
  }

  @override
  void dispose() {
    _pararConexao();
    _nome.dispose();
    _cultura.dispose();
    _novoPonto.dispose();
    super.dispose();
  }

  String? get _paramId => GoRouterState.of(context).uri.queryParameters['id'];

  void _setParams(int id) => context.go('/analise-foliar/vistorias?id=$id');

  _Vistoria? get _selecionada {
    final solicitado = int.tryParse(_paramId ?? '') ?? 0;
    final id = solicitado != 0
        ? solicitado
        : (_vistorias.isNotEmpty ? _vistorias.first.id : null);
    for (final v in _vistorias) {
      if (v.id == id) return v;
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
      final res = await Future.wait([
        api.get('/analise-foliar/vistorias'),
        api.get('/propriedades'),
      ]);
      if (!mounted) return;
      final vistorias = asList(res[0].data).map(_Vistoria.new).toList();
      setState(() {
        _vistorias = vistorias;
        _propriedades = asList(res[1].data)
            .map((p) => (id: toInt(p['id']), nome: p['nome']?.toString() ?? ''))
            .toList();
      });
      if ((_paramId ?? '').isEmpty && vistorias.isNotEmpty) {
        _setParams(vistorias.first.id);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _erro = _tratarErro(e, 'Não foi possível carregar as vistorias.'),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  /// Equivalente a `obterPosicao()`: lança uma mensagem pronta para exibir.
  Future<PosicaoGps> _obterPosicao() async {
    try {
      return await obterPosicaoGps();
    } on GpsException catch (e) {
      throw _ErroGps(
        e.indisponivel ? 'GPS não disponível neste navegador.' : 'Não foi possível obter o GPS. Libere a localização e tente a céu aberto.',
      );
    }
  }

  void _substituir(Map<String, dynamic> json) {
    final nova = _Vistoria(json);
    _vistorias = _vistorias.map((v) => v.id == nova.id ? nova : v).toList();
  }

  Future<void> _criarVistoria() async {
    if (_nome.text.trim().isEmpty) {
      setState(() => _erro = 'Informe um nome para a vistoria.');
      return;
    }
    setState(() {
      _ocupado = true;
      _erro = '';
    });
    try {
      final res = await api.post(
        '/analise-foliar/vistorias',
        data: {
          'nome': _nome.text.trim(),
          if (_cultura.text.trim().isNotEmpty) 'cultura': _cultura.text.trim(),
          if (_propriedadeId.isNotEmpty)
            'propriedade_id': int.parse(_propriedadeId),
        },
      );
      if (!mounted) return;
      final nova = _Vistoria(asMap(res.data));
      setState(() {
        _vistorias = [nova, ..._vistorias];
        _criando = false;
        _nome.clear();
        _cultura.clear();
        _propriedadeId = '';
      });
      _setParams(nova.id);
    } catch (e) {
      if (mounted) {
        setState(
          () => _erro = _tratarErro(e, 'Não foi possível criar a vistoria.'),
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _marcarPonto(_PontoVistoria ponto) async {
    final sel = _selecionada;
    if (sel == null) return;
    setState(() {
      _ocupado = true;
      _erro = '';
    });
    try {
      final posicao = await _obterPosicao();
      final res = await api.patch(
        '/analise-foliar/vistorias/${sel.id}/pontos/${ponto.id}/localizacao',
        data: {
          'latitude': posicao.latitude,
          'longitude': posicao.longitude,
          'precisao_metros': posicao.precisao,
        },
      );
      if (!mounted) return;
      setState(() {
        _substituir(asMap(res.data));
        _distancias[ponto.id] = 0;
      });
    } on _ErroGps catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (e) {
      if (mounted) {
        setState(
          () => _erro = _tratarErro(e, 'Não foi possível marcar o ponto.'),
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _medirDistancia(_PontoVistoria ponto) async {
    final lat = ponto.latitude, lon = ponto.longitude;
    if (lat == null || lon == null) return;
    setState(() {
      _ocupado = true;
      _erro = '';
    });
    try {
      final posicao = await _obterPosicao();
      if (!mounted) return;
      setState(
        () => _distancias[ponto.id] = _distanciaMetros(posicao, lat, lon),
      );
    } on _ErroGps catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (_) {
      if (mounted) setState(() => _erro = 'GPS indisponível.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _adicionarPonto() async {
    final sel = _selecionada;
    if (sel == null || _novoPonto.text.trim().isEmpty) return;
    setState(() => _ocupado = true);
    try {
      final res = await api.post(
        '/analise-foliar/vistorias/${sel.id}/pontos',
        data: {'nome': _novoPonto.text.trim()},
      );
      if (!mounted) return;
      setState(() => _substituir(asMap(res.data)));
      _novoPonto.clear();
    } catch (e) {
      if (mounted) {
        setState(
          () => _erro = _tratarErro(e, 'Não foi possível adicionar o ponto.'),
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _alternarStatus() async {
    final sel = _selecionada;
    if (sel == null) return;
    if (sel.emAndamento &&
        !await confirmar(
          context,
          'Concluir esta vistoria? Os pontos e análises continuarão disponíveis.',
          confirmar: 'OK',
        )) {
      return;
    }
    setState(() => _ocupado = true);
    try {
      final acao = sel.emAndamento ? 'concluir' : 'reabrir';
      final res = await api.post('/analise-foliar/vistorias/${sel.id}/$acao');
      if (!mounted) return;
      setState(() => _substituir(asMap(res.data)));
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _erro = _tratarErro(e, 'Não foi possível atualizar a vistoria.'),
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
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
    final selecionada = _selecionada;

    final statusConexao = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _online ? Colors.white : const Color(0xFFFFF6EE),
        border: Border.all(
          color: _online ? const Color(0xFFCDE0CC) : const Color(0xFFE6C5AC),
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _online ? LucideIcons.satellite : LucideIcons.wifiOff,
            size: 14,
            color: _online ? const Color(0xFF386443) : const Color(0xFF8A4B25),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _online
                  ? 'Sincronização disponível'
                  : 'Sem internet para analisar',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _online
                    ? const Color(0xFF386443)
                    : const Color(0xFF8A4B25),
              ),
            ),
          ),
        ],
      ),
    );

    final tituloCabecalho = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(LucideIcons.mapPinned, size: 14, color: Color(0xFF317244)),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'AMOSTRAGEM ORIENTATIVA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.98,
                  color: Color(0xFF317244),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Vistoria de área',
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
            'Percorra pontos espaçados, registre a posição e volte ao mesmo lugar para comparar a evolução.',
            style: TextStyle(
              fontSize: 14,
              height: 24 / 14,
              color: Color(0xFF687267),
            ),
          ),
        ),
      ],
    );

    return ListView(
      padding: EdgeInsets.zero,
      children: [
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
            child: md
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: tituloCabecalho),
                      const SizedBox(width: 16),
                      statusConexao,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      tituloCabecalho,
                      const SizedBox(height: 16),
                      statusConexao,
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
                _barraVistorias(selecionada),
                const SizedBox(height: 20),
                if (_criando) ...[_formulario(md), const SizedBox(height: 20)],
                if (selecionada == null)
                  _vazio()
                else
                  _painel(selecionada, md, lg),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _barraVistorias(_Vistoria? selecionada) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    runSpacing: 12,
    children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, v) in _vistorias.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Material(
                color: v.id == selecionada?.id
                    ? const Color(0xFFE8F3E6)
                    : Colors.white,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: v.id == selecionada?.id
                        ? const Color(0xFF397348)
                        : const Color(0xFFD6DED3),
                  ),
                ),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => _setParams(v.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Text(
                      v.nome,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF31513A),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      _BotaoVerde(
        icon: LucideIcons.plus,
        label: 'Nova vistoria',
        onPressed: () => setState(() => _criando = !_criando),
      ),
    ],
  );

  InputDecoration _decoracao(
    String hint, {
    Color foco = const Color(0xFF4A8A55),
    Color borda = const Color(0xFFDCE2D8),
  }) {
    final b = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: borda),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9DAA9F)),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: b,
      enabledBorder: b,
      focusedBorder: b.copyWith(borderSide: BorderSide(color: foco)),
    );
  }

  Widget _formulario(bool md) {
    Widget rotulo(String texto, Widget campo) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          texto,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF425346),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(height: 44, child: campo),
      ],
    );
    const estilo = TextStyle(fontSize: 14, color: AgroColors.text);

    final nome = rotulo(
      'Nome',
      TextField(
        controller: _nome,
        style: estilo,
        decoration: _decoracao('Talhão norte · julho'),
      ),
    );
    final cultura = rotulo(
      'Cultura',
      TextField(
        controller: _cultura,
        style: estilo,
        decoration: _decoracao('Ex.: soja'),
      ),
    );
    final propriedade = rotulo(
      'Propriedade',
      DropdownButtonFormField<String>(
        initialValue: _propriedadeId,
        isExpanded: true,
        style: estilo,
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(6),
        decoration: _decoracao('', foco: const Color(0xFFDCE2D8)),
        items: [
          const DropdownMenuItem(value: '', child: Text('Sem vínculo')),
          for (final p in _propriedades)
            DropdownMenuItem(value: '${p.id}', child: Text(p.nome)),
        ],
        onChanged: (v) => setState(() => _propriedadeId = v ?? ''),
      ),
    );
    final botao = SizedBox(
      height: 44,
      child: Opacity(
        opacity: _ocupado ? 0.5 : 1,
        child: Material(
          color: _primary,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: _ocupado ? null : _criarVistoria,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Center(
                widthFactor: 1,
                child: Text(
                  'Criar roteiro',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD9E1D5)),
      ),
      child: md
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: nome),
                const SizedBox(width: 12),
                Expanded(child: cultura),
                const SizedBox(width: 12),
                Expanded(child: propriedade),
                const SizedBox(width: 12),
                botao,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                nome,
                const SizedBox(height: 12),
                cultura,
                const SizedBox(height: 12),
                propriedade,
                const SizedBox(height: 12),
                botao,
              ],
            ),
    );
  }

  Widget _vazio() => CustomPaint(
    foregroundPainter: const _BordaTracejada(
      color: Color(0xFFC9D4C6),
      radius: 8,
    ),
    child: Container(
      constraints: const BoxConstraints(minHeight: 420),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.route, size: 40, color: Color(0xFF3B7748)),
          const SizedBox(height: 20),
          const Text(
            'Monte o primeiro roteiro',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AgroColors.text,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 512),
            child: const Text(
              'O sistema cria cinco pontos iniciais em sequência: frente, esquerda, centro, direita e fundo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 24 / 14,
                color: Color(0xFF6F7B70),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _painel(_Vistoria sel, bool md, bool lg) {
    final emCampo = sel.pontos
        .where((p) => p.latitude != null && p.longitude != null)
        .length;
    final r = sel.resumo;

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sel.emAndamento ? 'EM CAMPO' : 'VISTORIA CONCLUÍDA',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: Color(0xFF5D7B63),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          sel.nome,
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
      onPressed: _ocupado ? null : _alternarStatus,
      icon: sel.emAndamento ? LucideIcons.circleCheck : LucideIcons.refreshCw,
      label: sel.emAndamento ? 'Concluir vistoria' : 'Reabrir',
      iconSize: 16,
      fontSize: 12,
      minHeight: 44,
      borderColor: const Color(0xFFCBD6C8),
      color: const Color(0xFF31533A),
      radius: 6,
      background: Colors.transparent,
    );

    final indicadores = <(String, String)>[
      ('Cobertura', '${_num(r['cobertura'])}%'),
      (
        'Fotografados',
        '${_num(r['pontos_fotografados'])}/${_num(r['pontos_previstos'])}',
      ),
      ('Com sinais', _num(r['pontos_com_sinal'])),
      ('GPS marcado', '$emCampo/${sel.pontos.length}'),
    ];
    Widget celula((String, String) item) => Container(
      color: const Color(0xFFF8FAF6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.$1.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 1.2,
              color: Color(0xFF7A867A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.$2,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AgroColors.text,
            ),
          ),
        ],
      ),
    );
    final colunas = md ? 4 : 2;
    final linhas = <Widget>[];
    for (var i = 0; i < indicadores.length; i += colunas) {
      if (i > 0) linhas.add(const SizedBox(height: 1));
      linhas.add(
        Row(
          children: [
            for (var j = i; j < i + colunas; j++) ...[
              if (j > i) const SizedBox(width: 1),
              Expanded(child: celula(indicadores[j])),
            ],
          ],
        ),
      );
    }

    final cabecalho = Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE1E6DE))),
      ),
      padding: EdgeInsets.symmetric(horizontal: md ? 28 : 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (md)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: info),
                const SizedBox(width: 16),
                botaoStatus,
              ],
            )
          else ...[
            info,
            const SizedBox(height: 16),
            botaoStatus,
          ],
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFDCE3D8),
              border: Border.all(color: const Color(0xFFDCE3D8)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Column(children: linhas),
            ),
          ),
        ],
      ),
    );

    final pontos = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (indice, ponto) in sel.pontos.indexed) ...[
          if (indice > 0)
            const Divider(height: 1, thickness: 1, color: Color(0xFFE4E9E1)),
          _ponto(sel, ponto, indice, md),
        ],
      ],
    );

    final aside = _roteiro(sel);

    Widget corpo;
    if (lg) {
      corpo = Stack(
        children: [
          const Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 310,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFF6F8F3),
                border: Border(left: BorderSide(color: Color(0xFFE1E6DE))),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: pontos),
              const SizedBox(width: 1),
              SizedBox(width: 309, child: aside),
            ],
          ),
        ],
      );
    } else {
      corpo = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          pontos,
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF6F8F3),
              border: Border(top: BorderSide(color: Color(0xFFE1E6DE))),
            ),
            child: aside,
          ),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [cabecalho, corpo],
        ),
      ),
    );
  }

  Widget _ponto(_Vistoria sel, _PontoVistoria ponto, int indice, bool md) {
    final ultima = ponto.analises.isEmpty ? null : ponto.analises.last;
    final temSinal =
        ultima != null &&
        !const [
          'aparentemente_saudavel',
          'inconclusivo',
        ].contains(ultima.statusGeral);
    final distancia = _distancias[ponto.id];

    final numero = Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: temSinal
            ? const Color(0xFFFBECE5)
            : ultima != null
            ? const Color(0xFFE7F5E7)
            : const Color(0xFFEEF1EC),
      ),
      child: Text(
        '${indice + 1}',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: temSinal
              ? const Color(0xFF9B482E)
              : ultima != null
              ? const Color(0xFF276D39)
              : const Color(0xFF677467),
        ),
      ),
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
              ponto.nome,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AgroColors.text,
              ),
            ),
            if ((ponto.setor ?? '').isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF3EC),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  ponto.setor!.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                    color: Color(0xFF687668),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${_rotuloStatus(ultima?.statusGeral)}${ultima != null ? ' · ${_dataCurta(ultima.criadoEm)}' : ''}',
          style: const TextStyle(fontSize: 11, color: Color(0xFF7A857A)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(LucideIcons.mapPin, size: 12, color: Color(0xFF657365)),
            Text(
              ponto.latitude != null
                  ? 'Ponto salvo · precisão ±${(ponto.precisaoMetros ?? 0).round()} m'
                  : 'Local ainda não marcado',
              style: const TextStyle(fontSize: 10, color: Color(0xFF657365)),
            ),
            if (distancia != null)
              Text(
                'Você está a ${distancia < 1000 ? '${distancia.round()} m' : '${(distancia / 1000).toStringAsFixed(1)} km'}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF205F31),
                ),
              ),
          ],
        ),
      ],
    );

    final botoes = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: md ? WrapAlignment.end : WrapAlignment.start,
      children: [
        if (sel.emAndamento)
          _BotaoBorda(
            onPressed: _ocupado ? null : () => _marcarPonto(ponto),
            icon: LucideIcons.locateFixed,
            label: ponto.latitude == null ? 'Marcar GPS' : 'Atualizar GPS',
          ),
        if (ponto.latitude != null)
          _BotaoBorda(
            onPressed: _ocupado ? null : () => _medirDistancia(ponto),
            icon: LucideIcons.crosshair,
            label: 'Voltar ao ponto',
          ),
        if (sel.emAndamento)
          _BotaoVerde(
            icon: LucideIcons.camera,
            iconSize: 14,
            label: 'Fotografar',
            fontSize: 10,
            gap: 6,
            radius: 8,
            minHeight: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            onPressed: () => context.go(
              '/analise-foliar?ponto=${ponto.id}&vistoria=${sel.id}',
            ),
          ),
      ],
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: md ? 28 : 20, vertical: 20),
      child: md
          ? Row(
              children: [
                numero,
                const SizedBox(width: 16),
                Expanded(child: texto),
                const SizedBox(width: 16),
                botoes,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                numero,
                const SizedBox(height: 16),
                texto,
                const SizedBox(height: 16),
                botoes,
              ],
            ),
    );
  }

  Widget _roteiro(_Vistoria sel) {
    final podeAdicionar = _novoPonto.text.trim().isNotEmpty && !_ocupado;
    final borda = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: Color(0xFFD7DED3)),
    );
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.footprints, size: 16, color: AgroColors.text),
              SizedBox(width: 8),
              Text(
                'Roteiro de campo',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AgroColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Stack(
            children: [
              Positioned(
                left: 9,
                top: 12,
                bottom: 12,
                width: 1,
                child: Container(color: const Color(0xFFB8C8B5)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, ponto) in sel.pontos.indexed) ...[
                    if (i > 0) const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          color: const Color(0xFFF6F8F3),
                          child: const Icon(
                            LucideIcons.circleDot,
                            size: 19,
                            color: Color(0xFF4D8056),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            ponto.nome,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF536256),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (sel.emAndamento) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _novoPonto,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AgroColors.text,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Outro ponto',
                        hintStyle: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9DAA9F),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: borda,
                        enabledBorder: borda,
                        focusedBorder: borda,
                      ),
                      onSubmitted: (_) =>
                          podeAdicionar ? _adicionarPonto() : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Opacity(
                  opacity: podeAdicionar ? 1 : 0.4,
                  child: Tooltip(
                    message: 'Adicionar ponto',
                    child: Material(
                      color: _primary,
                      borderRadius: BorderRadius.circular(6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: podeAdicionar ? _adicionarPonto : null,
                        child: const SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(
                            LucideIcons.plus,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9E7),
              border: Border.all(color: const Color(0xFFE4D9AF)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 10,
                  height: 20 / 10,
                  color: Color(0xFF756220),
                ),
                children: [
                  TextSpan(
                    text: 'Leitura orientativa.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text:
                        ' Caminhe em zigue-zague e distribua pontos em zonas homogêneas. '
                        'Cinco fotos não representam automaticamente toda a área.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'O GPS ajuda a retornar ao local, mas a precisão varia com aparelho, céu e vegetação. '
            'A análise e a sincronização exigem internet.',
            style: TextStyle(
              fontSize: 10,
              height: 20 / 10,
              color: Color(0xFF748074),
            ),
          ),
        ],
      ),
    );
  }
}

/// Valor numérico do resumo como o JS o imprimiria (inteiro sem ".0").
String _num(dynamic v) {
  final d = toDouble(v);
  return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
}

class _ErroGps implements Exception {
  const _ErroGps(this.mensagem);
  final String mensagem;
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

/// Botão verde (bg #1F5B3A, texto branco, bold).
class _BotaoVerde extends StatelessWidget {
  const _BotaoVerde({
    required this.label,
    required this.onPressed,
    required this.icon,
    this.iconSize = 15,
    this.fontSize = 12,
    this.minHeight = 0,
    this.gap = 8,
    this.radius = 6,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final double iconSize;
  final double fontSize;
  final double minHeight;
  final double gap;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Material(
    color: _primary,
    borderRadius: BorderRadius.circular(radius),
    child: InkWell(
      borderRadius: BorderRadius.circular(radius),
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: iconSize, color: Colors.white),
              SizedBox(width: gap),
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

/// Botão com borda (padrão: ações do ponto — border #D4DDD1, texto #49604E, 10px, rounded-lg).
class _BotaoBorda extends StatelessWidget {
  const _BotaoBorda({
    required this.label,
    required this.onPressed,
    required this.icon,
    this.iconSize = 14,
    this.fontSize = 10,
    this.minHeight = 40,
    this.borderColor = const Color(0xFFD4DDD1),
    this.color = const Color(0xFF49604E),
    this.radius = 8,
    this.background = Colors.transparent,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final double iconSize;
  final double fontSize;
  final double minHeight;
  final Color borderColor;
  final Color color;
  final double radius;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final grande = fontSize >= 12;
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: grande ? 16 : 12,
              vertical: grande ? 10 : 8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: iconSize, color: color),
                SizedBox(width: grande ? 8 : 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
