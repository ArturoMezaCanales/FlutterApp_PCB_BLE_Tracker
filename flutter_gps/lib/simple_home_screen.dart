import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'simple_map_widget.dart';
import 'background_service_screen.dart';
import 'esp32_data_parser.dart';
import 'dart:async';
import 'dart:io' show Platform;

class SimpleHomeScreen extends StatefulWidget {
  final BluetoothDevice? connectedDevice;

  const SimpleHomeScreen({super.key, this.connectedDevice});

  @override
  State<SimpleHomeScreen> createState() => _SimpleHomeScreenState();
}

class _SimpleHomeScreenState extends State<SimpleHomeScreen> {
  Position? _phoneLocation;
  ESP32Data? _espData;
  String _connectionStatus = 'Disconnected';
  String _signalStrength = '--';
  String _lastUpdate = 'Never';
  BluetoothCharacteristic? _dataCharacteristic;
  StreamSubscription? _dataSubscription;
  StreamSubscription? _connectionSubscription;
  Timer? _locationTimer;

  // ESP32 specific UUIDs
  static const String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    if (widget.connectedDevice != null) {
      _setupBLEConnection();
    } else {
      _connectionStatus = 'Demo Mode';
      _startDemoMode();
    }
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _connectionSubscription?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    try {
      // Handle location permissions differently for web and mobile
      if (kIsWeb) {
        // On web, just try to get location without explicit permission check
        try {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );
          setState(() {
            _phoneLocation = position;
          });
        } catch (e) {
          print('Web location error: $e');
          // Set a default location for demo purposes
          setState(() {
            _phoneLocation = Position(
              latitude: 37.7749, // San Francisco as default
              longitude: -122.4194,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              heading: 0,
              speed: 0,
              speedAccuracy: 0,
              altitudeAccuracy: 0,
              headingAccuracy: 0,
            );
          });
        }
      } else {
        // On mobile platforms, handle permissions properly
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          Position position = await Geolocator.getCurrentPosition();
          setState(() {
            _phoneLocation = position;
          });
        } else {
          print('Location permission denied');
        }
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void _startLocationUpdates() {
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _updatePhoneLocation();
    });
  }

  Future<void> _updatePhoneLocation() async {
    try {
      if (kIsWeb) {
        // On web, use simpler location request
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        setState(() {
          _phoneLocation = position;
        });
      } else {
        // On mobile platforms
        Position position = await Geolocator.getCurrentPosition();
        setState(() {
          _phoneLocation = position;
        });
      }
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  Future<void> _setupBLEConnection() async {
    if (widget.connectedDevice == null) return;

    try {
      // Monitor connection state
      _connectionSubscription = widget.connectedDevice!.connectionState.listen((state) {
        setState(() {
          _connectionStatus = state == BluetoothConnectionState.connected 
            ? 'Connected' 
            : 'Disconnected';
        });
      });

      // Discover services
      List<BluetoothService> services = await widget.connectedDevice!.discoverServices();
      
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == CHARACTERISTIC_UUID.toLowerCase()) {
              _dataCharacteristic = characteristic;
              
              // Subscribe to notifications
              await characteristic.setNotifyValue(true);
              _dataSubscription = characteristic.lastValueStream.listen(_processReceivedData);
              
              setState(() {
                _connectionStatus = 'Connected';
              });
              break;
            }
          }
        }
      }
    } catch (e) {
      setState(() {
        _connectionStatus = 'Connection Error';
      });
      print('BLE setup error: $e');
    }
  }

  void _processReceivedData(List<int> data) {
    try {
      String dataString = String.fromCharCodes(data);
      ESP32Data? parsedData = ESP32Data.parseFromString(dataString);
      
      if (parsedData != null) {
        setState(() {
          _espData = parsedData;
          _lastUpdate = _formatLastUpdate();
        });
      }
      
      // Update signal strength if device is connected
      if (widget.connectedDevice != null) {
        _updateSignalStrength();
      }
    } catch (e) {
      print('Error processing data: $e');
    }
  }

  Future<void> _updateSignalStrength() async {
    try {
      if (widget.connectedDevice != null) {
        int rssi = await widget.connectedDevice!.readRssi();
        setState(() {
          _signalStrength = '${rssi} dBm';
        });
      }
    } catch (e) {
      // RSSI read failed, keep current value
      print('Error reading RSSI: $e');
    }
  }

  String _formatLastUpdate() {
    return 'Just now';
  }

  void _openDebugScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BackgroundServiceScreen(),
      ),
    );
  }

  void _startDemoMode() {
    // Create demo ESP32 data near the phone location
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_phoneLocation != null && widget.connectedDevice == null) {
        // Add slight variation to make it more realistic
        final random = DateTime.now().millisecond / 1000.0;
        final variation = (random - 0.5) * 0.0002; // Small random movement
        
        // Create a demo ESP32 location with more visible offset from phone
        final demoLat = _phoneLocation!.latitude + 0.0008 + variation;
        final demoLng = _phoneLocation!.longitude + 0.0006 + variation;
        
        final demoData = ESP32Data(
          latitude: demoLat,
          longitude: demoLng,
          altitude: 100.0, // Demo altitude
          timestamp: DateTime.now(),
          rssi: -45 + (random * 10).round(), // Varying RSSI
        );
        
        setState(() {
          _espData = demoData;
          _lastUpdate = 'Just now';
          _signalStrength = '${demoData.rssi} dBm (Demo)';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE GPS Tracker'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Map View
          Expanded(
            flex: 3,
            child: SimpleMapWidget(
              phoneLocation: _phoneLocation,
              espLocation: _espData != null 
                ? Position(
                    latitude: _espData!.latitude,
                    longitude: _espData!.longitude,
                    timestamp: DateTime.now(),
                    accuracy: 0,
                    altitude: 0,
                    heading: 0,
                    speed: 0,
                    speedAccuracy: 0,
                    altitudeAccuracy: 0,
                    headingAccuracy: 0,
                  )
                : null,
            ),
          ),
          
          // Single Device Status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Column(
              children: [
                // Device status row
                Row(
                  children: [
                    const Icon(Icons.radio, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.connectedDevice?.platformName ?? 'No Device',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.circle,
                      color: _connectionStatus == 'Connected' 
                        ? Colors.green 
                        : _connectionStatus == 'Demo Mode'
                          ? Colors.orange
                          : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _connectionStatus,
                      style: TextStyle(
                        color: _connectionStatus == 'Connected' 
                          ? Colors.green 
                          : _connectionStatus == 'Demo Mode'
                            ? Colors.orange
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Signal and last update row
                Row(
                  children: [
                    Text('Signal: $_signalStrength'),
                    const Spacer(),
                    Text('Last: $_lastUpdate'),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _openDebugScreen,
                      icon: const Icon(Icons.bug_report, size: 16),
                      label: const Text('Debug'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
