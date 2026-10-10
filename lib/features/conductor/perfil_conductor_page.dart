// lib/features/conductor/perfil_conductor_page.dart
// Perfil del conductor

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/colors.dart';
import '../auth/auth_controller.dart';

class PerfilConductorPage extends StatelessWidget {
  const PerfilConductorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final p = auth.perfil;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: FleteGGColors.primary,
            child: Text(
              p?.nombre.isNotEmpty == true ? p!.nombre[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 32, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Center(child: Text(p?.nombre ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
          Center(child: Text(p?.telefono ?? '', style: const TextStyle(color: Colors.grey))),
          const SizedBox(height: 24),

          // Stats
          Row(
            children: [
              _stat('${p?.rating?.toStringAsFixed(1) ?? '0.0'}', 'Rating'),
              _stat('${p?.totalViajes ?? 0}', 'Viajes'),
              _stat(_vehiculoLabel(p?.tipoVehiculo), 'Vehículo'),
            ],
          ),
          const SizedBox(height: 24),

          // Detalles
          _infoRow('Patente', p?.patente ?? 'No registrada'),
          _infoRow('Zona', _zonaLabel(p?.zona)),
          _infoRow('Disponibilidad', _dispLabel(p?.disponibilidad)),
          _infoRow('Estado', p?.aprobado == true ? 'Aprobado ✅' : 'En revisión ⏳'),

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => auth.signOut(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('CERRAR SESIÓN'),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: FleteGGColors.primary)),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _vehiculoLabel(TipoVehiculo? v) {
    switch (v) {
      case TipoVehiculo.camion34: return 'Camión 3/4';
      case TipoVehiculo.furgon: return 'Furgón';
      case TipoVehiculo.camioneta: return 'Camioneta';
      case TipoVehiculo.varios: return 'Varios';
      default: return '-';
    }
  }

  String _zonaLabel(ZonaOperacion? z) {
    switch (z) {
      case ZonaOperacion.centro: return 'Santiago Centro';
      case ZonaOperacion.oriente: return 'Oriente';
      case ZonaOperacion.sur: return 'Sur';
      case ZonaOperacion.norte: return 'Norte';
      case ZonaOperacion.poniente: return 'Poniente';
      case ZonaOperacion.todaRm: return 'Toda la RM';
      default: return 'No especificada';
    }
  }

  String _dispLabel(Disponibilidad? d) {
    switch (d) {
      case Disponibilidad.fullTime: return 'Tiempo completo';
      case Disponibilidad.finesSemana: return 'Fines de semana';
      case Disponibilidad.eventos: return 'Solo eventos';
      case Disponibilidad.flexible: return 'Flexible';
      default: return 'No especificada';
    }
  }
}