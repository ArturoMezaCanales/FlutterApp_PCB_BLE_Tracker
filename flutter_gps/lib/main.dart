import 'package:flutter/material.dart';
import 'connection_screen.dart';
import 'ble_background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize background service
  await BLEBackgroundService.initializeService();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE GPS Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ConnectionScreen(),
    );
  }
}
