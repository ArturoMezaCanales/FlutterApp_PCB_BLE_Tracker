import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'esp32_data_parser.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  String _bluetoothStatus = 'Checking Bluetooth...';
  String _scanResults = '';
  String _connectionStatus = '';
  String _receivedData = '';
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _dataCharacteristic;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _dataSubscription;
  
  // Data tracking
  ESP32Data? _latestData;
  List<ESP32Data> _dataHistory = [];
  int _totalPacketsReceived = 0;

  // ESP32 specific UUIDs from your Arduino code
  static const String TARGET_DEVICE_NAME = "ESP32-S3-Zero";
  static const String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  @override
  void initState() {
    super.initState();
    _checkBluetooth();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _dataSubscription?.cancel();
    _disconnectDevice();
    super.dispose();
  }

  Future<void> _checkBluetooth() async {
    BluetoothAdapterState state = await FlutterBluePlus.adapterState.first;
    setState(() {
      if (state == BluetoothAdapterState.on) {
        _bluetoothStatus = 'Bluetooth is ON';
      } else {
        _bluetoothStatus = 'Bluetooth is OFF - Please enable Bluetooth';
        _scanResults = '';
        _connectionStatus = '';
      }
    });
  }

  void _startScan() async {
    if (_connectedDevice != null) {
      setState(() {
        _scanResults = 'Already connected to a device. Disconnect first.';
      });
      return;
    }

    setState(() {
      _scanResults = 'Scanning for ESP32-S3-Zero...';
      _connectionStatus = '';
    });

    try {
      // Stop any existing scan
      await FlutterBluePlus.stopScan();
      
      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        withNames: [TARGET_DEVICE_NAME], // Only look for our specific device
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (var scanResult in results) {
          if (scanResult.device.platformName == TARGET_DEVICE_NAME) {
            setState(() {
              _scanResults = 'Found ESP32-S3-Zero!\nRSSI: ${scanResult.rssi} dBm';
            });
            // Automatically attempt connection when found
            _connectToDevice(scanResult.device);
            break;
          }
        }
      });

      // Wait for scan to complete
      await Future.delayed(const Duration(seconds: 10));
      await FlutterBluePlus.stopScan();

      if (_connectedDevice == null) {
        setState(() {
          _scanResults += '\nScan complete. ESP32-S3-Zero not found.';
        });
      }
    } catch (e) {
      setState(() {
        _scanResults = 'Scan error: $e';
      });
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      setState(() {
        _connectionStatus = 'Connecting to ESP32-S3-Zero...';
      });

      // Stop scanning
      await FlutterBluePlus.stopScan();

      // Connect to device
      await device.connect(timeout: const Duration(seconds: 15));
      
      setState(() {
        _connectedDevice = device;
        _connectionStatus = 'Connected to ESP32-S3-Zero!';
      });

      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      
      // Find our specific service and characteristic
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == CHARACTERISTIC_UUID.toLowerCase()) {
              _dataCharacteristic = characteristic;
              
              // Subscribe to notifications
              await characteristic.setNotifyValue(true);
              
              _dataSubscription = characteristic.lastValueStream.listen((value) {
                String dataString = String.fromCharCodes(value);
                _totalPacketsReceived++;
                
                // Parse the data
                ESP32Data? parsedData = ESP32Data.parseFromString(dataString);
                
                setState(() {
                  _receivedData = 'Raw data:\n$dataString\n\n$_receivedData';
                  
                  if (parsedData != null) {
                    _latestData = parsedData;
                    _dataHistory.insert(0, parsedData);
                    
                    // Keep only last 50 entries
                    if (_dataHistory.length > 50) {
                      _dataHistory = _dataHistory.take(50).toList();
                    }
                  }
                  
                  // Keep only last 10 raw entries to prevent UI overflow
                  List<String> lines = _receivedData.split('\n');
                  if (lines.length > 50) {
                    _receivedData = lines.take(50).join('\n');
                  }
                });
              });

              setState(() {
                _connectionStatus = 'Connected and receiving data!';
              });
              break;
            }
          }
          break;
        }
      }

      // Listen for disconnection
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          setState(() {
            _connectionStatus = 'Device disconnected';
            _connectedDevice = null;
            _dataCharacteristic = null;
          });
          _dataSubscription?.cancel();
        }
      });

    } catch (e) {
      setState(() {
        _connectionStatus = 'Connection failed: $e';
        _connectedDevice = null;
      });
    }
  }

  Future<void> _disconnectDevice() async {
    if (_connectedDevice != null) {
      try {
        await _dataSubscription?.cancel();
        await _connectedDevice!.disconnect();
        setState(() {
          _connectionStatus = 'Disconnected';
          _connectedDevice = null;
          _dataCharacteristic = null;
          _receivedData = '';
          _latestData = null;
          _dataHistory.clear();
          _totalPacketsReceived = 0;
        });
      } catch (e) {
        setState(() {
          _connectionStatus = 'Disconnect error: $e';
        });
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32-S3-Zero BLE Tracker'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bluetooth Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      _bluetoothStatus,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _checkBluetooth,
                      child: const Text('Refresh Bluetooth Status'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 10),
            
            // Control Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_bluetoothStatus == 'Bluetooth is ON' && _connectedDevice == null) 
                        ? _startScan : null,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Scan for ESP32-S3-Zero'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _connectedDevice != null ? _disconnectDevice : null,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Disconnect'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 10),
            
            // Scan Results Card
            if (_scanResults.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scan Results:',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _scanResults,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Connection Status Card
            if (_connectionStatus.isNotEmpty)
              Card(
                color: _connectedDevice != null ? Colors.green[50] : Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Connection Status:',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          if (_connectedDevice != null)
                            Text(
                              'Packets: $_totalPacketsReceived',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _connectionStatus,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 10),
            
            // Latest Data Card
            if (_latestData != null)
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Latest GPS Data:',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _latestData!.toFormattedString(),
                        style: const TextStyle(fontSize: 14),
                      ),
                      if (!_latestData!.isValidGPSLocation())
                        const Text(
                          'Warning: Invalid GPS coordinates',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),
              ),
            
            // Raw Data Display Card
            if (_receivedData.isNotEmpty)
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Raw Data Log:',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _receivedData = '';
                                    });
                                  },
                                  child: const Text('Clear'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _dataHistory.isNotEmpty ? () {
                                    _showDataHistoryDialog(context);
                                  } : null,
                                  child: const Text('History'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              _receivedData,
                              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDataHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Data History (${_dataHistory.length} entries)'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: _dataHistory.length,
              itemBuilder: (context, index) {
                ESP32Data data = _dataHistory[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Entry ${index + 1}:',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(data.toFormattedString()),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
