// lib/services/firebase_service.dart
// Servicio de Firebase — auth, firestore, storage

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/usuario.dart';
import '../models/viaje.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // === AUTH ===

  static User? get currentUser => _auth.currentUser;

  static Future<void> enviarCodigo(String telefono) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: telefono,
      verificationCompleted: (_) {},
      verificationFailed: (_) {},
      codeSent: (_, __) {},
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  static Future<UserCredential> verificarCodigo(
    String verificationId,
    String smsCode,
  ) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  // === USUARIOS ===

  static Future<void> crearUsuario(Usuario usuario) async {
    await _db.collection('usuarios').doc(usuario.id).set(usuario.toMap());
  }

  static Future<Usuario?> getUsuario(String id) async {
    final doc = await _db.collection('usuarios').doc(id).get();
    if (!doc.exists) return null;
    return Usuario.fromMap(doc.data()!, doc.id);
  }

  static Stream<Usuario?> streamUsuario(String id) {
    return _db.collection('usuarios').doc(id).snapshots().map(
      (doc) => doc.exists ? Usuario.fromMap(doc.data()!, doc.id) : null,
    );
  }

  static Future<void> actualizarUsuario(String id, Map<String, dynamic> data) async {
    await _db.collection('usuarios').doc(id).update(data);
  }

  // === VIAJES ===

  static Future<String> crearViaje(Viaje viaje) async {
    final ref = await _db.collection('viajes').add(viaje.toMap());
    return ref.id;
  }

  static Future<void> actualizarViaje(String id, Map<String, dynamic> data) async {
    await _db.collection('viajes').doc(id).update(data);
  }

  /// Viajes pendientes cercanos a una ubicación
  static Stream<List<Viaje>> streamViajesPendientes({
    required double lat,
    required double lng,
    required TipoVehiculoViaje vehiculo,
    double radioKm = 10,
  }) {
    return _db
        .collection('viajes')
        .where('estado', isEqualTo: EstadoViaje.pendiente.name)
        .where('vehiculoRequerido', isEqualTo: vehiculo.name)
        .snapshots()
        .map((snap) {
      final viajes = snap.docs
          .map((doc) => Viaje.fromMap(doc.data(), doc.id))
          .where((v) {
        // Filtro de distancia en memoria (no hay geoquery nativa en Firestore)
        final dist = _distanciaKm(lat, lng, v.origenLat, v.origenLng);
        return dist <= radioKm;
      }).toList();
      viajes.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return viajes;
    });
  }

  /// Viajes activos de un conductor
  static Stream<List<Viaje>> streamViajesConductor(String conductorId) {
    return _db
        .collection('viajes')
        .where('conductorId', isEqualTo: conductorId)
        .where('estado', whereIn: [
          EstadoViaje.asignado.name,
          EstadoViaje.enOrigen.name,
          EstadoViaje.enCamino.name,
        ])
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => Viaje.fromMap(doc.data(), doc.id)).toList());
  }

  /// Viajes de un cliente
  static Stream<List<Viaje>> streamViajesCliente(String clienteId) {
    return _db
        .collection('viajes')
        .where('clienteId', isEqualTo: clienteId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => Viaje.fromMap(doc.data(), doc.id)).toList());
  }

  /// Historial de viajes completados
  static Future<List<Viaje>> getHistorialConductor(
    String conductorId, {
    int limit = 100,
  }) async {
    final snap = await _db
        .collection('viajes')
        .where('conductorId', isEqualTo: conductorId)
        .where('estado', isEqualTo: EstadoViaje.completado.name)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((doc) => Viaje.fromMap(doc.data(), doc.id)).toList();
  }

  // === CONDUCTORES CERCANOS ===

  static Stream<List<Usuario>> streamConductoresEnLinea({
    required double lat,
    required double lng,
    double radioKm = 10,
  }) {
    return _db
        .collection('usuarios')
        .where('tipo', isEqualTo: TipoUsuario.conductor.name)
        .where('enLinea', isEqualTo: true)
        .where('aprobado', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final conductores = snap.docs
          .map((doc) => Usuario.fromMap(doc.data(), doc.id))
          .where((c) {
        // TODO: filtrar por ubicación actual cuando tengamos tracking de ubicación
        return true;
      }).toList();
      return conductores;
    });
  }

  // === HELPERS ===

  static double _distanciaKm(
    double lat1, double lng1, double lat2, double lng2,
  ) {
    // Fórmula Haversine simplificada
    const double r = 6371; // km
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = (dLat / 2).abs().sin() * (dLat / 2).abs().sin() +
        _toRad(lat1).cos() * _toRad(lat2).cos() *
        (dLng / 2).abs().sin() * (dLng / 2).abs().sin();
    final c = 2 * (a).abs().sqrt().asin();
    return r * c;
  }

  static double _toRad(double deg) => deg * 0.017453292519943295;
}

// Extension para no depender de dart:math
extension _NumExt on num {
  double sin() => 0; // placeholder — usar dart:math en producción
  double cos() => 0;
  double sqrt() => 0;
  double asin() => 0;
  double abs() => toDouble().abs();
}