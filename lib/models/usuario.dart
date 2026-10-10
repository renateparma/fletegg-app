// lib/models/usuario.dart
// Modelo de usuario (conductor o cliente)

enum TipoUsuario { conductor, cliente, admin }

enum TipoVehiculo { camion34, furgon, camioneta, varios }

enum ZonaOperacion { centro, oriente, sur, norte, poniente, todaRm }

enum Disponibilidad { fullTime, finesSemana, eventos, flexible }

class Usuario {
  final String id;
  final String nombre;
  final String telefono;
  final TipoUsuario tipo;
  final double? rating;
  final int? totalViajes;

  // Solo conductor
  final TipoVehiculo? tipoVehiculo;
  final String? patente;
  final ZonaOperacion? zona;
  final Disponibilidad? disponibilidad;
  final bool? aprobado;
  final bool? enLinea;

  Usuario({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.tipo,
    this.rating,
    this.totalViajes,
    this.tipoVehiculo,
    this.patente,
    this.zona,
    this.disponibilidad,
    this.aprobado,
    this.enLinea,
  });

  factory Usuario.fromMap(Map<String, dynamic> map, String id) {
    return Usuario(
      id: id,
      nombre: map['nombre'] ?? '',
      telefono: map['telefono'] ?? '',
      tipo: TipoUsuario.values.firstWhere(
        (e) => e.name == map['tipo'],
        orElse: () => TipoUsuario.cliente,
      ),
      rating: (map['rating'] ?? 0).toDouble(),
      totalViajes: map['totalViajes'] ?? 0,
      tipoVehiculo: map['tipoVehiculo'] != null
          ? TipoVehiculo.values.firstWhere(
              (e) => e.name == map['tipoVehiculo'],
              orElse: () => TipoVehiculo.camion34,
            )
          : null,
      patente: map['patente'],
      zona: map['zona'] != null
          ? ZonaOperacion.values.firstWhere(
              (e) => e.name == map['zona'],
              orElse: () => ZonaOperacion.todaRm,
            )
          : null,
      disponibilidad: map['disponibilidad'] != null
          ? Disponibilidad.values.firstWhere(
              (e) => e.name == map['disponibilidad'],
              orElse: () => Disponibilidad.flexible,
            )
          : null,
      aprobado: map['aprobado'] ?? false,
      enLinea: map['enLinea'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'telefono': telefono,
      'tipo': tipo.name,
      'rating': rating ?? 0,
      'totalViajes': totalViajes ?? 0,
      if (tipoVehiculo != null) 'tipoVehiculo': tipoVehiculo!.name,
      if (patente != null) 'patente': patente,
      if (zona != null) 'zona': zona!.name,
      if (disponibilidad != null) 'disponibilidad': disponibilidad!.name,
      'aprobado': aprobado ?? false,
      'enLinea': enLinea ?? false,
    };
  }
}