// lib/features/auth/auth_controller.dart
// Controlador de autenticación

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firebase_service.dart';
import '../../models/usuario.dart';

class AuthController extends ChangeNotifier {
  User? _user;
  Usuario? _perfil;
  bool _loading = true;

  User? get user => _user;
  Usuario? get perfil => _perfil;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;

  AuthController() {
    FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  void _onAuthChanged(User? user) async {
    _user = user;
    _loading = true;
    notifyListeners();

    if (user != null) {
      _perfil = await FirebaseService.getUsuario(user.uid);
    } else {
      _perfil = null;
    }

    _loading = false;
    notifyListeners();
  }

  void onLogin(User user) {
    _user = user;
    notifyListeners();
  }

  Future<void> registrarConductor({
    required String nombre,
    required String telefono,
    required TipoVehiculo vehiculo,
    String? patente,
    ZonaOperacion? zona,
    Disponibilidad? disponibilidad,
  }) async {
    if (_user == null) return;

    final usuario = Usuario(
      id: _user!.uid,
      nombre: nombre,
      telefono: telefono,
      tipo: TipoUsuario.conductor,
      tipoVehiculo: vehiculo,
      patente: patente,
      zona: zona,
      disponibilidad: disponibilidad,
      aprobado: false,
      enLinea: false,
      rating: 0,
      totalViajes: 0,
    );

    await FirebaseService.crearUsuario(usuario);
    _perfil = usuario;
    notifyListeners();
  }

  Future<void> registrarCliente({
    required String nombre,
    required String telefono,
  }) async {
    if (_user == null) return;

    final usuario = Usuario(
      id: _user!.uid,
      nombre: nombre,
      telefono: telefono,
      tipo: TipoUsuario.cliente,
      rating: 0,
      totalViajes: 0,
    );

    await FirebaseService.crearUsuario(usuario);
    _perfil = usuario;
    notifyListeners();
  }

  Future<void> toggleEnLinea() async {
    if (_user == null || _perfil == null) return;
    final nuevo = !(_perfil!.enLinea ?? false);
    await FirebaseService.actualizarUsuario(
      _user!.uid,
      {'enLinea': nuevo},
    );
    _perfil = _perfil!.copyWith(enLinea: nuevo);
    notifyListeners();
  }

  Future<void> signOut() async {
    await FirebaseService.signOut();
    _user = null;
    _perfil = null;
    notifyListeners();
  }
}