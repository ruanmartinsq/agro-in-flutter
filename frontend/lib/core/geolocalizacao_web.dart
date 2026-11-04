// Implementação web de conexão (navigator.onLine) via dart:js_interop.
import 'dart:js_interop';

export 'gps.dart';

@JS('navigator.onLine')
external bool get _onLine;

@JS('window.addEventListener')
external void _addEventListener(String tipo, JSFunction f);

@JS('window.removeEventListener')
external void _removeEventListener(String tipo, JSFunction f);

/// `navigator.onLine`
bool get conectado => _onLine;

/// Escuta os eventos `online`/`offline`. Retorna a função que cancela a escuta.
void Function() ouvirConexao(void Function(bool online) aoMudar) {
  void atualizar(JSAny? _) => aoMudar(_onLine);
  final f = atualizar.toJS;
  _addEventListener('online', f);
  _addEventListener('offline', f);
  return () {
    _removeEventListener('online', f);
    _removeEventListener('offline', f);
  };
}
