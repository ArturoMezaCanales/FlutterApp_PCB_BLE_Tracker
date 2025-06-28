# ESP32-S3-Zero BLE Connection Setup - Quick Guide

## What I've Done

I've modified your Flutter app to specifically connect to your ESP32-S3-Zero BLE device. Here are the key changes:

### 1. Updated `bluetooth.dart`
- **Targeted scanning**: Now specifically looks for "ESP32-S3-Zero" device
- **Automatic connection**: Connects automatically when device is found
- **Real-time data parsing**: Parses GPS data format from your ESP32
- **Connection management**: Handles connection states with visual feedback
- **Data history**: Tracks received data packets

### 2. Added `esp32_data_parser.dart`
- **Data structure**: Defines ESP32Data class for parsed GPS data
- **Format parsing**: Parses "MM/DD/YYYY, HH:MM:SS, Lat, Lon, Alt, RSSI" format
- **Validation**: Checks for valid GPS coordinates
- **Distance calculation**: Includes Haversine formula for distance calculations

### 3. Updated Android permissions
- **BLE permissions**: Added all necessary Bluetooth Low Energy permissions
- **Location permissions**: Required for BLE scanning on Android

### 4. Enhanced UI
- **Connection status**: Clear visual feedback for connection state
- **Live data display**: Shows latest parsed GPS data
- **Raw data log**: Displays raw received data for debugging
- **Data history viewer**: Browse through all received data packets

## How to Use

### Step 1: Prepare ESP32
1. Upload your Arduino code to ESP32-S3-Zero
2. Power on - should show blue LED (PAIR mode)

### Step 2: Use Flutter App
1. Run the app: `flutter run` or install APK
2. Tap "Connect to ESP32-S3-Zero" from main screen
3. Tap "Scan for ESP32-S3-Zero" button
4. App automatically connects when device found
5. Monitor real-time GPS data

### Data Flow
```
ESP32-S3-Zero → BLE Notifications → Flutter App → Parsed Display
     ↓
"12/28/2025, 14:30:25, 40.712800, -74.006000, 10.00, -45"
     ↓
Timestamp: 2025-12-28 14:30:25
Location: 40.712800, -74.006000  
Altitude: 10.00m
RSSI: -45dBm
```

## LED Status Meanings
- **Blue blinking**: PAIR mode - ready for connection
- **Purple blinking**: NORMAL mode - connected and transmitting
- **Red blinking**: LOST mode - connection issues

## Features
✅ Automatic device discovery and connection
✅ Real-time GPS data reception and parsing  
✅ Connection state management
✅ Data packet counting
✅ Raw data logging
✅ Parsed data history (last 50 entries)
✅ GPS coordinate validation
✅ Visual connection feedback

## Next Steps
- Test with your ESP32 device
- Verify data format matches expectations
- Consider adding map integration for GPS visualization
- Add data export functionality if needed

The app is now ready to connect to your ESP32-S3-Zero BLE tracker!
