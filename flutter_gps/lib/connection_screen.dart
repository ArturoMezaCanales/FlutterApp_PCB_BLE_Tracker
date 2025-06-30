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
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const SimpleHomeScreen(connectedDevice: null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade900,
              Colors.blue.shade600,
              Colors.blue.shade300,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedScale(
                        scale: _isScanning ? 1.1 : 1.0,
                        duration: const Duration(milliseconds: 600),
                        child: Icon(
                          Icons.bluetooth_searching,
                          size: 100,
                          color: Colors.white.withAlpha(230), // ~90% white
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Connect to ESP32 Device',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              blurRadius: 10.0,
                              color: Colors.black.withAlpha(77),
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: (_isScanning || _isConnecting || kIsWeb) ? null : _startScan,
                        icon: _isScanning
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.search),
                        label: Text(
                          kIsWeb
                              ? 'Web - Use Demo Mode'
                              : (_isScanning ? 'Scanning...' : 'Scan for Devices'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          disabledBackgroundColor: Colors.grey.shade500,
                          foregroundColor: Colors.white,
                          elevation: 8,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _statusMessage,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (_foundDevices.isNotEmpty) ...[
                        Text(
                          'Found Devices:',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withAlpha(230),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _foundDevices.length,
                            itemBuilder: (context, index) {
                              final device = _foundDevices[index];
                              return AnimatedOpacity(
                                opacity: _isConnecting ? 0.6 : 1.0,
                                duration: const Duration(milliseconds: 300),
                                child: Card(
                                  color: Colors.white.withAlpha(25),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withAlpha(50)),
                                    ),
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.device_hub,
                                        color: Colors.blue.shade300,
                                      ),
                                      title: Text(
                                        device.platformName,
                                        style: TextStyle(
                                          color: Colors.white.withAlpha(230),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        device.remoteId.toString(),
                                        style: TextStyle(
                                          color: Colors.white.withAlpha(180),
                                          fontSize: 12,
                                        ),
                                      ),
                                      trailing: _isConnecting
                                          ? const CircularProgressIndicator(
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                            )
                                          : Icon(
                                              Icons.arrow_forward_ios,
                                              color: Colors.white.withAlpha(180),
                                              size: 16,
                                            ),
                                      onTap: _isConnecting ? null : () => _connectToDevice(device),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: _isConnecting ? null : _skipConnection,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    backgroundColor: Colors.white.withAlpha(25),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Skip - Enter Demo Mode',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withAlpha(230),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
