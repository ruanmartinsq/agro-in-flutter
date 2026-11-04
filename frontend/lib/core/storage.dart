import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Substitui o `localStorage` do navegador. Inicialize com [Storage.init] no main().
class Storage {
  Storage._();
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String? get token => _prefs.getString('token');
  static Future<void> setToken(String token) =>
      _prefs.setString('token', token);
  static Future<void> clearToken() => _prefs.remove('token');

  static String? getString(String key) => _prefs.getString(key);
  static Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
  static Future<void> remove(String key) => _prefs.remove(key);

  /// Equivalente ao hook useLocalStorage do React: grava um "envelope"
  /// `{v, savedAt, data}` com versão e TTL opcional; nunca lança exceção.
  static T readEnvelope<T>(
    String key,
    T fallback, {
    int version = 1,
    Duration? ttl,
    T Function(dynamic raw)? fromJson,
  }) {
    try {
      final raw = _prefs.getString(key);
      if (raw == null || raw.isEmpty) return fallback;
      final env = jsonDecode(raw);
      if (env is! Map || env['v'] != version) return fallback;
      if (ttl != null) {
        final savedAt = (env['savedAt'] as num?)?.toInt() ?? 0;
        if (DateTime.now().millisecondsSinceEpoch - savedAt >
            ttl.inMilliseconds) {
          return fallback;
        }
      }
      final data = env['data'];
      return fromJson != null ? fromJson(data) : data as T;
    } catch (_) {
      return fallback;
    }
  }

  static Future<void> writeEnvelope(
    String key,
    dynamic data, {
    int version = 1,
  }) async {
    try {
      await _prefs.setString(
        key,
        jsonEncode({
          'v': version,
          'savedAt': DateTime.now().millisecondsSinceEpoch,
          'data': data,
        }),
      );
    } catch (_) {
      // Não derruba a UI se não conseguir persistir.
    }
  }

  static Future<void> removeEnvelope(String key) async {
    try {
      await _prefs.remove(key);
    } catch (_) {}
  }
}
