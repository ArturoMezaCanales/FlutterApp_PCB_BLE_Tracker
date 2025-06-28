import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'ble_background_service.dart';
import 'database_service.dart';
import 'esp32_data_parser.dart';
import 'dart:io' show Platform;

class BackgroundServiceScreen extends StatefulWidget {
  const BackgroundServiceScreen({super.key});

  @override
  State<BackgroundServiceScreen> createState() => _BackgroundServiceScreenState();
}

class _BackgroundServiceScreenState extends State<BackgroundServiceScreen> {
  bool _isServiceRunning = false;
  Map<String, dynamic> _serviceStatus = {};
  List<ESP32Data> _storedData = [];
  int _totalStoredEntries = 0;
  
  @override
  void initState() {
    super.initState();
    _loadServiceStatus();
    _loadStoredData();
    _setupServiceListener();
  }

  void _setupServiceListener() {
    // Skip service listener setup on unsupported platforms
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      print('Service listener not supported on this platform');
      return;
    }
    
    final service = FlutterBackgroundService();
    
    service.on('dataReceived').listen((event) {
      if (mounted) {
        setState(() {
          // Refresh data when new data is received
          _loadStoredData();
        });
      }
    });

    service.on('status').listen((event) {
      if (mounted) {
        setState(() {
          _serviceStatus = event!;
        });
      }
    });
  }

  Future<void> _loadServiceStatus() async {
    final status = await BLEBackgroundService.getServiceStatus();
    
    // Only check background service running status on supported platforms
    bool isRunning = false;
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        isRunning = await FlutterBackgroundService().isRunning();
      } catch (e) {
        print('Error checking service status: $e');
      }
    }
    
    setState(() {
      _isServiceRunning = isRunning;
      _serviceStatus = status;
    });
  }

  Future<void> _loadStoredData() async {
    final data = await DatabaseService.getAllGPSData(limit: 20);
    final count = await DatabaseService.getDataCount();
    
    setState(() {
      _storedData = data;
      _totalStoredEntries = count;
    });
  }

  Future<void> _startBackgroundService() async {
    await BLEBackgroundService.startService();
    await _loadServiceStatus();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Background service started!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _stopBackgroundService() async {
    await BLEBackgroundService.stopService();
    await Future.delayed(const Duration(seconds: 2)); // Wait for service to stop
    await _loadServiceStatus();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Background service stopped!'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _clearStoredData() async {
    await DatabaseService.deleteAllData();
    await _loadStoredData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All stored data cleared!'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _showDataDetails(ESP32Data data) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('GPS Data Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Timestamp: ${data.timestamp}'),
                const SizedBox(height: 8),
                Text('Latitude: ${data.latitude.toStringAsFixed(6)}°'),
                Text('Longitude: ${data.longitude.toStringAsFixed(6)}°'),
                Text('Altitude: ${data.altitude.toStringAsFixed(2)}m'),
                Text('RSSI: ${data.rssi}dBm'),
                const SizedBox(height: 8),
                Text('Valid GPS: ${data.isValidGPSLocation() ? "Yes" : "No"}'),
              ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Service Manager'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadServiceStatus();
              _loadStoredData();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Service Status Card
            Card(
              color: _isServiceRunning ? Colors.green[50] : Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Background Service',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isServiceRunning ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _isServiceRunning ? 'RUNNING' : 'STOPPED',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_serviceStatus.isNotEmpty) ...[
                      Text('Total Packets: ${_serviceStatus['totalPackets'] ?? 0}'),
                      if (_serviceStatus['lastReceived']?.isNotEmpty == true)
                        Text('Last Data: ${DateTime.tryParse(_serviceStatus['lastReceived'])?.toString().substring(11, 19) ?? 'Never'}'),
                      if (_serviceStatus['lastHeartbeat']?.isNotEmpty == true)
                        Text('Last Heartbeat: ${DateTime.tryParse(_serviceStatus['lastHeartbeat'])?.toString().substring(11, 19) ?? 'Never'}'),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Control Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: !_isServiceRunning ? _startBackgroundService : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Start Background Service'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isServiceRunning ? _stopBackgroundService : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Stop Background Service'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Stored Data Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Stored Data ($_totalStoredEntries total)',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        ElevatedButton(
                          onPressed: _totalStoredEntries > 0 ? _clearStoredData : null,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Latest 20 entries (automatically stored in background)',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Data List
            Expanded(
              child: _storedData.isEmpty
                  ? Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No stored data yet',
                                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Start the background service to begin collecting GPS data',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _storedData.length,
                      itemBuilder: (context, index) {
                        ESP32Data data = _storedData[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: data.isValidGPSLocation() ? Colors.green : Colors.orange,
                              child: Icon(
                                data.isValidGPSLocation() ? Icons.gps_fixed : Icons.gps_off,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              '${data.timestamp.toString().substring(11, 19)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Lat: ${data.latitude.toStringAsFixed(4)}, '
                              'Lon: ${data.longitude.toStringAsFixed(4)}\n'
                              'Alt: ${data.altitude.toStringAsFixed(1)}m, RSSI: ${data.rssi}dBm',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _showDataDetails(data),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
