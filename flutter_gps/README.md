# ESP32-S3-Zero BLE Tracker Flutter App

A Flutter application designed to connect to and track data from an ESP32-S3-Zero BLE device (your custom AirTag).

## Features

- **BLE Device Discovery**: Automatically scans for and connects to your ESP32-S3-Zero device
- **Real-time Data Reception**: Receives GPS coordinates, timestamp, altitude, and RSSI data
- **Data Parsing**: Automatically parses the incoming data format: `MM/DD/YYYY, HH:MM:SS, Latitude, Longitude, Altitude, RSSI`
- **Connection Management**: Handles connection/disconnection with visual feedback
- **Data History**: Keeps track of received data with a history viewer
- **Visual Feedback**: LED status indicators based on connection state

## ESP32 Device Specifications

Your ESP32-S3-Zero device should:
- Advertise with name: `ESP32-S3-Zero`
- Use Service UUID: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- Use Characteristic UUID: `beb5483e-36e1-4688-b7f5-ea07361b26a8`
- Send data in format: `MM/DD/YYYY, HH:MM:SS, Latitude, Longitude, Altitude, RSSI`
- Transmit data at 1Hz (1 second intervals)

## State Machine Integration

The app is designed to work with your ESP32's 3-state machine:

1. **PAIR MODE**: Blue LED - Device is discoverable and ready for connection
2. **NORMAL MODE**: Purple LED - Connected and transmitting data normally
3. **LOST MODE**: Red LED - Connection issues, enhanced signaling

## Getting Started

### Prerequisites

- Flutter SDK installed
- Android device with BLE support
- Your ESP32-S3-Zero device programmed with the provided Arduino code

### Installation

1. Navigate to the flutter_gps directory:
   ```bash
   cd flutter_gps
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Build and install the APK:
   ```bash
   flutter build apk --release
   ```

4. Or run directly on connected device:
   ```bash
   flutter run
   ```

### Required Permissions

The app automatically requests these permissions:
- **Bluetooth**: For BLE scanning and connection
- **Location**: Required for BLE scanning on Android
- **Fine Location**: For precise location access

## Usage Instructions

### Step 1: Prepare Your ESP32 Device
1. Upload the provided Arduino code to your ESP32-S3-Zero
2. Power on the device - it should start in PAIR mode (blue LED)
3. The device should appear as "ESP32-S3-Zero" in BLE scans

### Step 2: Connect Using the App
1. Launch the Flutter app
2. Ensure Bluetooth is enabled on your phone
3. Tap "Connect to ESP32-S3-Zero" from the main screen
4. The app will navigate to the BLE scanner
5. Tap "Scan for ESP32-S3-Zero" button
6. The app will automatically connect when the device is found

### Step 3: Monitor Data
1. Once connected, you'll see:
   - Connection status (green background when connected)
   - Packet counter showing received data count
   - Latest GPS data in formatted display
   - Raw data log for troubleshooting

### Step 4: View Data History
1. Tap the "History" button to view all received data entries
2. Use "Clear" to reset the raw data log
3. The app maintains the last 50 data entries

## Data Format

The ESP32 sends data in this format:
```
MM/DD/YYYY, HH:MM:SS, Latitude, Longitude, Altitude, RSSI
```

Example:
```
12/28/2025, 14:30:25, 40.712800, -74.006000, 10.00, -45
```

## Troubleshooting

### Device Not Found
- Ensure ESP32 is powered and in PAIR mode (blue LED)
- Check that Bluetooth is enabled on your phone
- Grant location permissions (required for BLE on Android)
- Try refreshing Bluetooth status

### Connection Issues
- ESP32 will automatically go to LOST mode (red LED) if connection fails
- The app will attempt to reconnect automatically
- Use the Disconnect button and try reconnecting

### No Data Received
- Check that the ESP32 is in NORMAL mode (purple LED)
- Verify the ESP32 code is sending notifications
- Check the characteristic UUID matches exactly

### Permission Denied
- Go to Android Settings > Apps > [Your App] > Permissions
- Enable Location and Nearby Devices permissions

## Technical Details

### BLE Connection Parameters
- **Service UUID**: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- **Characteristic UUID**: `beb5483e-36e1-4688-b7f5-ea07361b26a8`
- **Connection Type**: GATT Client (app) to GATT Server (ESP32)
- **Data Method**: Characteristic Notifications
- **Scan Timeout**: 10 seconds
- **Connection Timeout**: 15 seconds

### Data Processing
- Raw BLE data is parsed into structured ESP32Data objects
- GPS coordinates are validated for proper ranges
- Distance calculations available using Haversine formula
- Data history limited to 50 entries for performance

## App Architecture

```
lib/
├── main.dart              # Main app entry point
├── bluetooth.dart         # BLE scanner and connection logic
├── esp32_data_parser.dart # Data parsing and validation
├── HomePage.dart          # Additional screens
└── map.dart              # Map integration (if needed)
```

## Future Enhancements

- Map integration to visualize GPS coordinates
- Data export functionality
- Connection quality metrics
- Multiple device support
- Background data logging

## Dependencies

- `flutter_blue_plus: ^1.35.5` - BLE functionality
- `geolocator: ^14.0.1` - Location services
- Standard Flutter widgets for UI

---

**Note**: This app is specifically designed for your ESP32-S3-Zero BLE tracking device. Make sure your ESP32 code matches the UUIDs and data format specified above.