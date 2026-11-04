import 'package:geolocator/geolocator.dart';

/// GPS em todas as plataformas (web, Android, iOS, Windows) via geolocator.
/// Equivale a `navigator.geolocation.getCurrentPosition(..., { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 })`.
class PosicaoGps {
  const PosicaoGps(this.latitude, this.longitude, this.precisao);
  final double latitude;
  final double longitude;
  final double precisao;
}

/// Lançada por [obterPosicaoGps]. [indisponivel] = dispositivo sem serviço de localização.
class GpsException implements Exception {
  const GpsException({this.indisponivel = false});
  final bool indisponivel;
}

Future<PosicaoGps> obterPosicaoGps() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const GpsException(indisponivel: true);
    }
    var permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }
    if (permissao == LocationPermission.denied ||
        permissao == LocationPermission.deniedForever) {
      throw const GpsException();
    }
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return PosicaoGps(p.latitude, p.longitude, p.accuracy);
  } on GpsException {
    rethrow;
  } catch (_) {
    throw const GpsException();
  }
}
