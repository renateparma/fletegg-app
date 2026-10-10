// lib/main.dart
// FleteGG — Entry point

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/colors.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_page.dart';
import 'features/conductor/conductor_home_page.dart';
import 'features/cliente/pedir_flete_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const FleteGGApp());
}

class FleteGGApp extends StatelessWidget {
  const FleteGGApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
      ],
      child: MaterialApp(
        title: 'FleteGG',
        theme: FleteGGTheme.dark,
        debugShowCheckedModeBanner: false,
        home: const RootPage(),
      ),
    );
  }
}

class RootPage extends StatelessWidget {
  const RootPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    if (auth.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!auth.isLoggedIn) {
      return const LoginPage();
    }

    // Redirect según tipo de usuario
    final perfil = auth.perfil;
    if (perfil == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    switch (perfil.tipo) {
      case TipoUsuario.conductor:
        return const ConductorHomePage();
      case TipoUsuario.cliente:
        return const PedirFletePage();
      case TipoUsuario.admin:
        return const Scaffold(body: Center(child: Text('Dashboard admin próximamente')));
    }
  }
}