import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'simple_home_screen.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  List<BluetoothDevice> _foundDevices = [];
  bool _isScanning = false;
  bool _isConnecting = false;
  String _statusMessage = 'Ready to scan for ESP32 devices';
  StreamSubscription? _scanSubscription;

  // ESP32 specific settings
  static const String TARGET_DEVICE_PREFIX = "ESP32";

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      setState(() {
        _statusMessage = 'Bluetooth scanning not supported on web. Use Demo Mode.';
      });
    } else {
      _checkBluetooth();
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkBluetooth() async {
    BluetoothAdapterState state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      setState(() {
        _statusMessage = 'Please enable Bluetooth to continue';
      });
    }
  }

  Future<void> _startScan() async {
    // Skip BLE scan on web
    if (kIsWeb) {
      setState(() {
        _statusMessage = 'BLE scanning not available on web. Please use Demo Mode.';
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _foundDevices.clear();
      _statusMessage = 'Scanning for ESP32 devices...';
    });

    try {
      await FlutterBluePlus.stopScan();
      
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (var scanResult in results) {
          final deviceName = scanResult.device.platformName;
          if (deviceName.isNotEmpty && 
              deviceName.toUpperCase().contains(TARGET_DEVICE_PREFIX) &&
              !_foundDevices.any((d) => d.remoteId == scanResult.device.remoteId)) {
            setState(() {
              _foundDevices.add(scanResult.device);
            });
          }
        }
      });

      // Wait for scan to complete
      await Future.delayed(const Duration(seconds: 10));
      await FlutterBluePlus.stopScan();

      setState(() {
        _isScanning = false;
        if (_foundDevices.isEmpty) {
          _statusMessage = 'No ESP32 devices found. Try again.';
        } else {
          _statusMessage = 'Found ${_foundDevices.length} ESP32 device(s)';
        }
      });

    } catch (e) {
      setState(() {
        _isScanning = false;
        _statusMessage = 'Error scanning: $e';
      });
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Connecting to ${device.platformName}...';
    });

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      
      // Navigate to home screen with connected device
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SimpleHomeScreen(connectedDevice: device),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _statusMessage = 'Failed to connect: $e';
      });
    }
  }

  void _skipConnection() {
    // Enter app without device (demo mode)
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const SimpleHomeScreen(connectedDevice: null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE GPS Tracker'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.bluetooth_searching,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            const Text(
              'Connect to ESP32 Device',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Scan button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isScanning || _isConnecting || kIsWeb) ? null : _startScan,
                icon: _isScanning 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
                label: Text(kIsWeb 
                  ? 'Web - Use Demo Mode' 
                  : (_isScanning ? 'Scanning...' : 'Scan for Devices')),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Found devices list
            if (_foundDevices.isNotEmpty) ...[
              const Text(
                'Found Devices:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...(_foundDevices.map((device) => Card(
                child: ListTile(
                  leading: const Icon(Icons.device_hub, color: Colors.blue),
                  title: Text(device.platformName),
                  subtitle: Text(device.remoteId.toString()),
                  trailing: _isConnecting 
                    ? const CircularProgressIndicator()
                    : const Icon(Icons.arrow_forward_ios),
                  onTap: _isConnecting ? null : () => _connectToDevice(device),
                ),
              ))),
            ],
            
            const SizedBox(height: 32),
            
            // Skip button
            TextButton(
              onPressed: _isConnecting ? null : _skipConnection,
              child: const Text(
                'Skip - Enter Demo Mode',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
