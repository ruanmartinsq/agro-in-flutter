import 'package:intl/intl.dart';

final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
final _num = NumberFormat.decimalPattern('pt_BR');

/// `valor.toLocaleString("pt-BR", { style: "currency", currency: "BRL" })`
String formatBRL(num valor) => _brl.format(valor);

/// `valor.toLocaleString("pt-BR")`
String formatNum(num valor) => _num.format(valor);

/// dd/MM/yyyy
String formatData(DateTime? d) =>
    d == null ? '—' : DateFormat('dd/MM/yyyy', 'pt_BR').format(d.toLocal());

/// dd/MM/yyyy às HH:mm
String formatDataHora(DateTime? d) => d == null
    ? '—'
    : DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR').format(d.toLocal());

/// Formata com um padrão do intl em pt_BR (ex.: 'MMM', 'd MMM yyyy').
String formatPattern(DateTime d, String pattern) =>
    DateFormat(pattern, 'pt_BR').format(d.toLocal());

DateTime? parseData(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

/// yyyy-MM-dd (valor de <input type="date">)
String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
