// lib/models/pricing.dart
// Cálculo de precios de flete

import 'tipo_vehiculo_viaje.dart';

class PricingConfig {
  // Base por vehículo
  static const Map<TipoVehiculoViaje, int> base = {
    TipoVehiculoViaje.camioneta: 8000,
    TipoVehiculoViaje.furgon: 12000,
    TipoVehiculoViaje.camion34: 18000,
  };

  // Por km adicional
  static const Map<TipoVehiculoViaje, int> porKm = {
    TipoVehiculoViaje.camioneta: 500,
    TipoVehiculoViaje.furgon: 700,
    TipoVehiculoViaje.camion34: 900,
  };

  // Comisión FleteGG
  static const double comisionPct = 0.15; // 15% (0% primeros 30 días piloto)
  static const double comisionPctPiloto = 0.0; // 0% piloto

  // Costo transacción Mercado Pago
  static const double mpPct = 0.03; // 3%
}

class PricingResult {
  final int precioTotal;
  final int base;
  final int costoDistancia;
  final int comision;
  final int conductorRecibe;
  final int costoTransaccion;

  PricingResult({
    required this.precioTotal,
    required this.base,
    required this.costoDistancia,
    required this.comision,
    required this.conductorRecibe,
    required this.costoTransaccion,
  });
}

class PricingService {
  static PricingResult calcular({
    required TipoVehiculoViaje vehiculo,
    required double distanciaKm,
    bool esPiloto = true,
  }) {
    final basePrice = PricingConfig.base[vehiculo]!;
    final kmPrice = PricingConfig.porKm[vehiculo]!;
    final costoDistancia = (distanciaKm * kmPrice).round();
    final precioTotal = basePrice + costoDistancia;
    final costoTransaccion = (precioTotal * PricingConfig.mpPct).round();
    final comisionPct = esPiloto
        ? PricingConfig.comisionPctPiloto
        : PricingConfig.comisionPct;
    final comision = (precioTotal * comisionPct).round();
    final conductorRecibe = precioTotal - comision - costoTransaccion;

    return PricingResult(
      precioTotal: precioTotal,
      base: basePrice,
      costoDistancia: costoDistancia,
      comision: comision,
      conductorRecibe: conductorRecibe,
      costoTransaccion: costoTransaccion,
    );
  }
}