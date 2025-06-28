import 'dart:math' as math;

class ESP32Data {
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double altitude;
  final int rssi;

  ESP32Data({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.rssi,
  });

  static ESP32Data? parseFromString(String data) {
    try {
      // Expected format: "MM/DD/YYYY, HH:MM:SS, Latitude, Longitude, Altitude, RSSI"
      List<String> parts = data.split(', ');
      
      if (parts.length != 6) {
        print('Invalid data format: expected 6 parts, got ${parts.length}');
        return null;
      }

      // Parse date and time
      String dateStr = parts[0]; // MM/DD/YYYY
      String timeStr = parts[1]; // HH:MM:SS

      List<String> dateParts = dateStr.split('/');
      List<String> timeParts = timeStr.split(':');

      if (dateParts.length != 3 || timeParts.length != 3) {
        print('Invalid date/time format');
        return null;
      }

      int month = int.parse(dateParts[0]);
      int day = int.parse(dateParts[1]);
      int year = int.parse(dateParts[2]);
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      int second = int.parse(timeParts[2]);

      DateTime timestamp = DateTime(year, month, day, hour, minute, second);

      // Parse coordinates
      double latitude = double.parse(parts[2]);
      double longitude = double.parse(parts[3]);
      double altitude = double.parse(parts[4]);
      int rssi = int.parse(parts[5]);

      return ESP32Data(
        timestamp: timestamp,
        latitude: latitude,
        longitude: longitude,
        altitude: altitude,
        rssi: rssi,
      );
    } catch (e) {
      print('Error parsing ESP32 data: $e');
      return null;
    }
  }

  String toFormattedString() {
    return '''
Timestamp: ${timestamp.toString()}
Location: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}
Altitude: ${altitude.toStringAsFixed(2)}m
RSSI: ${rssi}dBm
''';
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'rssi': rssi,
    };
  }

  bool isValidGPSLocation() {
    // Check if coordinates are within valid ranges
    return latitude >= -90 && latitude <= 90 && 
           longitude >= -180 && longitude <= 180;
  }

  double distanceFromLocation(double lat, double lon) {
    // Simple distance calculation (Haversine formula simplified)
    const double earthRadius = 6371000; // meters
    double latDiff = (lat - latitude) * (math.pi / 180);
    double lonDiff = (lon - longitude) * (math.pi / 180);
    
    double a = math.pow(math.sin(latDiff / 2), 2) + 
               math.pow(math.sin(lonDiff / 2), 2) * 
               math.cos(latitude * math.pi / 180) * 
               math.cos(lat * math.pi / 180);
    
    double c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }
}
