import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'screens/web/web_landing_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    runApp(const _WebApp());
    return;
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(
    const ProviderScope(
      child: MotoRemapApp(),
    ),
  );
}

class _WebApp extends StatelessWidget {
  const _WebApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MotoRemap Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const WebLandingScreen(),
    );
  }
}
