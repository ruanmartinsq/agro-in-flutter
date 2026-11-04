import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/relatorios.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Port de src/pages/Dashboard.tsx
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _PropriedadeResumo {
  _PropriedadeResumo(this.nome, this.areaTotalHa, this.talhoes);
  final String nome;
  final String status = 'Ativa';
  final num areaTotalHa;
  final int talhoes;
}

class _MetaResumo {
  _MetaResumo(this.titulo, this.atual, this.alvo, this.unidade, this.prazo);
  final String titulo;
  final double atual, alvo;
  final String unidade;
  final String? prazo;
}

class _DashboardData {
  _PropriedadeResumo? propriedade;
  ({double saldoMes, List<double> historico})? financeiro;
  ({double colhendoTon, List<double> historico})? producao;
  List<({String nome, int percentual})> estoque = [];
  _MetaResumo? meta;
}

class _DashboardPageState extends State<DashboardPage> {
  _DashboardData? _data;
  bool _loading = true;
  late final List<RelatorioGerado> _relatoriosRecentes;

  @override
  void initState() {
    super.initState();
    _relatoriosRecentes =
        (lerHistoricoRelatorios()
                .where((r) => r.status == StatusRelatorio.pronto)
                .toList()
              ..sort((a, b) => b.geradoEm.compareTo(a.geradoEm)))
            .take(4)
            .toList();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final res = await Future.wait([
        api.get('/propriedades'),
        api.get('/estoque'),
        api.get('/financeiro'),
        api.get('/metas'),
        api.get('/producao'),
      ]);
      final propriedades = asList(res[0].data);
      final estoque = asList(res[1].data);
      final financeiro = asList(res[2].data);
      final metas = asList(res[3].data);
      final producao = asList(res[4].data);

      final entradas = financeiro
          .where((i) => i['tipo'] == 'entrada')
          .fold<double>(0, (t, i) => t + toDouble(i['valor']));
      final saidas = financeiro
          .where((i) => i['tipo'] == 'saida')
          .fold<double>(0, (t, i) => t + toDouble(i['valor']));

      final ordenado = [...financeiro]
        ..sort(
          (a, b) => (parseData(a['data']) ?? DateTime(0)).compareTo(
            parseData(b['data']) ?? DateTime(0),
          ),
        );
      final historicoFin = <double>[];
      for (final item in ordenado) {
        final ultimo = historicoFin.isEmpty ? 0.0 : historicoFin.last;
        final v = item['tipo'] == 'entrada'
            ? toDouble(item['valor'])
            : -toDouble(item['valor']);
        historicoFin.add(ultimo + v);
      }

      final metaAtiva = metas.firstWhere(
        (m) => m['status'] != 'concluida',
        orElse: () => metas.isNotEmpty ? metas.first : <String, dynamic>{},
      );

      final d = _DashboardData();
      if (propriedades.isNotEmpty) {
        final p = propriedades.first;
        d.propriedade = _PropriedadeResumo(
          '${p['nome']}',
          toDouble(p['area_total']),
          propriedades.length,
        );
      }
      if (financeiro.isNotEmpty) {
        d.financeiro = (saldoMes: entradas - saidas, historico: historicoFin);
      }
      if (producao.isNotEmpty) {
        final ultimos = producao.length > 5
            ? producao.sublist(producao.length - 5)
            : producao;
        d.producao = (
          colhendoTon: producao.fold<double>(
            0,
            (s, p) => s + toDouble(p['area_utilizada']),
          ),
          historico: ultimos
              .map((p) => toDouble(p['area_utilizada'] ?? p['quantidade']))
              .toList(),
        );
      }
      d.estoque = estoque.map((item) {
        final minimo = toDouble(item['quantidade_minima']);
        final pct = minimo > 0
            ? math.min(
                (toDouble(item['quantidade']) / minimo * 100).round(),
                100,
              )
            : 100;
        return (nome: '${item['item']}', percentual: pct);
      }).toList();
      if (metaAtiva.isNotEmpty) {
        d.meta = _MetaResumo(
          '${metaAtiva['descricao'] ?? ''}',
          toDouble(metaAtiva['valor_atual']),
          toDouble(metaAtiva['valor_alvo']),
          '${metaAtiva['unidade'] ?? ''}',
          metaAtiva['prazo']?.toString(),
        );
      }
      if (mounted) setState(() => _data = d);
    } catch (e) {
      debugPrint('Erro ao carregar dashboard: $e');
      if (mounted) setState(() => _data = _DashboardData());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatPrazo(String? data) {
    final d = parseData(data);
    if (d == null) return 'Sem prazo definido';
    final mes = formatPattern(d, 'MMM').replaceAll('.', '');
    return '$mes/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _data == null) {
      return const LoadingView('Carregando dashboard...');
    }
    final data = _data!;
    final w = MediaQuery.sizeOf(context).width;
    final hPad = w >= 1024 ? 40.0 : (w >= 640 ? 24.0 : 16.0);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          color: AgroColors.sidebar,
          padding: EdgeInsets.fromLTRB(
            hPad,
            w >= 1024 ? 32 : 24,
            hPad,
            w >= 1024 ? 28 : 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dashboard',
                style: TextStyle(
                  fontFamily: kTitleFont,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AgroColors.headerTitle,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Visão geral da sua propriedade',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: .65),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, w >= 1024 ? 28 : 20, hPad, 28),
          child: ResponsiveGrid(
            md: 2,
            xl: 3,
            children: [
              _Card(
                accent: AgroColors.accentPropriedade,
                title: 'Propriedades',
                footer: data.propriedade != null
                    ? 'Ver todas as propriedades'
                    : null,
                onFooterClick: () => context.go('/propriedade'),
                child: data.propriedade != null
                    ? _propriedade(data.propriedade!)
                    : _EmptyState(
                        label: 'Nenhuma propriedade cadastrada',
                        cta: 'Cadastrar propriedade',
                        onClick: () => context.go('/propriedade'),
                      ),
              ),
              _Card(
                accent: AgroColors.accentFinanceiro,
                title: 'Financeiro',
                footer: data.financeiro != null ? 'Ver extrato completo' : null,
                onFooterClick: () => context.go('/financeiro'),
                child: data.financeiro != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          const Text(
                            'Saldo do mês',
                            style: TextStyle(
                              fontSize: 12,
                              color: AgroColors.muted,
                            ),
                          ),
                          Text(
                            formatBRL(data.financeiro!.saldoMes),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 96,
                            width: double.infinity,
                            child: CustomPaint(
                              painter: _MiniAreaPainter(
                                data.financeiro!.historico,
                                AgroColors.accentFinanceiro,
                              ),
                            ),
                          ),
                        ],
                      )
                    : _EmptyState(
                        label: 'Nenhum lançamento este mês',
                        cta: 'Adicionar lançamento',
                        onClick: () => context.go('/financeiro'),
                      ),
              ),
              _Card(
                accent: AgroColors.accentProducao,
                title: 'Produção',
                footer: data.producao != null ? 'Ver extrato completo' : null,
                onFooterClick: () => context.go('/producao'),
                child: data.producao != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          const Text(
                            'Área total utilizada (ha)',
                            style: TextStyle(
                              fontSize: 12,
                              color: AgroColors.muted,
                            ),
                          ),
                          Text(
                            '${formatNum(data.producao!.colhendoTon)} ha',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _MiniBarChart(
                            data.producao!.historico,
                            AgroColors.accentProducao,
                          ),
                        ],
                      )
                    : _EmptyState(
                        label: 'Nenhum registro de produção',
                        cta: 'Registrar produção',
                        onClick: () => context.go('/producao'),
                      ),
              ),
              _Card(
                accent: AgroColors.accentEstoque,
                title: 'Estoques',
                footer: data.estoque.isNotEmpty ? 'Ver todo o estoque' : null,
                onFooterClick: () => context.go('/estoque'),
                child: data.estoque.isNotEmpty
                    ? Column(
                        children: [
                          for (final item in data.estoque)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, bottom: 6),
                              child: _ProgressBar(
                                item.nome,
                                item.percentual,
                                AgroColors.accentEstoque,
                              ),
                            ),
                        ],
                      )
                    : _EmptyState(
                        label: 'Estoque ainda não configurado',
                        cta: 'Adicionar item',
                        onClick: () => context.go('/estoque'),
                      ),
              ),
              _Card(
                accent: AgroColors.accentMetas,
                title: 'Metas',
                footer: data.meta != null ? 'Ver todas as metas' : null,
                onFooterClick: () => context.go('/meta'),
                child: data.meta != null
                    ? Row(
                        children: [
                          _ProgressRing(
                            data.meta!.alvo > 0
                                ? (data.meta!.atual / data.meta!.alvo * 100)
                                      .round()
                                : 0,
                            AgroColors.accentMetas,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data.meta!.titulo,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${formatNum(data.meta!.atual)} / ${formatNum(data.meta!.alvo)} ${data.meta!.unidade} · Prazo - ${_formatPrazo(data.meta!.prazo)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AgroColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : _EmptyState(
                        label: 'Nenhuma meta definida',
                        cta: 'Criar meta',
                        onClick: () => context.go('/meta'),
                      ),
              ),
              _Card(
                accent: AgroColors.accentRelatorios,
                title: 'Relatórios',
                footer: _relatoriosRecentes.isNotEmpty
                    ? 'Ver todos os relatórios'
                    : null,
                onFooterClick: () => context.go('/relatorios'),
                child: _relatoriosRecentes.isNotEmpty
                    ? Column(
                        children: [
                          for (final r in _relatoriosRecentes)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: AgroColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => context.go('/relatorios'),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r.titulo,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          tempoRelativo(r.geradoEm),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AgroColors.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      )
                    : _EmptyState(
                        label: 'Nenhum relatório gerado',
                        cta: 'Gerar relatório',
                        onClick: () => context.go('/relatorios'),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _propriedade(_PropriedadeResumo p) {
    Widget mini(String rotulo, String valor) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AgroColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rotulo,
              style: const TextStyle(fontSize: 11, color: AgroColors.muted),
            ),
            Text(
              valor,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
    return Column(
      children: [
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AgroColors.surfaceMuted,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  p.nome,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Pill(p.status),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            mini('Área Total', '${formatNum(p.areaTotalHa)} ha'),
            const SizedBox(width: 8),
            mini('Talhões', '${p.talhoes}'),
          ],
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.label,
    required this.cta,
    required this.onClick,
  });
  final String label, cta;
  final VoidCallback onClick;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AgroColors.muted,
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onClick,
          icon: const Icon(LucideIcons.plus, size: 13),
          label: Text(cta),
          style: OutlinedButton.styleFrom(
            foregroundColor: AgroColors.primary,
            backgroundColor: Colors.white,
            side: const BorderSide(color: AgroColors.emptyBorder),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(0, 34),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Card extends StatefulWidget {
  const _Card({
    required this.accent,
    required this.title,
    this.footer,
    this.onFooterClick,
    required this.child,
  });
  final Color accent;
  final String title;
  final String? footer;
  final VoidCallback? onFooterClick;
  final Widget child;

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final sm = MediaQuery.sizeOf(context).width >= 640;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
        constraints: BoxConstraints(minHeight: sm ? 224 : 190),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AgroColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(26, 48, 31, _hover ? .13 : .10),
              blurRadius: _hover ? 18 : 9,
              offset: Offset(0, _hover ? 7 : 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 6, color: widget.accent),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AgroColors.text,
                      ),
                    ),
                  ),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 15,
                    color: AgroColors.chevron,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: widget.child,
            ),
            if (widget.footer != null)
              InkWell(
                onTap: widget.onFooterClick,
                hoverColor: const Color(0xFFF5F7F3),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AgroColors.cardDivider),
                    ),
                  ),
                  child: Text(
                    widget.footer!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.accent,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniAreaPainter extends CustomPainter {
  _MiniAreaPainter(this.data, this.color);
  final List<double> data;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxV = data.reduce(math.max);
    final minV = data.reduce(math.min);
    final range = (maxV - minV) == 0 ? 1 : maxV - minV;
    final step = size.width / (data.length - 1 == 0 ? 1 : data.length - 1);
    final pts = [
      for (var i = 0; i < data.length; i++)
        Offset(
          i * step,
          size.height - ((data[i] - minV) / range) * size.height,
        ),
    ];
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    final area = Path()
      ..moveTo(0, size.height)
      ..addPolygon(pts, false)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .35), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniAreaPainter old) =>
      old.data != data || old.color != color;
}

class _MiniBarChart extends StatelessWidget {
  const _MiniBarChart(this.data, this.color);
  final List<double> data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final maxV = math.max(data.fold<double>(0, math.max), 1);
    return SizedBox(
      height: 96,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < data.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: math.max(96 * data[i] / maxV, 6),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar(this.label, this.percentual, this.color);
  final String label;
  final int percentual;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: AgroColors.text2),
            ),
          ),
          Text(
            '$percentual%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AgroColors.muted,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: percentual.clamp(0, 100) / 100,
          minHeight: 8,
          color: color,
          backgroundColor: AgroColors.track,
        ),
      ),
    ],
  );
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing(this.percentual, this.color);
  final int percentual;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 88,
    height: 88,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.all(4),
          child: CircularProgressIndicator(
            value: math.min(percentual, 100) / 100,
            strokeWidth: 8,
            color: color,
            backgroundColor: const Color(0xFFF1E7E3),
            strokeCap: StrokeCap.round,
          ),
        ),
        Center(
          child: Text(
            '$percentual%',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AgroColors.text,
            ),
          ),
        ),
      ],
    ),
  );
}
