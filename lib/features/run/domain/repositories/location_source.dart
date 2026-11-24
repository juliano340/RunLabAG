import 'package:geolocator/geolocator.dart';

/// Porta de localização usada pelo motor da corrida.
///
/// A UI e as regras de tracking não dependem do plugin ou da plataforma.
abstract interface class LocationSource {
  Future<bool> requestPermission();

  Future<Position> getCurrentLocation();

  Stream<Position> getLocationStream();
}
