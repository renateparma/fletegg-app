// lib/features/cliente/tracking_page.dart
// Tracking del viaje en tiempo real

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/colors.dart';
import '../../models/viaje.dart';

class TrackingPage extends StatefulWidget {
  final String viajeId;
  const TrackingPage({super.key, required this.viajeId});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  Viaje? _viaje;
  GoogleMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('viajes')
          .doc(widget.viajeId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        _viaje = Viaje.fromMap(snap.data!.data() as Map<String, dynamic>, snap.data!.id);

        return Scaffold(
          appBar: AppBar(title: Text(_estadoTitulo(_viaje!.estado))),
          body: Column(
            children: [
              // Mapa
              SizedBox(
                height: 300,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_viaje!.origenLat, _viaje!.origenLng),
                    zoom: 12,
                  ),
                  onMapCreated: (c) => _mapController = c,
                  markers: _markers(),
                  polylines: _polyline(),
                  myLocationEnabled: true,
                ),
              ),
              // Info
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Estado
                    _estadoCard(),
                    const SizedBox(height: 16),

                    // Conductor
                    if (_viaje!.conductorId != null) _conductorCard(),

                    // Detalles
                    const SizedBox(height: 16),
                    _detallesCard(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Set<Marker> _markers() {
    final markers = <Marker>{};
    markers.add(Marker(
      markerId: const MarkerId('origen'),
      position: LatLng(_viaje!.origenLat, _viaje!.origenLng),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(title: 'Origen: ${_viaje!.origenDireccion}'),
    ));
    markers.add(Marker(
      markerId: const MarkerId('destino'),
      position: LatLng(_viaje!.destinoLat, _viaje!.destinoLng),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      infoWindow: InfoWindow(title: 'Destino: ${_viaje!.destinoDireccion}'),
    ));
    return markers;
  }

  Set<Polyline> _polyline() {
    return {
      Polyline(
        polylineId: const PolylineId('ruta'),
        points: [
          LatLng(_viaje!.origenLat, _viaje!.origenLng),
          LatLng(_viaje!.destinoLat, _viaje!.destinoLng),
        ],
        color: FleteGGColors.primary,
        width: 4,
        patterns: [PatternItem.dash(8), PatternItem.gap(4)],
      ),
    };
  }

  Widget _estadoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _estadoStep('Flete confirmado', _viaje!.estado.index >= 0),
            _estadoStep('Conductor en camino', _viaje!.estado.index >= 1),
            _estadoStep('Carga en camino al destino', _viaje!.estado.index >= 3),
            _estadoStep('Viaje completado', _viaje!.estado.index >= 4),
          ],
        ),
      ),
    );
  }

  Widget _estadoStep(String texto, bool done) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? FleteGGColors.success : Colors.grey,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(texto, style: TextStyle(
            color: done ? Colors.white : Colors.grey,
            fontWeight: done ? FontWeight.w600 : FontWeight.normal,
          )),
        ],
      ),
    );
  }

  Widget _conductorCard() {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(backgroundColor: FleteGGColors.primary, child: Icon(Icons.person, color: Colors.white)),
        title: Text(_viaje!.conductorNombre ?? 'Conductor'),
        subtitle: Text('★ ${(85).toStringAsFixed(1)} · ${_vehiculoLabel()}'),
        trailing: IconButton(icon: const Icon(Icons.phone), onPressed: () {}),
      ),
    );
  }

  Widget _detallesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Detalles', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Distancia'),
                Text('${_viaje!.distanciaKm.toStringAsFixed(1)} km'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tiempo estimado'),
                Text('~${_viaje!.tiempoEstimadoMin} min'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Carga'),
                Text(_viaje!.descripcionCarga),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('\$${_viaje!.precioTotal}', style: const TextStyle(fontWeight: FontWeight.bold, color: FleteGGColors.primary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _estadoTitulo(EstadoViaje e) {
    switch (e) {
      case EstadoViaje.pendiente:
        return 'Buscando conductor...';
      case EstadoViaje.asignado:
        return 'Conductor en camino';
      case EstadoViaje.enOrigen:
        return 'Conductor en el origen';
      case EstadoViaje.enCamino:
        return 'Carga en camino';
      case EstadoViaje.completado:
        return 'Viaje completado';
      case EstadoViaje.cancelado:
        return 'Viaje cancelado';
    }
  }

  String _vehiculoLabel() {
    switch (_viaje!.vehiculoRequerido) {
      case TipoVehiculoViaje.camioneta:
        return 'Camioneta';
      case TipoVehiculoViaje.furgon:
        return 'Furgón cerrado';
      case TipoVehiculoViaje.camion34:
        return 'Camión 3/4';
    }
  }
}