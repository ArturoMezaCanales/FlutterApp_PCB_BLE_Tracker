import 'dart:async';
import 'dart:ui';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'esp32_data_parser.dart';
import 'database_service.dart';

class BLEBackgroundService {
  static const String channelId = 'esp32_ble_service';
  static const String channelName = 'ESP32 BLE Connection Service';
  static const int notificationId = 1001;

  // ESP32 specific UUIDs
  static const String targetDeviceName = "ESP32-S3-Zero";
  static const String serviceUUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String characteristicUUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  static FlutterLocalNotificationsPlugin? _notifications;
  static BluetoothDevice? _connectedDevice;
  static BluetoothCharacteristic? _dataCharacteristic;
  static StreamSubscription? _scanSubscription;
  static StreamSubscription? _dataSubscription;
  static StreamSubscription? _connectionSubscription;
  static Timer? _reconnectTimer;
  static Timer? _heartbeatTimer;

  static int _totalPacketsReceived = 0;
  static DateTime? _lastDataReceived;
  static bool _isServiceRunning = false;

  static Future<void> initializeService() async {
    // Check if platform supports background service
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      print('Background service not supported on this platform');
      return;
    }

    final service = FlutterBackgroundService();

    // Configure notifications
    await _initializeNotifications();

    await service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: channelId,
        initialNotificationTitle: 'ESP32 BLE Tracker',
        initialNotificationContent: 'Scanning for ESP32-S3-Zero...',
        foregroundServiceNotificationId: notificationId,
      ),
    );
  }

  static Future<void> _initializeNotifications() async {
    // Skip notifications on web or unsupported platforms
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      print('Notifications not supported on this platform');
      return;
    }

    _notifications = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notifications!.initialize(initializationSettings);

    // Create notification channel (Android only)
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: 'ESP32 BLE connection status notifications',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      );

      await _notifications!
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    
    if (_isServiceRunning) return;
    _isServiceRunning = true;

    await _initializeNotifications();
    await _updateNotification('Initializing ESP32 BLE Service...', 'Starting up');

    // Set up periodic tasks
    _setupHeartbeat(service);
    
    // Start BLE scanning and connection
    await _startBLEService(service);

    service.on('stopService').listen((event) async {
      await _stopService();
      service.stopSelf();
    });

    service.on('getStatus').listen((event) async {
      service.invoke('status', {
        'isConnected': _connectedDevice != null,
        'packetsReceived': _totalPacketsReceived,
        'lastDataReceived': _lastDataReceived?.toIso8601String(),
        'deviceName': _connectedDevice?.platformName ?? 'None',
      });
    });
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    // iOS background handling
    return true;
  }

  static void _setupHeartbeat(ServiceInstance service) {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_heartbeat', DateTime.now().toIso8601String());
      
      // Send status update
      service.invoke('heartbeat', {
        'timestamp': DateTime.now().toIso8601String(),
        'isConnected': _connectedDevice != null,
        'packetsReceived': _totalPacketsReceived,
      });

      // Check connection health and handle reconnection
      await _checkConnectionHealth(service);
    });
  }

  static Future<void> _startBLEService(ServiceInstance service) async {
    try {
      await _updateNotification('ESP32 BLE Tracker', 'Scanning for device...');
      
      // Start scanning for ESP32 device
      await _scanForDevice(service);
      
    } catch (e) {
      await _updateNotification('ESP32 BLE Tracker', 'Error: $e');
      print('BLE Service error: $e');
    }
  }

  static Future<void> _scanForDevice(ServiceInstance service) async {
    try {
      if (_connectedDevice != null) return;

      await _updateNotification('ESP32 BLE Tracker', 'Scanning for $targetDeviceName...');

      await FlutterBluePlus.stopScan();
      
      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        withNames: [targetDeviceName],
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        for (var scanResult in results) {
          if (scanResult.device.platformName == targetDeviceName) {
            await FlutterBluePlus.stopScan();
            await _connectToDevice(scanResult.device, service);
            break;
          }
        }
      });

      // Set up retry mechanism
      _reconnectTimer = Timer(const Duration(seconds: 20), () async {
        if (_connectedDevice == null) {
          print('Device not found, retrying in 30 seconds...');
          await _updateNotification('ESP32 BLE Tracker', 'Device not found, retrying...');
          
          Timer(const Duration(seconds: 30), () {
            _scanForDevice(service);
          });
        }
      });

    } catch (e) {
      print('Scan error: $e');
      await _updateNotification('ESP32 BLE Tracker', 'Scan error, retrying...');
      
      Timer(const Duration(seconds: 30), () {
        _scanForDevice(service);
      });
    }
  }

  static Future<void> _connectToDevice(BluetoothDevice device, ServiceInstance service) async {
    try {
      await _updateNotification('ESP32 BLE Tracker', 'Connecting to ${device.platformName}...');
      
      await device.connect(timeout: const Duration(seconds: 15));
      _connectedDevice = device;
      
      await _updateNotification('ESP32 BLE Tracker', 'Connected! Discovering services...');

      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      
      // Find our service and characteristic
      for (BluetoothService bleService in services) {
        if (bleService.uuid.toString().toLowerCase() == serviceUUID.toLowerCase()) {
          for (BluetoothCharacteristic characteristic in bleService.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == characteristicUUID.toLowerCase()) {
              _dataCharacteristic = characteristic;
              
              // Subscribe to notifications
              await characteristic.setNotifyValue(true);
              
              _dataSubscription = characteristic.lastValueStream.listen((value) async {
                await _handleDataReceived(value, service);
              });

              await _updateNotification('ESP32 BLE Tracker', 'Connected and receiving data!');
              break;
            }
          }
          break;
        }
      }

      // Monitor connection state
      _connectionSubscription = device.connectionState.listen((state) async {
        if (state == BluetoothConnectionState.disconnected) {
          await _handleDisconnection(service);
        }
      });

    } catch (e) {
      print('Connection error: $e');
      await _updateNotification('ESP32 BLE Tracker', 'Connection failed, retrying...');
      _connectedDevice = null;
      
      // Retry connection
      Timer(const Duration(seconds: 30), () {
        _scanForDevice(service);
      });
    }
  }

  static Future<void> _handleDataReceived(List<int> value, ServiceInstance service) async {
    String dataString = String.fromCharCodes(value);
    _totalPacketsReceived++;
    _lastDataReceived = DateTime.now();

    // Parse and store data
    ESP32Data? parsedData = ESP32Data.parseFromString(dataString);
    if (parsedData != null) {
      await DatabaseService.insertGPSData(parsedData);
      
      // Update notification with latest data
      await _updateNotification(
        'ESP32 BLE Tracker - Connected',
        'Packets: $_totalPacketsReceived | Last: ${parsedData.timestamp.toString().substring(11, 19)}',
      );

      // Send data to UI if app is open
      service.invoke('dataReceived', {
        'data': dataString,
        'parsedData': parsedData.toMap(),
        'totalPackets': _totalPacketsReceived,
      });
    }

    // Store preferences for UI
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('total_packets', _totalPacketsReceived);
    await prefs.setString('last_data', dataString);
    await prefs.setString('last_received', _lastDataReceived!.toIso8601String());
  }

  static Future<void> _handleDisconnection(ServiceInstance service) async {
    print('Device disconnected');
    await _updateNotification('ESP32 BLE Tracker', 'Device disconnected, reconnecting...');
    
    _connectedDevice = null;
    await _dataSubscription?.cancel();
    await _connectionSubscription?.cancel();

    // Attempt reconnection
    Timer(const Duration(seconds: 5), () {
      _scanForDevice(service);
    });
  }

  static Future<void> _checkConnectionHealth(ServiceInstance service) async {
    if (_connectedDevice != null && _lastDataReceived != null) {
      Duration timeSinceLastData = DateTime.now().difference(_lastDataReceived!);
      
      if (timeSinceLastData.inSeconds > 120) { // No data for 2 minutes
        print('No data received for ${timeSinceLastData.inSeconds} seconds, checking connection...');
        
        try {
          // Try to check connection state
          if (_connectedDevice!.isConnected == false) {
            print('Connection health check: device not connected');
            await _handleDisconnection(service);
          }
        } catch (e) {
          print('Connection health check failed: $e');
          await _handleDisconnection(service);
        }
      }
    } else if (_connectedDevice == null) {
      // Not connected, try to scan for device
      print('Health check: Not connected, starting scan...');
      await _scanForDevice(service);
    }
  }

  static Future<void> _updateNotification(String title, String content) async {
    // Skip notifications on unsupported platforms
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS) || _notifications == null) {
      print('Notification: $title - $content');
      return;
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'ESP32 BLE connection status',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notifications!.show(
      notificationId,
      title,
      content,
      platformChannelSpecifics,
    );
  }

  static Future<void> _stopService() async {
    _isServiceRunning = false;
    
    await _scanSubscription?.cancel();
    await _dataSubscription?.cancel();
    await _connectionSubscription?.cancel();
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();

    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (e) {
        print('Error disconnecting: $e');
      }
    }

    await _notifications?.cancel(notificationId);
    
    _connectedDevice = null;
    _dataCharacteristic = null;
  }

  // Public methods for UI
  static Future<void> startService() async {
    // Check if platform supports background service
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      print('Background service not supported on this platform');
      return;
    }

    final service = FlutterBackgroundService();
    bool isRunning = await service.isRunning();
    
    if (!isRunning) {
      await service.startService();
    }
  }

  static Future<void> stopService() async {
    // Check if platform supports background service
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      print('Background service not supported on this platform');
      return;
    }

    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  static Future<Map<String, dynamic>> getServiceStatus() async {
    final prefs = await SharedPreferences.getInstance();
    
    // For unsupported platforms, return mock status
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return {
        'isRunning': false,
        'totalPackets': prefs.getInt('total_packets') ?? 0,
        'lastData': prefs.getString('last_data') ?? '',
        'lastReceived': prefs.getString('last_received') ?? '',
        'lastHeartbeat': prefs.getString('last_heartbeat') ?? '',
        'platformSupported': false,
      };
    }
    
    return {
      'isRunning': await FlutterBackgroundService().isRunning(),
      'totalPackets': prefs.getInt('total_packets') ?? 0,
      'lastData': prefs.getString('last_data') ?? '',
      'lastReceived': prefs.getString('last_received') ?? '',
      'lastHeartbeat': prefs.getString('last_heartbeat') ?? '',
      'platformSupported': true,
    };
  }
}
