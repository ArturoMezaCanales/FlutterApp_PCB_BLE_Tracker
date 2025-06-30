import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'simple_map_widget.dart';
import 'background_service_screen.dart';
import 'esp32_data_parser.dart';
import 'dart:async';

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
  BluetoothCharacteristic? _sendCharacteristic;  // For sending data to ESP32
  StreamSubscription? _dataSubscription;
  StreamSubscription? _connectionSubscription;
  Timer? _locationTimer;
  Timer? _sendDataTimer;  // Timer for sending data every 2 seconds
  
  // Compass related variables
  StreamSubscription? _compassSubscription;
  double _heading = 0.0;  // Device heading in degrees (0-360)
  bool _compassAvailable = true;

  // ESP32 specific UUIDs
  static const String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";  // For receiving data from ESP32
  static const String RECEIVE_CHAR_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a9";    // For sending data to ESP32

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _initializeCompass();
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
    _sendDataTimer?.cancel();  // Cancel the send data timer
    _compassSubscription?.cancel();  // Cancel compass subscription
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
        
        // Stop sending data if disconnected
        if (state != BluetoothConnectionState.connected) {
          _stopSendingLocationData();
        }
      });

      // Discover services
      List<BluetoothService> services = await widget.connectedDevice!.discoverServices();
      
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            // Data characteristic for receiving data from ESP32
            if (characteristic.uuid.toString().toLowerCase() == CHARACTERISTIC_UUID.toLowerCase()) {
              _dataCharacteristic = characteristic;
              
              // Subscribe to notifications
              await characteristic.setNotifyValue(true);
              _dataSubscription = characteristic.lastValueStream.listen(_processReceivedData);
              
              print('Data characteristic set up successfully');
            }
            // Send characteristic for sending data to ESP32
            else if (characteristic.uuid.toString().toLowerCase() == RECEIVE_CHAR_UUID.toLowerCase()) {
              _sendCharacteristic = characteristic;
              print('Send characteristic found');
            }
          }
        }
      }
      
      // Start sending location data every 2 seconds if we found the send characteristic
      if (_sendCharacteristic != null) {
        _startSendingLocationData();
        setState(() {
          _connectionStatus = 'Connected';
        });
      } else {
        print('Warning: Send characteristic not found');
        setState(() {
          _connectionStatus = 'Connected (Read Only)';
        });
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

  void _startSendingLocationData() {
    // Cancel any existing timer
    _sendDataTimer?.cancel();
    
    // Start sending location data every 2 seconds
    _sendDataTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _sendLocationToESP32();
    });
    
    print('Started sending location data to ESP32 every 2 seconds');
  }

  void _stopSendingLocationData() {
    _sendDataTimer?.cancel();
    _sendDataTimer = null;
    print('Stopped sending location data to ESP32');
  }

  Future<void> _sendLocationToESP32() async {
    if (_sendCharacteristic == null || _phoneLocation == null) {
      return;
    }

    try {
      // Format the data according to ESP32 expected format:
      // MM/DD/YYYY, HH:MM:SS, Latitude, Longitude, Altitude
      DateTime now = DateTime.now();
      String formattedDate = '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year}';
      String formattedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      
      String dataPacket = '$formattedDate, $formattedTime, ${_phoneLocation!.latitude.toStringAsFixed(6)}, ${_phoneLocation!.longitude.toStringAsFixed(6)}, ${_phoneLocation!.altitude.toStringAsFixed(2)}';
      
      // Send the data to ESP32
      await _sendCharacteristic!.write(dataPacket.codeUnits, withoutResponse: false);
      
      print('Sent location to ESP32: $dataPacket');
      
    } catch (e) {
      print('Error sending location to ESP32: $e');
    }
  }

  Future<void> _initializeCompass() async {
    try {
      // Check if we're on web - compass might not be available
      if (kIsWeb) {
        setState(() {
          _compassAvailable = false;
        });
        print('Compass not available on web platform');
        return;
      }
      
      // Subscribe to compass events
      _compassSubscription = FlutterCompass.events?.listen(
        (CompassEvent event) {
          if (event.heading != null) {
            setState(() {
              _heading = event.heading!;
            });
          }
        },
        onError: (error) {
          print('Compass error: $error');
          setState(() {
            _compassAvailable = false;
          });
        },
      );
      
      print('Compass initialized successfully');
    } catch (e) {
      print('Error initializing compass: $e');
      setState(() {
        _compassAvailable = false;
      });
    }
  }

  String _getCompassDirection(double heading) {
    // Convert heading to compass direction
    const List<String> directions = [
      'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
      'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'
    ];
    
    int index = ((heading + 11.25) / 22.5).floor() % 16;
    return directions[index];
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('BLE GPS Tracker'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(255, 0, 0, 139),
              Color.fromARGB(255, 30, 144, 255),
              Color.fromARGB(255, 173, 216, 230),
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: SimpleMapWidget(
                phoneLocation: _phoneLocation,
                phoneHeading: _compassAvailable ? _heading : null,
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.radio, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.connectedDevice?.platformName ?? 'No Device',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
                                  ? Colors.white
                                  : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Signal: $_signalStrength    Last: $_lastUpdate',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _compassAvailable
                        ? 'Compass: ${_heading.toStringAsFixed(0)}° ${_getCompassDirection(_heading)}'
                        : 'Compass: Not Available',
                    style: TextStyle(
                      color: _compassAvailable ? Colors.white : Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (_sendDataTimer?.isActive == true)
                        const Text(
                          'Sending location every 2s',
                          style: TextStyle(color: Colors.green),
                        )
                      else if (widget.connectedDevice != null)
                        const Text(
                          'Not sending location',
                          style: TextStyle(color: Colors.orange),
                        ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _openDebugScreen,
                        icon: const Icon(Icons.bug_report, size: 16),
                        label: const Text('Debug'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}