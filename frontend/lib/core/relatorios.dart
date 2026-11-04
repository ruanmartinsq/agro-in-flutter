import 'dart:convert';

import 'storage.dart';

/// Port de src/hooks/relatorios.ts
enum CategoriaRelatorio { financeiro, producao, estoque, geral }

enum StatusRelatorio { pronto, agendado }

class RelatorioPropriedadeAPI {
  final String propriedade;
  final double entradas, saidas, saldo, producaoTotal;
  final int estoqueTotalItens;

  RelatorioPropriedadeAPI({
    required this.propriedade,
    required this.entradas,
    required this.saidas,
    required this.saldo,
    required this.producaoTotal,
    required this.estoqueTotalItens,
  });

  factory RelatorioPropriedadeAPI.fromJson(Map<String, dynamic> j) {
    double n(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    final fin = (j['financeiro'] ?? {}) as Map;
    return RelatorioPropriedadeAPI(
      propriedade: '${j['propriedade'] ?? ''}',
      entradas: n(fin['entradas']),
      saidas: n(fin['saidas']),
      saldo: n(fin['saldo']),
      producaoTotal: n((j['producao'] ?? {})['total']),
      estoqueTotalItens: n((j['estoque'] ?? {})['totalItens']).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'propriedade': propriedade,
    'financeiro': {'entradas': entradas, 'saidas': saidas, 'saldo': saldo},
    'producao': {'total': producaoTotal},
    'estoque': {'totalItens': estoqueTotalItens},
  };
}

class RelatorioGerado {
  final String id;
  final CategoriaRelatorio categoria;
  final String titulo;
  final DateTime geradoEm;
  final StatusRelatorio status;
  final bool compartilhado;
  final RelatorioPropriedadeAPI? dados;

  RelatorioGerado({
    required this.id,
    required this.categoria,
    required this.titulo,
    required this.geradoEm,
    required this.status,
    required this.compartilhado,
    this.dados,
  });

  RelatorioGerado copyWith({bool? compartilhado, StatusRelatorio? status}) =>
      RelatorioGerado(
        id: id,
        categoria: categoria,
        titulo: titulo,
        geradoEm: geradoEm,
        status: status ?? this.status,
        compartilhado: compartilhado ?? this.compartilhado,
        dados: dados,
      );

  factory RelatorioGerado.fromJson(Map<String, dynamic> j) => RelatorioGerado(
    id: '${j['id']}',
    categoria: CategoriaRelatorio.values.firstWhere(
      (c) => c.name == j['categoria'],
      orElse: () => CategoriaRelatorio.geral,
    ),
    titulo: '${j['titulo'] ?? ''}',
    geradoEm: DateTime.tryParse('${j['geradoEm']}') ?? DateTime.now(),
    status: j['status'] == 'agendado'
        ? StatusRelatorio.agendado
        : StatusRelatorio.pronto,
    compartilhado: j['compartilhado'] == true,
    dados: j['dados'] is Map
        ? RelatorioPropriedadeAPI.fromJson(
            Map<String, dynamic>.from(j['dados'] as Map),
          )
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'categoria': categoria.name,
    'titulo': titulo,
    'geradoEm': geradoEm.toIso8601String(),
    'status': status.name,
    'compartilhado': compartilhado,
    'dados': dados?.toJson(),
  };
}

const kChaveHistoricoRelatorios = 'agroin:relatorios:historico';

List<RelatorioGerado> lerHistoricoRelatorios() =>
    Storage.readEnvelope<List<RelatorioGerado>>(
      kChaveHistoricoRelatorios,
      const [],
      fromJson: (raw) => (raw as List)
          .map(
            (e) =>
                RelatorioGerado.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );

Future<void> gravarHistoricoRelatorios(List<RelatorioGerado> lista) =>
    Storage.writeEnvelope(
      kChaveHistoricoRelatorios,
      jsonDecode(jsonEncode(lista.map((e) => e.toJson()).toList())),
    );

String _pad(int n) => n.toString().padLeft(2, '0');

String tempoRelativo(DateTime data) {
  final diffMs =
      data.millisecondsSinceEpoch - DateTime.now().millisecondsSinceEpoch;
  if (diffMs > 0) return 'agendado para ${_pad(data.day)}/${_pad(data.month)}';
  final min = (-diffMs / 60000).floor();
  if (min < 1) return 'agora mesmo';
  if (min < 60) return 'há $min min';
  final horas = (min / 60).floor();
  if (horas < 24) return 'há ${horas}h';
  final dias = (horas / 24).floor();
  if (dias < 7) return 'há $dias ${dias == 1 ? 'dia' : 'dias'}';
  final semanas = (dias / 7).floor();
  if (semanas < 5) return 'há $semanas ${semanas == 1 ? 'semana' : 'semanas'}';
  final meses = (dias / 30).floor();
  return 'há $meses ${meses == 1 ? 'mês' : 'meses'}';
}
