# FleteGG App — Flutter

App de fletes bajo demanda por EggClaw Solutions.

## Estructura

```
lib/
├── main.dart                  # Entry point + routing
├── app/
│   ├── app.dart               # MaterialApp + theme
│   └── routes.dart            # GoRouter config
├── features/
│   ├── auth/                  # Login + registro (teléfono OTP)
│   │   ├── login_page.dart
│   │   ├── register_page.dart
│   │   └── auth_controller.dart
│   ├── conductor/             # App del conductor
│   │   ├── conductor_home_page.dart
│   │   ├── viaje_detalle_page.dart
│   │   ├── ganancias_page.dart
│   │   └── perfil_conductor_page.dart
│   ├── cliente/               # App del cliente
│   │   ├── cliente_home_page.dart
│   │   ├── pedir_flete_page.dart
│   │   ├── tracking_page.dart
│   │   └── historial_page.dart
│   └── admin/                 # Dashboard Renate
│       └── admin_page.dart
├── models/
│   ├── usuario.dart
│   ├── viaje.dart
│   ├── vehiculo.dart
│   └── pricing.dart
├── services/
│   ├── firebase_service.dart
│   ├── maps_service.dart
│   ├── pricing_service.dart
│   ├── pago_service.dart
│   └── notification_service.dart
├── widgets/
│   ├── map_widget.dart
│   ├── viaje_card.dart
│   ├── vehiculo_selector.dart
│   └── rating_widget.dart
└── theme/
    └── colors.dart
```

## Setup

1. `flutter pub get`
2. Configurar Firebase: `flutterfire configure`
3. Agregar Google Maps API key en `lib/services/maps_service.dart`
4. `flutter run`

## Stack

- Flutter 3.24+
- Firebase (Auth, Firestore, Cloud Functions, Storage)
- Google Maps SDK
- Mercado Pago SDK
- GoRouter (navegación)