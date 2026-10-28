// lib/services/firebase_service.dart
// Servicio de Firebase — auth, firestore, storage

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/usuario.dart';
import '../models/viaje.dart';
import 'maps_service.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // === AUTH ===

  static User? get currentUser => _auth.currentUser;

  /// Envía el SMS y resuelve con el `verificationId` cuando Firebase confirma
  /// el envío (`codeSent`). Falla con la causa real si `verificationFailed`.
  static Future<String> enviarCodigo(String telefono) {
    final completer = Completer<String>();

    _auth.verifyPhoneNumber(
      phoneNumber: telefono,
      verificationCompleted: (credential) async {
        // Android puede verificar solo (auto-retrieval / instant verification)
        // antes de que llegue codeSent. Iniciamos sesión y resolvemos para que
        // la UI no se quede esperando; AuthController detecta el login.
        try {
          await _auth.signInWithCredential(credential);
          if (!completer.isCompleted) {
            completer.complete(credential.verificationId ?? '');
          }
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) {
          completer.completeError(Exception(e.message ?? e.code));
        }
      },
      codeSent: (verificationId, _) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (_) {},
    ).catchError((Object e) {
      // Errores síncronos del plugin (p. ej. número mal formado)
      if (!completer.isCompleted) completer.completeError(e);
    });

    return completer.future;
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
      final aqui = LatLng(lat, lng);
      final viajes = snap.docs
          .map((doc) => Viaje.fromMap(doc.data(), doc.id))
          .where((v) {
        final dist = MapsService.distanciaKm(
          aqui,
          LatLng(v.origenLat, v.origenLng),
        );
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

  /// Guarda la última ubicación conocida del conductor (campos `lat`/`lng`),
  /// necesaria para que [streamConductoresEnLinea] pueda filtrar por radio.
  static Future<void> actualizarUbicacionConductor(
    String id,
    LatLng posicion,
  ) async {
    await _db.collection('usuarios').doc(id).update({
      'lat': posicion.latitude,
      'lng': posicion.longitude,
      'ubicacionAt': FieldValue.serverTimestamp(),
    });
  }

  /// Conductores aprobados y en línea dentro de [radioKm] de (lat, lng).
  /// Los conductores sin ubicación reportada quedan fuera.
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
      final aqui = LatLng(lat, lng);
      return snap.docs
          .map((doc) => Usuario.fromMap(doc.data(), doc.id))
          .where((u) {
        if (u.lat == null || u.lng == null) return false;
        final dist = MapsService.distanciaKm(aqui, LatLng(u.lat!, u.lng!));
        return dist <= radioKm;
      }).toList();
    });
  }
}