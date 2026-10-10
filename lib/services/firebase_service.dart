// lib/services/firebase_service.dart
// Servicio de Firebase — auth, firestore, storage

import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/usuario.dart';
import '../models/viaje.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // === AUTH ===

  static User? get currentUser => _auth.currentUser;

  static String? _verificationId;

  static Future<String> enviarCodigo(String telefono) async {
    String? verId;
    await _auth.verifyPhoneNumber(
      phoneNumber: telefono,
      verificationCompleted: (_) {},
      verificationFailed: (e) {
        throw Exception(e.message);
      },
      codeSent: (id, __) {
        verId = id;
        _verificationId = id;
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    // Esperar un momento para que codeSent se ejecute
    await Future.delayed(const Duration(seconds: 1));
    return _verificationId ?? verId ?? '';
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
        final dist = _distanciaKm(lat, lng, v.origenLat, v.origenLng);
        return dist <= radioKm;
      }).toList();
      viajes.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return viajes;
    });
  }

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
      return snap.docs
          .map((doc) => Usuario.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // === HELPERS ===

  static double _distanciaKm(
    double lat1, double lng1, double lat2, double lng2,
  ) {
    const double r = 6371;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.asin(math.sqrt(a));
    return r * c;
  }

  static double _toRad(double deg) => deg * math.pi / 180.0;
}