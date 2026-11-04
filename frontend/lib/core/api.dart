import 'package:dio/dio.dart';

import 'config.dart';
import 'storage.dart';

/// Cliente HTTP — equivalente ao `api` (axios) do React.
/// Adiciona automaticamente `Authorization: Bearer <token>` em toda requisição.
/// Uso: `final res = await api.get('/propriedades'); res.data` (JSON já decodificado).
final Dio api =
    Dio(
        BaseOptions(
          baseUrl: kApiUrl,
          connectTimeout: const Duration(seconds: 20),
        ),
      )
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final token = Storage.token;
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            handler.next(options);
          },
        ),
      );

/// Extrai a mensagem `error` (ou `message`) retornada pelo backend, como no React:
/// `isAxiosError(e) ? e.response?.data?.error : undefined`.
String? apiErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final msg = data['error'] ?? data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
  }
  return null;
}

int? apiStatus(Object error) =>
    error is DioException ? error.response?.statusCode : null;

/// Converte valores vindos do JSON (num, String ou null) em double.
double toDouble(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

double? toDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int toInt(dynamic v, [int fallback = 0]) => toIntOrNull(v) ?? fallback;

int? toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

/// Lista de mapas a partir de `res.data`.
List<Map<String, dynamic>> asList(dynamic data) => data is List
    ? data.map((e) => Map<String, dynamic>.from(e as Map)).toList()
    : <Map<String, dynamic>>[];

Map<String, dynamic> asMap(dynamic data) =>
    data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
