// Fora do navegador: status de conexão sempre online. GPS vem de gps.dart (geolocator).
// Use via import condicional:
// import '../core/geolocalizacao_stub.dart' if (dart.library.js_interop) '../core/geolocalizacao_web.dart';

export 'gps.dart';

/// `navigator.onLine`
bool get conectado => true;

/// Escuta os eventos `online`/`offline`. Retorna a função que cancela a escuta.
void Function() ouvirConexao(void Function(bool online) aoMudar) => () {};
