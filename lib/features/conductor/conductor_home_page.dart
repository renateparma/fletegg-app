// lib/features/conductor/conductor_home_page.dart
// Home del conductor — ver viajes disponibles + ganancias

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../theme/colors.dart';
import '../../services/firebase_service.dart';
import '../../models/viaje.dart';
import '../../models/usuario.dart';
import '../../utils/formato.dart';
import '../auth/auth_controller.dart';
import 'ganancias_page.dart';
import 'perfil_conductor_page.dart';

class ConductorHomePage extends StatefulWidget {
  const ConductorHomePage({super.key});

  @override
  State<ConductorHomePage> createState() => _ConductorHomePageState();
}

class _ConductorHomePageState extends State<ConductorHomePage> {
  int _tabIndex = 0;
  LatLng? _miUbicacion;

  @override
  void initState() {
    super.initState();
    _obtenerUbicacion();
  }

  Future<void> _obtenerUbicacion() async {
    final pos = await Geolocator.getCurrentPosition();
    final ubicacion = LatLng(pos.latitude, pos.longitude);
    if (!mounted) return;
    setState(() => _miUbicacion = ubicacion);

    // Publicar la ubicación para que los clientes puedan ver conductores
    // cercanos (streamConductoresEnLinea filtra por radio con lat/lng).
    final uid = context.read<AuthController>().user?.uid;
    if (uid != null) {
      FirebaseService.actualizarUbicacionConductor(uid, ubicacion)
          .catchError((Object e) => debugPrint('No pude guardar ubicación: $e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final perfil = auth.perfil;

    if (perfil?.aprobado == false) {
      return _noAprobado(context);
    }

    return Scaffold(
      body: _tabIndex == 0
          ? _viajesDisponibles(context, auth)
          : _tabIndex == 1
              ? const GananciasPage()
              : const PerfilConductorPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.local_shipping), label: 'Viajes'),
          NavigationDestination(icon: Icon(Icons.payments), label: 'Ganancias'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }

  Widget _noAprobado(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_top, size: 80, color: FleteGGColors.primary),
              const SizedBox(height: 24),
              const Text('Afiliación en revisión', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const Text(
                'Te contactaremos por WhatsApp para activar tu cuenta. Esto suele tomar menos de 24 horas.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.read<AuthController>().signOut(),
                child: const Text('SALIR'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _viajesDisponibles(BuildContext context, AuthController auth) {
    final perfil = auth.perfil!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FleteGG Conductor'),
        actions: [
          Switch(
            value: perfil.enLinea ?? false,
            activeThumbColor: FleteGGColors.success,
            onChanged: (_) => auth.toggleEnLinea(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats del día
          Container(
            padding: const EdgeInsets.all(16),
            color: FleteGGColors.surface,
            child: Row(
              children: [
                _statCard('\$0', 'HOY'),
                _statCard('0', 'VIAJES'),
                _statCard('${perfil.rating?.toStringAsFixed(1) ?? '0.0'}', 'RATING'),
              ],
            ),
          ),
          // Viajes disponibles
          Expanded(
            child: (perfil.enLinea ?? false)
                ? _streamViajes(perfil)
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.power_settings_new, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Estás offline', style: TextStyle(fontSize: 18, color: Colors.grey)),
                        Text('Activa el switch para recibir viajes', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _streamViajes(Usuario perfil) {
    if (_miUbicacion == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final vehiculo = _mapVehiculo(perfil.tipoVehiculo);

    return StreamBuilder<List<Viaje>>(
      stream: FirebaseService.streamViajesPendientes(
        lat: _miUbicacion!.latitude,
        lng: _miUbicacion!.longitude,
        vehiculo: vehiculo,
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final viajes = snap.data ?? [];

        if (viajes.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No hay viajes cerca', style: TextStyle(fontSize: 18, color: Colors.grey)),
                Text('Mantente en línea — los viajes llegan solos', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: viajes.length,
          itemBuilder: (context, i) => _viajeCard(context, viajes[i]),
        );
      },
    );
  }

  Widget _viajeCard(BuildContext context, Viaje viaje) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(child: Text(viaje.origenDireccion, style: const TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(left: 23),
              child: Icon(Icons.arrow_downward, size: 16, color: Colors.grey),
            ),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: FleteGGColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(viaje.destinoDireccion, style: const TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
            const SizedBox(height: 12),
            Text(viaje.descripcionCarga, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(fmtClp(viaje.precioTotal), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: FleteGGColors.primary)),
                Text('${viaje.distanciaKm.toStringAsFixed(1)} km · ~${viaje.tiempoEstimadoMin} min', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _aceptarViaje(viaje),
                    style: ElevatedButton.styleFrom(backgroundColor: FleteGGColors.success),
                    child: const Text('ACEPTAR'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {},
                  child: const Text('Rechazar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _aceptarViaje(Viaje viaje) async {
    final auth = context.read<AuthController>();
    final rating = auth.perfil!.rating ?? 0;
    await FirebaseService.actualizarViaje(viaje.id, {
      'conductorId': auth.user!.uid,
      'conductorNombre': auth.perfil!.nombre,
      // Sin rating (conductor nuevo) se omite: el cliente ve "Nuevo"
      if (rating > 0) 'conductorRating': rating,
      'estado': EstadoViaje.asignado.name,
      'aceptadoAt': DateTime.now(),
    });
  }

  Widget _statCard(String value, String label) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: FleteGGColors.primary)),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  TipoVehiculoViaje _mapVehiculo(TipoVehiculo? v) {
    switch (v) {
      case TipoVehiculo.camion34:
        return TipoVehiculoViaje.camion34;
      case TipoVehiculo.furgon:
        return TipoVehiculoViaje.furgon;
      case TipoVehiculo.camioneta:
        return TipoVehiculoViaje.camioneta;
      default:
        return TipoVehiculoViaje.camion34;
    }
  }
}