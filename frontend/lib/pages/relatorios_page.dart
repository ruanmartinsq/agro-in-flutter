import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/relatorios.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Port de src/pages/Relatorios.tsx
class RelatoriosPage extends StatefulWidget {
  const RelatoriosPage({super.key});

  @override
  State<RelatoriosPage> createState() => _RelatoriosPageState();
}

// 'todas' | 'producao' | 'financeiro' | 'estoque'
const _abas = <(String, String)>[
  ('todas', 'Todas'),
  ('producao', 'Produção'),
  ('financeiro', 'Financeiro'),
  ('estoque', 'Estoque'),
];

const _chaveAba = 'agroin:relatorios:aba';
const _chavePropriedade = 'agroin:relatorios:propriedadeId';

const _categoriaLabel = <CategoriaRelatorio, String>{
  CategoriaRelatorio.financeiro: 'Financeiro',
  CategoriaRelatorio.producao: 'Produção',
  CategoriaRelatorio.estoque: 'Estoque',
  CategoriaRelatorio.geral: 'Geral',
};

const _iconeCategoria = <CategoriaRelatorio, IconData>{
  CategoriaRelatorio.financeiro: LucideIcons.dollarSign,
  CategoriaRelatorio.producao: LucideIcons.sprout,
  CategoriaRelatorio.estoque: LucideIcons.boxes,
  CategoriaRelatorio.geral: LucideIcons.fileText,
};

final _coresCategoria = <CategoriaRelatorio, ({Color bg, Color icone})>{
  CategoriaRelatorio.financeiro: (bg: hex('#E8F3EA'), icone: hex('#4E9462')),
  CategoriaRelatorio.producao: (bg: hex('#F8ECE8'), icone: hex('#E2574C')),
  CategoriaRelatorio.estoque: (bg: hex('#FFF3DC'), icone: hex('#D9A62E')),
  CategoriaRelatorio.geral: (bg: hex('#E8F3EA'), icone: hex('#1F5B3A')),
};

final _corAgendado = (bg: hex('#EAF2FB'), icone: hex('#4E829C'));

final _coresStatus = <StatusRelatorio, ({Color bg, Color texto})>{
  StatusRelatorio.pronto: (bg: hex('#E8F3EA'), texto: hex('#1F5B3A')),
  StatusRelatorio.agendado: (bg: hex('#EAF2FB'), texto: hex('#2A5C93')),
};

const _nomesMes = [
  'Jan',
  'Fev',
  'Mar',
  'Abr',
  'Mai',
  'Jun',
  'Jul',
  'Ago',
  'Set',
  'Out',
  'Nov',
  'Dez',
];

// Evita que o armazenamento cresça sem limite: guarda só os relatórios mais recentes.
const _maxHistoricoPersistido = 100;

String _mesAno(DateTime d) => '${_nomesMes[d.month - 1]}/${d.year}';

String _tituloRelatorio(CategoriaRelatorio categoria, DateTime data) {
  final ref = _mesAno(data);
  switch (categoria) {
    case CategoriaRelatorio.financeiro:
      return 'Fechamento financeiro - $ref';
    case CategoriaRelatorio.producao:
      return 'Produtividade - $ref';
    case CategoriaRelatorio.estoque:
      return 'Movimentação de estoque - $ref';
    case CategoriaRelatorio.geral:
      return 'Relatório geral - $ref';
  }
}

const _montserrat = kTitleFont;

class _RelatoriosPageState extends State<RelatoriosPage> {
  String _aba = 'todas';
  List<({int id, String nome})> _propriedades = [];
  int? _propriedadeId;
  bool _carregandoPropriedades = true;
  List<RelatorioGerado> _historico = [];
  bool _gerando = false;
  String _erroGeracao = '';
  final _idCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final aba = Storage.readEnvelope<dynamic>(_chaveAba, 'todas');
    _aba = _abas.any((a) => a.$1 == aba) ? aba as String : 'todas';
    _propriedadeId = toIntOrNull(
      Storage.readEnvelope<dynamic>(_chavePropriedade, null),
    );
    _idCtrl.text = _propriedadeId?.toString() ?? '';
    _historico = lerHistoricoRelatorios();
    _carregarPropriedades();
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }

  void _setAba(String aba) {
    setState(() => _aba = aba);
    Storage.writeEnvelope(_chaveAba, aba);
  }

  void _setPropriedadeId(int? id) {
    setState(() => _propriedadeId = id);
    Storage.writeEnvelope(_chavePropriedade, id);
  }

  void _setHistorico(List<RelatorioGerado> lista) {
    setState(() => _historico = lista);
    gravarHistoricoRelatorios(lista);
  }

  Future<void> _carregarPropriedades() async {
    setState(() => _carregandoPropriedades = true);
    try {
      final res = await api.get('/propriedades');
      final lista = asList(res.data)
          .map((p) => (id: toInt(p['id']), nome: '${p['nome'] ?? ''}'))
          .toList();
      if (!mounted) return;
      setState(() => _propriedades = lista);
      if (lista.isNotEmpty && _propriedadeId == null) {
        _setPropriedadeId(lista.first.id);
      }
    } catch (_) {
      if (mounted) setState(() => _propriedades = []);
    } finally {
      if (mounted) setState(() => _carregandoPropriedades = false);
    }
  }

  // ------------------------------------------------------------
  // Ações
  // ------------------------------------------------------------

  Future<void> _gerarRelatorio() async {
    if (_propriedadeId == null) {
      setState(
        () => _erroGeracao =
            'Selecione uma propriedade antes de gerar o relatório.',
      );
      return;
    }
    setState(() {
      _gerando = true;
      _erroGeracao = '';
    });
    try {
      final res = await api.get('/relatorios/$_propriedadeId');
      final dados = RelatorioPropriedadeAPI.fromJson(asMap(res.data));
      final categoria = _aba == 'todas'
          ? CategoriaRelatorio.geral
          : CategoriaRelatorio.values.firstWhere((c) => c.name == _aba);
      final agora = DateTime.now();
      final novo = RelatorioGerado(
        id: 'r-${agora.millisecondsSinceEpoch}',
        categoria: categoria,
        titulo: _tituloRelatorio(categoria, agora),
        geradoEm: agora,
        status: StatusRelatorio.pronto,
        compartilhado: false,
        dados: dados,
      );
      if (!mounted) return;
      _setHistorico(
        [novo, ..._historico].take(_maxHistoricoPersistido).toList(),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _erroGeracao =
              'Não foi possível gerar o relatório. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  void _alternarCompartilhado(String id) {
    _setHistorico(
      _historico
          .map(
            (r) => r.id == id ? r.copyWith(compartilhado: !r.compartilhado) : r,
          )
          .toList(),
    );
  }

  // window.print(): gera um PDF com o histórico filtrado e abre a janela de impressão/salvar PDF.
  Future<void> _exportarPDF() async {
    final doc = pw.Document();
    final verde = PdfColor.fromInt(0xFF1F5B3A);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(
            'Relatórios AGRO.IN',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: verde,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Gerado em ${formatDataHora(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const ['Relatório', 'Categoria', 'Status', 'Gerado em'],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: verde),
            cellStyle: const pw.TextStyle(fontSize: 10),
            data: [
              for (final r in _historicoFiltrado)
                [
                  r.titulo,
                  _categoriaLabel[r.categoria]!,
                  r.status.name,
                  formatData(r.geradoEm),
                ],
            ],
          ),
        ],
      ),
    );
    await Printing.layoutPdf(
      name: 'relatorios-agroin.pdf',
      onLayout: (_) => doc.save(),
    );
  }

  // Baixa (web) ou compartilha (celular/desktop) o CSV, como o download do React.
  Future<void> _exportarPlanilha() async {
    final linhas = <List<String>>[
      ['Relatório', 'Categoria', 'Status', 'Gerado em'],
      ..._historicoFiltrado.map(
        (r) => [
          r.titulo,
          _categoriaLabel[r.categoria]!,
          r.status.name,
          formatData(r.geradoEm),
        ],
      ),
    ];
    final csv = linhas
        .map((l) => l.map((v) => '"${v.replaceAll('"', '""')}"').join(';'))
        .join('\n');
    final nome = 'relatorios-agroin-${isoDate(DateTime.now())}.csv';
    // BOM para o Excel reconhecer acentos (UTF-8).
    final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'text/csv', name: nome)],
          fileNameOverrides: [nome],
        ),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: csv));
      if (mounted) {
        avisar(
          context,
          'Não foi possível salvar o arquivo. CSV copiado para a área de transferência.',
        );
      }
    }
  }

  // mailto: abre o app de e-mail com assunto e corpo preenchidos.
  Future<void> _enviarPorEmail() async {
    final itens = _historicoFiltrado
        .take(5)
        .map((r) => '- ${r.titulo} (${_categoriaLabel[r.categoria]})')
        .join('\n');
    final corpo = 'Segue o resumo dos últimos relatórios:\n\n$itens';
    final uri = Uri.parse(
      'mailto:?subject=${Uri.encodeComponent('Relatórios AGRO.IN')}&body=${Uri.encodeComponent(corpo)}',
    );
    final ok = await launchUrl(uri);
    if (!ok) {
      await Clipboard.setData(
        ClipboardData(text: 'Assunto: Relatórios AGRO.IN\n\n$corpo'),
      );
      if (mounted) {
        avisar(
          context,
          'Nenhum app de e-mail encontrado. Texto copiado para a área de transferência.',
        );
      }
    }
  }

  Future<void> _limparHistorico() async {
    final ok = await confirmar(
      context,
      'Limpar todo o histórico de relatórios salvo neste navegador?',
      confirmar: 'Limpar',
    );
    if (!ok) return;
    await Storage.removeEnvelope(kChaveHistoricoRelatorios);
    if (mounted) setState(() => _historico = []);
  }

  // ------------------------------------------------------------
  // Dados derivados
  // ------------------------------------------------------------

  List<RelatorioGerado> get _historicoFiltrado {
    final base = _historico
        .where((r) => _aba == 'todas' || r.categoria.name == _aba)
        .toList();
    final prontos =
        base.where((r) => r.status == StatusRelatorio.pronto).toList()
          ..sort((a, b) => b.geradoEm.compareTo(a.geradoEm));
    final agendados =
        base.where((r) => r.status == StatusRelatorio.agendado).toList()
          ..sort((a, b) => a.geradoEm.compareTo(b.geradoEm));
    return [...prontos, ...agendados];
  }

  int _prontosNoMes(int ano, int mes) => _historico
      .where(
        (r) =>
            r.status == StatusRelatorio.pronto &&
            r.geradoEm.toLocal().year == ano &&
            r.geradoEm.toLocal().month == mes,
      )
      .length;

  int get _geradosEsteMes {
    final hoje = DateTime.now();
    return _prontosNoMes(hoje.year, hoje.month);
  }

  int get _totalCompartilhados =>
      _historico.where((r) => r.compartilhado).length;

  RelatorioGerado? get _ultimoGerado {
    final prontos =
        _historico.where((r) => r.status == StatusRelatorio.pronto).toList()
          ..sort((a, b) => b.geradoEm.compareTo(a.geradoEm));
    return prontos.isEmpty ? null : prontos.first;
  }

  List<({String label, int total})> get _dadosGrafico {
    final hoje = DateTime.now();
    final lista = <({String label, int total})>[];
    for (var i = 5; i >= 0; i--) {
      final d = DateTime(hoje.year, hoje.month - i, 1);
      lista.add((
        label: _nomesMes[d.month - 1],
        total: _prontosNoMes(d.year, d.month),
      ));
    }
    return lista;
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
    final filtrado = _historicoFiltrado;
    final ultimo = _ultimoGerado;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Header
        Container(
          color: hex('#1F5B3A'),
          padding: EdgeInsets.fromLTRB(hPad, sm ? 32 : 24, hPad, 24),
          child: Flex(
            direction: sm ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: sm
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Flexible(
                fit: sm ? FlexFit.tight : FlexFit.loose,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Relatórios',
                      style: TextStyle(
                        fontFamily: _montserrat,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_historico.length} ${_historico.length == 1 ? 'relatório' : 'relatórios'} · último ${ultimo != null ? tempoRelativo(ultimo.geradoEm) : 'nenhum ainda'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: .65),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: sm ? 16 : 0, height: sm ? 0 : 16),
              _seletorPropriedade(),
            ],
          ),
        ),

        Padding(
          padding: EdgeInsets.fromLTRB(hPad, sm ? 32 : 24, hPad, sm ? 32 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Abas + gerar relatório
              Flex(
                direction: sm ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: sm
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    fit: sm ? FlexFit.tight : FlexFit.loose,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          for (final (key, label) in _abas) ...[
                            _BotaoAba(
                              label: label,
                              ativo: _aba == key,
                              onTap: () => _setAba(key),
                            ),
                            if (key != _abas.last.$1) const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: sm ? 12 : 0, height: sm ? 0 : 12),
                  _BotaoGerar(
                    gerando: _gerando,
                    onTap: (_gerando || _propriedadeId == null)
                        ? null
                        : _gerarRelatorio,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_erroGeracao.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: hex('#F8ECE8'),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.circleAlert,
                        size: 15,
                        color: hex('#A8553E'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _erroGeracao,
                          style: TextStyle(fontSize: 14, color: hex('#A8553E')),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Cards resumo
              _grid(
                cols: sm ? 2 : 1,
                spacing: 16,
                children: [
                  _CardResumo(
                    titulo: 'Gerados este mês',
                    valor: _geradosEsteMes,
                  ),
                  _CardResumo(
                    titulo: 'Compartilhados',
                    valor: _totalCompartilhados,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Gráfico + Exportar
              _grid(
                cols: lg ? 2 : 1,
                spacing: 20,
                children: [
                  _CardGrafico(dados: _dadosGrafico),
                  _CardExportar(
                    onPdf: _exportarPDF,
                    onPlanilha: _exportarPlanilha,
                    onEmail: _enviarPorEmail,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Histórico
              _historicoCard(filtrado, sm),
            ],
          ),
        ),
      ],
    );
  }

  Widget _grid({
    required int cols,
    required double spacing,
    required List<Widget> children,
  }) {
    if (cols == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            children[i],
          ],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }

  Widget _seletorPropriedade() {
    final fundo = Colors.white.withValues(alpha: .1);
    if (_carregandoPropriedades) {
      return Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: fundo,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Girando(
              child: Icon(
                LucideIcons.refreshCw,
                size: 14,
                color: Colors.white.withValues(alpha: .7),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Carregando...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: .7),
              ),
            ),
          ],
        ),
      );
    }
    if (_propriedades.isNotEmpty) {
      final valor = _propriedades.any((p) => p.id == _propriedadeId)
          ? _propriedadeId
          : null;
      return Container(
        height: 40,
        padding: const EdgeInsets.only(left: 12, right: 8),
        decoration: BoxDecoration(
          color: fundo,
          borderRadius: BorderRadius.circular(6),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: valor,
            isDense: true,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(6),
            icon: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                LucideIcons.chevronDown,
                size: 14,
                color: Colors.white.withValues(alpha: .7),
              ),
            ),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AgroColors.text,
            ),
            selectedItemBuilder: (_) => [
              for (final p in _propriedades)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    p.nome,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
            items: [
              for (final p in _propriedades)
                DropdownMenuItem(
                  value: p.id,
                  child: Text(
                    p.nome,
                    style: const TextStyle(color: AgroColors.text),
                  ),
                ),
            ],
            onChanged: (v) => _setPropriedadeId(v),
          ),
        ),
      );
    }
    return SizedBox(
      width: 160,
      height: 40,
      child: TextField(
        controller: _idCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (v) => _setPropriedadeId(v.isEmpty ? null : int.tryParse(v)),
        style: const TextStyle(fontSize: 14, color: Colors.white),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: 'ID da propriedade',
          hintStyle: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: .5),
          ),
          filled: true,
          fillColor: fundo,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _historicoCard(List<RelatorioGerado> filtrado, bool sm) {
    final borda = hex('#E1E6DF');
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: sm ? 24 : 20,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              color: hex('#F5F6F2'),
              border: Border(bottom: BorderSide(color: borda)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Histórico de relatórios',
                    style: TextStyle(
                      fontFamily: _montserrat,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: hex('#25352B'),
                    ),
                  ),
                ),
                if (_historico.isNotEmpty)
                  _Hover(
                    onTap: _limparHistorico,
                    child: Text(
                      'Limpar histórico',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: hex('#647269'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (filtrado.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 80),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: hex('#E9F1E8'),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.fileText,
                      size: 20,
                      color: hex('#8CA88A'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _historico.isEmpty
                        ? 'Nenhum relatório gerado ainda'
                        : 'Nenhum relatório nesta categoria',
                    style: TextStyle(fontSize: 14, color: hex('#647269')),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: hex('#E8F3EA'),
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: _gerarRelatorio,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.plus,
                              size: 13,
                              color: hex('#1F5B3A'),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Gerar relatório',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: hex('#1F5B3A'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < filtrado.length; i++)
              _linhaHistorico(filtrado[i], i < filtrado.length - 1, sm),
        ],
      ),
    );
  }

  Widget _linhaHistorico(RelatorioGerado r, bool comBorda, bool sm) {
    final corIcone = r.status == StatusRelatorio.agendado
        ? _corAgendado
        : _coresCategoria[r.categoria]!;
    final corStatus = _coresStatus[r.status]!;
    final temDados = r.dados != null;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: sm ? 24 : 20, vertical: 16),
      decoration: BoxDecoration(
        border: comBorda
            ? Border(bottom: BorderSide(color: hex('#EFF3ED')))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: corIcone.bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _iconeCategoria[r.categoria],
              size: 16,
              color: corIcone.icone,
            ),
          ),
          SizedBox(width: sm ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: hex('#25352B'),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_categoriaLabel[r.categoria]} · ${tempoRelativo(r.geradoEm)}',
                  style: TextStyle(fontSize: 12, color: hex('#647269')),
                ),
              ],
            ),
          ),
          SizedBox(width: sm ? 16 : 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: corStatus.bg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              r.status.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: corStatus.texto,
              ),
            ),
          ),
          SizedBox(width: sm ? 16 : 12),
          _BotaoIcone(
            icone: LucideIcons.eye,
            cor: hex('#1F5B3A'),
            fundo: hex('#F2F5F0'),
            tooltip: temDados
                ? 'Ver detalhes'
                : 'Detalhes indisponíveis para este exemplo',
            onTap: temDados ? () => _abrirDetalhe(r) : null,
          ),
          const SizedBox(width: 8),
          _BotaoIcone(
            icone: LucideIcons.share2,
            cor: r.compartilhado ? hex('#4E829C') : hex('#1F5B3A'),
            fundo: r.compartilhado ? hex('#EAF2FB') : hex('#F2F5F0'),
            tooltip: r.compartilhado
                ? 'Deixar de compartilhar'
                : 'Compartilhar',
            onTap: () => _alternarCompartilhado(r.id),
          ),
        ],
      ),
    );
  }

  void _abrirDetalhe(RelatorioGerado r) {
    final dados = r.dados;
    if (dados == null) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .4),
      builder: (ctx) => _ModalDetalhe(relatorio: r, dados: dados),
    );
  }
}

// ------------------------------------------------------------
// Widgets privados
// ------------------------------------------------------------

class _ModalDetalhe extends StatelessWidget {
  const _ModalDetalhe({required this.relatorio, required this.dados});
  final RelatorioGerado relatorio;
  final RelatorioPropriedadeAPI dados;

  @override
  Widget build(BuildContext context) {
    final sm = MediaQuery.sizeOf(context).width >= 640;
    final texto = hex('#25352B');
    final cinza = hex('#46564B');

    Widget caixa(
      String rotulo,
      String valor,
      Color bg,
      Color corRotulo, {
      Color? corValor,
      double tamanho = 16,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rotulo, style: TextStyle(fontSize: 12, color: corRotulo)),
            const SizedBox(height: 2),
            Text(
              valor,
              style: TextStyle(
                fontSize: tamanho,
                fontWeight: FontWeight.w700,
                color: corValor ?? texto,
              ),
            ),
          ],
        ),
      );
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: hex('#E1E6DF')),
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
                      relatorio.titulo,
                      style: TextStyle(
                        fontFamily: _montserrat,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: texto,
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
                        icon: Icon(
                          LucideIcons.x,
                          size: 18,
                          color: hex('#647269'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                dados.propriedade,
                style: TextStyle(fontSize: 12, color: hex('#647269')),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: caixa(
                      'Entradas',
                      formatBRL(dados.entradas),
                      hex('#E8F3EA'),
                      hex('#1F5B3A'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: caixa(
                      'Saídas',
                      formatBRL(dados.saidas),
                      hex('#F8ECE8'),
                      hex('#A8553E'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              caixa(
                'Saldo',
                formatBRL(dados.saldo),
                hex('#F2F5F0'),
                cinza,
                corValor: dados.saldo >= 0 ? hex('#1F5B3A') : hex('#A8553E'),
                tamanho: 18,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: caixa(
                      'Produções registradas',
                      _numero(dados.producaoTotal),
                      hex('#F2F5F0'),
                      cinza,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: caixa(
                      'Itens em estoque',
                      '${dados.estoqueTotalItens}',
                      hex('#F2F5F0'),
                      cinza,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Material(
                color: hex('#F2F5F0'),
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => Navigator.of(context).pop(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: Text(
                        'Fechar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: cinza,
                        ),
                      ),
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

  static String _numero(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _BotaoAba extends StatelessWidget {
  const _BotaoAba({
    required this.label,
    required this.ativo,
    required this.onTap,
  });
  final String label;
  final bool ativo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: ativo ? hex('#1F5B3A') : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
      side: BorderSide(color: hex('#E1E6DF')),
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
            color: ativo ? Colors.white : hex('#46564B'),
          ),
        ),
      ),
    ),
  );
}

class _BotaoGerar extends StatelessWidget {
  const _BotaoGerar({required this.gerando, required this.onTap});
  final bool gerando;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cor = hex('#1F5B3A');
    return Opacity(
      opacity: onTap == null ? .6 : 1,
      child: Material(
        color: hex('#9AE6A6'),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          hoverColor: Colors.black.withValues(alpha: .1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                gerando
                    ? _Girando(
                        child: Icon(
                          LucideIcons.refreshCw,
                          size: 16,
                          color: cor,
                        ),
                      )
                    : Icon(LucideIcons.plus, size: 16, color: cor),
                const SizedBox(width: 8),
                Text(
                  gerando ? 'Gerando...' : 'Gerar relatório',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cor,
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

class _CardResumo extends StatelessWidget {
  const _CardResumo({required this.titulo, required this.valor});
  final String titulo;
  final int valor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: BoxDecoration(
      color: hex('#EFF3ED'),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: TextStyle(fontSize: 14, color: hex('#647269'))),
        const SizedBox(height: 4),
        Text(
          '$valor',
          style: TextStyle(
            fontFamily: _montserrat,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: hex('#25352B'),
          ),
        ),
      ],
    ),
  );
}

class _CardTopo extends StatelessWidget {
  const _CardTopo({required this.corTopo, required this.child});
  final Color corTopo;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: hex('#E1E6DF')),
    ),
    child: Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: corTopo, width: 4)),
      ),
      padding: const EdgeInsets.all(24),
      child: child,
    ),
  );
}

class _CardGrafico extends StatelessWidget {
  const _CardGrafico({required this.dados});
  final List<({String label, int total})> dados;

  @override
  Widget build(BuildContext context) {
    final maxGrafico = math.max(
      1,
      dados.fold<int>(0, (m, d) => math.max(m, d.total)),
    );
    return _CardTopo(
      corTopo: hex('#1F5B3A'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Relatórios gerados por mês',
            style: TextStyle(
              fontFamily: _montserrat,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: hex('#25352B'),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < dados.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Tooltip(
                      message: '${dados[i].total} relatório(s)',
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 0,
                          end: dados[i].total == 0
                              ? 4
                              : math
                                    .max(10, dados[i].total / maxGrafico * 100)
                                    .toDouble(),
                        ),
                        duration: const Duration(milliseconds: 300),
                        builder: (_, h, _) => Container(
                          height: h,
                          decoration: BoxDecoration(
                            color: i == dados.length - 1
                                ? hex('#1F5B3A')
                                : hex('#AEC2A9'),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
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
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < dados.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dados[i].label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: hex('#647269')),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CardExportar extends StatelessWidget {
  const _CardExportar({
    required this.onPdf,
    required this.onPlanilha,
    required this.onEmail,
  });
  final VoidCallback onPdf, onPlanilha, onEmail;

  @override
  Widget build(BuildContext context) {
    final azul = hex('#4E829C');
    Widget item(IconData icone, String texto, VoidCallback onTap, bool borda) =>
        _Hover(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: borda
                  ? Border(bottom: BorderSide(color: hex('#EFF3ED')))
                  : null,
            ),
            child: Row(
              children: [
                Icon(icone, size: 17, color: azul),
                const SizedBox(width: 12),
                Text(
                  texto,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: hex('#25352B'),
                  ),
                ),
              ],
            ),
          ),
        );

    return _CardTopo(
      corTopo: azul,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Exportar',
            style: TextStyle(
              fontFamily: _montserrat,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: hex('#25352B'),
            ),
          ),
          const SizedBox(height: 16),
          item(LucideIcons.fileText, 'Exportar em PDF', onPdf, true),
          item(
            LucideIcons.fileSpreadsheet,
            'Exportar em planilha',
            onPlanilha,
            true,
          ),
          item(LucideIcons.mail, 'Enviar por e-mail', onEmail, false),
        ],
      ),
    );
  }
}

class _BotaoIcone extends StatelessWidget {
  const _BotaoIcone({
    required this.icone,
    required this.cor,
    required this.fundo,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icone;
  final Color cor, fundo;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Opacity(
      opacity: onTap == null ? .4 : 1,
      child: Material(
        color: fundo,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icone, size: 13, color: cor),
          ),
        ),
      ),
    ),
  );
}

/// hover:opacity-70
class _Hover extends StatefulWidget {
  const _Hover({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<_Hover> createState() => _HoverState();
}

class _HoverState extends State<_Hover> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedOpacity(
        opacity: _hover ? .7 : 1,
        duration: const Duration(milliseconds: 150),
        child: widget.child,
      ),
    ),
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
