// lib/features/conductor/ganancias_page.dart
// Ganancias del conductor

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/colors.dart';
import '../../services/firebase_service.dart';
import '../../models/viaje.dart';
import '../auth/auth_controller.dart';

class GananciasPage extends StatelessWidget {
  const GananciasPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Ganancias')),
      body: FutureBuilder<List<Viaje>>(
        future: FirebaseService.getHistorialConductor(auth.user!.uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final viajes = snap.data ?? [];

          // Calcular totales
          int totalHoy = 0;
          int totalSemana = 0;
          int totalMes = 0;
          final hoy = DateTime.now();
          final semanaAtras = hoy.subtract(const Duration(days: 7));
          final mesAtras = hoy.subtract(const Duration(days: 30));

          for (final v in viajes) {
            if (v.completadoAt == null) continue;
            final monto = v.conductorRecibe;
            if (v.completadoAt!.isAfter(hoy.subtract(const Duration(hours: 24)))) {
              totalHoy += monto;
            }
            if (v.completadoAt!.isAfter(semanaAtras)) {
              totalSemana += monto;
            }
            if (v.completadoAt!.isAfter(mesAtras)) {
              totalMes += monto;
            }
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _bigCard('\$${_fmt(totalHoy)}', 'Hoy', FleteGGColors.primary),
              const SizedBox(height: 12),
              _bigCard('\$${_fmt(totalSemana)}', 'Últimos 7 días', Colors.blue),
              const SizedBox(height: 12),
              _bigCard('\$${_fmt(totalMes)}', 'Últimos 30 días', Colors.green),
              const SizedBox(height: 24),
              const Text('Viajes completados', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...viajes.take(20).map((v) => ListTile(
                leading: const Icon(Icons.check_circle, color: FleteGGColors.success, size: 20),
                title: Text('${v.origenDireccion} → ${v.destinoDireccion}'),
                subtitle: Text(v.completadoAt != null
                    ? '${v.completadoAt!.day}/${v.completadoAt!.month}/${v.completadoAt!.year}'
                    : ''),
                trailing: Text('\$${v.conductorRecibe}', style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
              if (viajes.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('Aún no tienes viajes completados', style: TextStyle(color: Colors.grey)),
                )),
            ],
          );
        },
      ),
    );
  }

  Widget _bigCard(String monto, String label, Color color) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: [color.withAlpha(20), color.withAlpha(5)]),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 16)),
            Text(monto, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }

  String _fmt(int n) => n.toString().replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), '.');
}