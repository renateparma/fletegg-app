// lib/services/maps_service.dart
// Google Maps — geocoding, routing, distancia

import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config/maps_config.dart';
import 'package:geocoding/geocoding.dart';

class MapsService {
  static const String apiKey = MapsConfig.apiKey;

  /// Geocoding: dirección → coordenadas
  static Future<LatLng> geocode(String direccion) async {
    final locations = await locationFromAddress('$direccion, Santiago, Chile');
    if (locations.isEmpty) {
      throw Exception('Dirección no encontrada: $direccion');
    }
    return LatLng(locations.first.latitude, locations.first.longitude);
  }

  /// Distancia entre dos puntos en km (Haversine)
  static double distanciaKm(LatLng a, LatLng b) {
    const double r = 6371;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLng = _toRad(b.longitude - a.longitude);
    final lat1 = _toRad(a.latitude);
    final lat2 = _toRad(b.latitude);
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * asin(sqrt(h));
    return r * c;
  }

  /// Tiempo estimado de viaje en minutos (aproximación)
  /// A 30 km/h promedio en ciudad + 5 min de carga/descarga
  static int tiempoEstimadoMin(double distanciaKm) {
    final horas = distanciaKm / 30;
    return (horas * 60).round() + 5;
  }

  /// Bounds para mostrar origen y destino en el mapa
  static LatLngBounds bounds(LatLng a, LatLng b) {
    final southwest = LatLng(
      min(a.latitude, b.latitude),
      min(a.longitude, b.longitude),
    );
    final northeast = LatLng(
      max(a.latitude, b.latitude),
      max(a.longitude, b.longitude),
    );
    return LatLngBounds(southwest: southwest, northeast: northeast);
  }

  static double _toRad(double deg) => deg * pi / 180;
}