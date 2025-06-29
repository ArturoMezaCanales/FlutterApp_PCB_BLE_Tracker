# FlutterApp_PCB_BLE_Tracker

A Flutter application for tracking GPS locations via Bluetooth Low Energy (BLE) communication with ESP32 devices.

## Features

### Core Functionality
- **BLE GPS Tracking**: Connect to ESP32 devices and exchange GPS location data
- **Real-time Mapping**: Interactive map showing both phone and ESP32 device locations
- **Bidirectional Communication**: Send phone location to ESP32 and receive ESP32 location data
- **Background Service**: Continue tracking even when app is in background
- **Demo Mode**: Test functionality without physical ESP32 device

### New: Compass Integration
- **Device Orientation**: Uses the device's built-in compass for highly accurate directional data
- **Directional Map Marker**: Phone location marker rotates to show current heading
- **Compass Display**: Real-time compass bearing shown in degrees and cardinal directions (N, NE, E, etc.)
- **Cross-platform Support**: Works on Android and iOS (Web version shows fallback icon)
- **Automatic Calibration**: No manual calibration needed - uses device's calibrated compass

## Technical Implementation

### Compass/Magnetometer
- Uses `flutter_compass` package for accurate compass readings
- Built-in device calibration and magnetic declination compensation
- No manual calibration required - leverages device's native compass
- Gracefully handles platforms where compass is not available
- Updates map marker with directional arrow icon that rotates based on device orientation

### Map Features
- Interactive map with zoom controls
- Auto-fit functionality to show both device locations
- Distance calculation between phone and ESP32
- Real-time location updates every 5 seconds
- Polyline connection between devices

## Getting Started

1. Clone the repository
2. Navigate to `flutter_gps` directory
3. Run `flutter pub get` to install dependencies
4. Connect an ESP32 device or use demo mode
5. Run the app with `flutter run`

## Dependencies

- `flutter_blue_plus`: BLE communication
- `geolocator`: GPS location services
- `flutter_map`: Interactive mapping
- `flutter_compass`: Device compass functionality
- Additional packages for background services and notifications