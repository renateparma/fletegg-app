// lib/features/cliente/pedir_flete_page.dart
// Cliente pide flete — origen, destino, vehículo, precio

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../theme/colors.dart';
import '../../services/firebase_service.dart';
import '../../services/maps_service.dart';
import '../../models/viaje.dart';
import '../../models/pricing.dart';
import '../../utils/formato.dart';
import '../auth/auth_controller.dart';
import 'tracking_page.dart';

class PedirFletePage extends StatefulWidget {
  const PedirFletePage({super.key});

  @override
  State<PedirFletePage> createState() => _PedirFletePageState();
}

class _PedirFletePageState extends State<PedirFletePage> {
  final _origenCtrl = TextEditingController();
  final _destinoCtrl = TextEditingController();
  final _cargaCtrl = TextEditingController();
  TipoVehiculoViaje _vehiculo = TipoVehiculoViaje.camion34;
  LatLng? _origen;
  LatLng? _destino;
  double? _distancia;
  PricingResult? _precio;
  bool _calculando = false;
  bool _confirmando = false;

  @override
  void dispose() {
    _origenCtrl.dispose();
    _destinoCtrl.dispose();
    _cargaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pedir flete')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Origen
            TextField(
              controller: _origenCtrl,
              decoration: const InputDecoration(
                labelText: 'Origen',
                hintText: 'Ej: Vega Central, Renca',
                prefixIcon: Icon(Icons.my_location, color: Colors.green),
              ),
              onChanged: (_) => _origen = null,
            ),
            const SizedBox(height: 12),

            // Destino
            TextField(
              controller: _destinoCtrl,
              decoration: const InputDecoration(
                labelText: 'Destino',
                hintText: 'Ej: Bodega Antúnez, Providencia',
                prefixIcon: Icon(Icons.location_on, color: FleteGGColors.primary),
              ),
              onChanged: (_) => _destino = null,
            ),
            const SizedBox(height: 12),

            // Descripción de carga
            TextField(
              controller: _cargaCtrl,
              decoration: const InputDecoration(
                labelText: '¿Qué llevas?',
                hintText: 'Ej: 10 cajas de mercadería, ~200kg',
                prefixIcon: Icon(Icons.inventory_2),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // Selector de vehículo
            const Text('Tipo de vehículo', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _vehiculoSelector(),
            const SizedBox(height: 20),

            // Botón calcular
            ElevatedButton.icon(
              onPressed: _calcularPrecio,
              icon: const Icon(Icons.calculate),
              label: const Text('CALCULAR PRECIO'),
            ),

            if (_calculando) const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),

            // Precio
            if (_precio != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: FleteGGColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: FleteGGColors.primary.withAlpha(60)),
                ),
                child: Column(
                  children: [
                    const Text('Total estimado', style: TextStyle(color: Colors.grey)),
                    Text(fmtClp(_precio!.precioTotal), style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: FleteGGColors.primary)),
                    Text('${_vehiculoLabel(_vehiculo)} · ${_distancia!.toStringAsFixed(1)} km · ~${MapsService.tiempoEstimadoMin(_distancia!)} min', style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    // Desglose
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Base'),
                        Text(fmtClp(_precio!.base)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${_distancia!.toStringAsFixed(1)} km × ${fmtClp(PricingConfig.porKm[_vehiculo]!)}'),
                        Text(fmtClp(_precio!.costoDistancia)),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(fmtClp(_precio!.precioTotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _confirmando ? null : _confirmarFlete,
                icon: _confirmando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(_confirmando ? 'CONFIRMANDO...' : 'CONFIRMAR FLETE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FleteGGColors.success,
                  minimumSize: const Size.fromHeight(56),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _vehiculoSelector() {
    return SegmentedButton<TipoVehiculoViaje>(
      segments: const [
        ButtonSegment(value: TipoVehiculoViaje.camioneta, label: Text('🛻 Camioneta'), icon: Icon(Icons.local_shipping)),
        ButtonSegment(value: TipoVehiculoViaje.furgon, label: Text('🚐 Furgón'), icon: Icon(Icons.airport_shuttle)),
        ButtonSegment(value: TipoVehiculoViaje.camion34, label: Text('🚚 3/4'), icon: Icon(Icons.local_shipping)),
      ],
      selected: {_vehiculo},
      onSelectionChanged: (s) => setState(() {
        _vehiculo = s.first;
        _precio = null;
      }),
    );
  }

  Future<void> _calcularPrecio() async {
    if (_origenCtrl.text.isEmpty || _destinoCtrl.text.isEmpty) return;

    setState(() => _calculando = true);

    try {
      _origen ??= await MapsService.geocode(_origenCtrl.text);
      _destino ??= await MapsService.geocode(_destinoCtrl.text);

      _distancia = MapsService.distanciaKm(_origen!, _destino!);

      setState(() {
        _precio = PricingService.calcular(
          vehiculo: _vehiculo,
          distanciaKm: _distancia!,
        );
        _calculando = false;
      });
    } catch (e) {
      setState(() => _calculando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No pude encontrar la dirección: $e')),
        );
      }
    }
  }

  Future<void> _confirmarFlete() async {
    final auth = context.read<AuthController>();
    if (_confirmando) return;
    if (_precio == null || _origen == null || _destino == null) return;

    setState(() => _confirmando = true);

    final viaje = Viaje(
      id: '',
      clienteId: auth.user!.uid,
      clienteNombre: auth.perfil!.nombre,
      origenDireccion: _origenCtrl.text,
      origenLat: _origen!.latitude,
      origenLng: _origen!.longitude,
      destinoDireccion: _destinoCtrl.text,
      destinoLat: _destino!.latitude,
      destinoLng: _destino!.longitude,
      vehiculoRequerido: _vehiculo,
      descripcionCarga: _cargaCtrl.text,
      distanciaKm: _distancia!,
      tiempoEstimadoMin: MapsService.tiempoEstimadoMin(_distancia!),
      precioTotal: _precio!.precioTotal,
      comision: _precio!.comision,
      conductorRecibe: _precio!.conductorRecibe,
      estado: EstadoViaje.pendiente,
      createdAt: DateTime.now(),
    );

    try {
      final viajeId = await FirebaseService.crearViaje(viaje);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TrackingPage(viajeId: viajeId),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No pude crear el flete: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _confirmando = false);
    }
  }

  String _vehiculoLabel(TipoVehiculoViaje v) {
    switch (v) {
      case TipoVehiculoViaje.camioneta:
        return 'Camioneta';
      case TipoVehiculoViaje.furgon:
        return 'Furgón cerrado';
      case TipoVehiculoViaje.camion34:
        return 'Camión 3/4';
    }
  }
}