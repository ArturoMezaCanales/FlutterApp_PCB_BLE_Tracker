import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  String _bluetoothStatus = 'Checking Bluetooth...';
  String _scanResults = '';

  @override
  void initState() {
    super.initState();
    _checkBluetooth();
  }

  Future<void> _checkBluetooth() async {
    BluetoothAdapterState state = await FlutterBluePlus.adapterState.first;
    setState(() {
      if (state == BluetoothAdapterState.on) {
        _bluetoothStatus = 'Bluetooth is ON';
      } else {
        _bluetoothStatus = 'Bluetooth is OFF';
        _scanResults = ''; // clear scan results if off
      }
    });
  }

void _startScan() async {
  setState(() {
    _scanResults = 'Scanning...';
  });

  FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

  FlutterBluePlus.scanResults.listen((results) {
    for (var scanResult in results) {
      final deviceName = scanResult.device.name.isNotEmpty
          ? scanResult.device.name
          : scanResult.device.id.id;
      if (!_scanResults.contains(deviceName)) {
        setState(() {
          _scanResults += '\n$deviceName';
        });
      }
    }
  });

  await Future.delayed(const Duration(seconds: 4));
  FlutterBluePlus.stopScan();

  setState(() {
    _scanResults += '\nScan complete.';
  });
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bluetooth Scan')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _bluetoothStatus,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _checkBluetooth,
                child: const Text('Check Bluetooth Status'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed:
                    (_bluetoothStatus == 'Bluetooth is ON') ? _startScan : null,
                child: const Text('Start Scan'),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    _scanResults,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
