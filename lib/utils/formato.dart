// lib/utils/formato.dart
// Helpers de formato compartidos (precios CLP con separador de miles)

/// Formatea un entero con puntos de miles al estilo chileno: 18000 → "18.000"
String fmtMiles(int n) =>
    n.toString().replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), '.');

/// Precio en pesos chilenos con signo: 18000 → "$18.000"
String fmtClp(int n) => '\$${fmtMiles(n)}';
