// lib/services/pago_service.dart
// Flow.cl — integración de pagos (Chile)

class PagoService {
  // TODO: Pegar credenciales de Flow (apiKey + secret)
  static const String flowApiKey = 'YOUR_FLOW_API_KEY';
  static const String flowSecret = 'YOUR_FLOW_SECRET';
  static const String flowBaseUrl = 'https://www.flow.cl/api';

  /// Crear pago para un viaje
  /// Flow genera un URL de pago que el cliente abre en el navegador/app
  static Future<Map<String, dynamic>> crearPago({
    required int monto,
    required String viajeId,
    required String descripcion,
    String? emailCliente,
  }) async {
    // POST {flowBaseUrl}/payment/create
    //
    // Body (form-urlencoded, firmado con HMAC-SHA256):
    // {
    //   "apiKey": flowApiKey,
    //   "commerceOrder": viajeId,
    //   "subject": "FleteGG - Viaje $viajeId",
    //   "amount": monto,
    //   "currency": "CLP",
    //   "email": emailCliente,
    //   "urlConfirmation": "https://eggclaw.cl/fletegg/api/flow/webhook",
    //   "urlReturn": "https://eggclaw.cl/fletegg/pago-ok",
    //   "optional": jsonEncode({"viajeId": viajeId})
    // }
    //
    // Response:
    // {
    //   "token": "xxxx",
    //   "url": "https://www.flow.cl/pay/?token=xxxx",
    //   "flowOrder": 12345
    // }
    //
    // El cliente abre url → paga → Flow notifica a urlConfirmation

    throw UnimplementedError('Flow pendiente — implementar cuando tengamos apiKey + secret');
  }

  /// Confirmar pago (webhook de Flow → urlConfirmation)
  /// Flow envía POST con: token, commerceOrder, flowOrder, amount, status
  static Future<bool> confirmarPago({
    required String token,
    required String commerceOrder,
    required int flowOrder,
    required int amount,
    required String status,
  }) async {
    // Verificar firma HMAC
    // Si status == 2 (pagado), actualizar viaje en Firestore:
    //   estado → asignado (o confirmar pago)
    //   guardar flowOrder + amount en el documento
    //
    // Flow statuses:
    //   1 = pendiente
    //   2 = pagado
    //   3 = rechazado
    //   4 = anulado

    if (status == '2') {
      // Pago confirmado — actualizar viaje
      // await FirebaseService.actualizarViaje(commerceOrder, {
      //   'pagoFlowOrder': flowOrder,
      //   'pagoMonto': amount,
      //   'pagoEstado': 'pagado',
      // });
      return true;
    }
    return false;
  }

  /// Transferir al conductor (retiro)
  /// Flow tiene endpoint para transferencia bancaria
  static Future<void> transferirConductor({
    required String conductorId,
    required int monto,
    required String banco,
    required String tipoCuenta,
    required String numeroCuenta,
    required String rut,
  }) async {
    // POST {flowBaseUrl}/transfer/create
    // Body: apiKey, amount, rut, bank, accountType, accountNumber, subject
    //
    // Requiere que el conductor tenga cuenta bancaria registrada
    throw UnimplementedError('Transferencia conductor pendiente');
  }

  /// Estado del pago (consultar)
  static Future<Map<String, dynamic>> getEstadoPago(String token) async {
    // GET {flowBaseUrl}/payment/getStatus?token={token}&apiKey={apiKey}
    throw UnimplementedError('Consulta de estado pendiente');
  }
}