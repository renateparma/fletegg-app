// lib/models/viaje.dart
// Modelo de viaje (flete)

enum EstadoViaje {
  pendiente,      // Buscando conductor
  asignado,       // Conductor aceptó, yendo al origen
  enOrigen,       // Conductor llegó al origen
  enCamino,       // Carga recogida, yendo al destino
  completado,     // Entregado
  cancelado,      // Cancelado por cliente o conductor
}

enum TipoVehiculoViaje { camioneta, furgon, camion34 }

class Viaje {
  final String id;
  final String clienteId;
  final String clienteNombre;
  final String? conductorId;
  final String? conductorNombre;
  /// Rating del conductor al momento de aceptar (null = conductor nuevo)
  final double? conductorRating;

  // Origen
  final String origenDireccion;
  final double origenLat;
  final double origenLng;

  // Destino
  final String destinoDireccion;
  final double destinoLat;
  final double destinoLng;

  // Detalles
  final TipoVehiculoViaje vehiculoRequerido;
  final String descripcionCarga;
  final double distanciaKm;
  final int tiempoEstimadoMin;

  // Pricing
  final int precioTotal;
  final int comision;
  final int conductorRecibe;

  // Estado
  final EstadoViaje estado;
  final DateTime createdAt;
  final DateTime? aceptadoAt;
  final DateTime? completadoAt;

  // Rating
  final int? ratingCliente;
  final int? ratingConductor;

  Viaje({
    required this.id,
    required this.clienteId,
    required this.clienteNombre,
    this.conductorId,
    this.conductorNombre,
    this.conductorRating,
    required this.origenDireccion,
    required this.origenLat,
    required this.origenLng,
    required this.destinoDireccion,
    required this.destinoLat,
    required this.destinoLng,
    required this.vehiculoRequerido,
    required this.descripcionCarga,
    required this.distanciaKm,
    required this.tiempoEstimadoMin,
    required this.precioTotal,
    required this.comision,
    required this.conductorRecibe,
    required this.estado,
    required this.createdAt,
    this.aceptadoAt,
    this.completadoAt,
    this.ratingCliente,
    this.ratingConductor,
  });

  factory Viaje.fromMap(Map<String, dynamic> map, String id) {
    return Viaje(
      id: id,
      clienteId: map['clienteId'] ?? '',
      clienteNombre: map['clienteNombre'] ?? '',
      conductorId: map['conductorId'],
      conductorNombre: map['conductorNombre'],
      conductorRating: (map['conductorRating'] as num?)?.toDouble(),
      origenDireccion: map['origenDireccion'] ?? '',
      origenLat: (map['origenLat'] ?? 0).toDouble(),
      origenLng: (map['origenLng'] ?? 0).toDouble(),
      destinoDireccion: map['destinoDireccion'] ?? '',
      destinoLat: (map['destinoLat'] ?? 0).toDouble(),
      destinoLng: (map['destinoLng'] ?? 0).toDouble(),
      vehiculoRequerido: TipoVehiculoViaje.values.firstWhere(
        (e) => e.name == map['vehiculoRequerido'],
        orElse: () => TipoVehiculoViaje.camion34,
      ),
      descripcionCarga: map['descripcionCarga'] ?? '',
      distanciaKm: (map['distanciaKm'] ?? 0).toDouble(),
      tiempoEstimadoMin: map['tiempoEstimadoMin'] ?? 0,
      precioTotal: map['precioTotal'] ?? 0,
      comision: map['comision'] ?? 0,
      conductorRecibe: map['conductorRecibe'] ?? 0,
      estado: EstadoViaje.values.firstWhere(
        (e) => e.name == map['estado'],
        orElse: () => EstadoViaje.pendiente,
      ),
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      aceptadoAt: (map['aceptadoAt'] as dynamic)?.toDate(),
      completadoAt: (map['completadoAt'] as dynamic)?.toDate(),
      ratingCliente: map['ratingCliente']?.toInt(),
      ratingConductor: map['ratingConductor']?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clienteId': clienteId,
      'clienteNombre': clienteNombre,
      if (conductorId != null) 'conductorId': conductorId,
      if (conductorNombre != null) 'conductorNombre': conductorNombre,
      if (conductorRating != null) 'conductorRating': conductorRating,
      'origenDireccion': origenDireccion,
      'origenLat': origenLat,
      'origenLng': origenLng,
      'destinoDireccion': destinoDireccion,
      'destinoLat': destinoLat,
      'destinoLng': destinoLng,
      'vehiculoRequerido': vehiculoRequerido.name,
      'descripcionCarga': descripcionCarga,
      'distanciaKm': distanciaKm,
      'tiempoEstimadoMin': tiempoEstimadoMin,
      'precioTotal': precioTotal,
      'comision': comision,
      'conductorRecibe': conductorRecibe,
      'estado': estado.name,
      'createdAt': createdAt,
      if (aceptadoAt != null) 'aceptadoAt': aceptadoAt,
      if (completadoAt != null) 'completadoAt': completadoAt,
      if (ratingCliente != null) 'ratingCliente': ratingCliente,
      if (ratingConductor != null) 'ratingConductor': ratingConductor,
    };
  }
}