# Location Sharing Feature Implementation

## Overview

This document describes the implementation of the location sharing feature that allows the Flutter app to send the phone's GPS coordinates to the ESP32 device every 2 seconds.

## Implementation Details

### 1. BLE Characteristics

The app now uses two BLE characteristics:

- **Data Characteristic** (`beb5483e-36e1-4688-b7f5-ea07361b26a8`): For receiving data FROM the ESP32
- **Receive Characteristic** (`beb5483e-36e1-4688-b7f5-ea07361b26a9`): For sending data TO the ESP32

### 2. Data Format

**Data sent to ESP32:**
```
MM/DD/YYYY, HH:MM:SS, Latitude, Longitude, Altitude
```

Example:
```
06/28/2025, 14:30:25, 40.712800, -74.006000, 10.00
```

**Note:** RSSI is not included in data sent to ESP32 as it will be determined locally by the ESP32.

### 3. Timing

- **Send Interval**: Every 2 seconds (phone → ESP32)
- **Receive Interval**: Every 1 second (ESP32 → phone)

### 4. Key Features

#### Automatic Location Sharing
- Starts automatically when connected to ESP32
- Stops automatically when disconnected
- Uses the phone's current GPS location
- Updates timestamp for each transmission

#### Visual Indicators
- "Sending location every 2s" status when active
- "Not sending location" warning when inactive but connected
- Upload icon indicator
- Manual "Send Now" button for testing

#### Error Handling
- Graceful handling of location permission issues
- Automatic retry on BLE write failures
- Proper cleanup when connection is lost

### 5. Code Changes

#### Files Modified:

1. **`lib/simple_home_screen.dart`**
   - Added `RECEIVE_CHAR_UUID` constant
   - Added `_sendCharacteristic` and `_sendDataTimer` fields
   - Implemented `_startSendingLocationData()` method
   - Implemented `_sendLocationToESP32()` method
   - Added automatic start/stop based on connection state
   - Enhanced UI with status indicators and manual send button

2. **`README.md`**
   - Updated feature list to include location transmission
   - Added documentation for both characteristics
   - Updated data format section
   - Added troubleshooting for location sharing

### 6. ESP32 Integration

The ESP32 code already supports receiving this data through:

```cpp
// Receive characteristic for getting data from phone
#define RECEIVE_CHAR_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a9"
```

The `parseReceivedPacket()` function processes the incoming data and stores it in the `receivedData` structure, which is then used by the ESP32 for its own GPS data transmissions.

### 7. Usage

1. **Connect to ESP32**: The app discovers and connects to the ESP32 device
2. **Automatic Start**: Location sharing begins automatically upon successful connection
3. **Status Monitoring**: Check the status indicator to confirm data is being sent
4. **Manual Testing**: Use the "Send Now" button to trigger immediate location transmission
5. **Automatic Stop**: Sharing stops when the device disconnects

### 8. Troubleshooting

- **Location Permissions**: Ensure the app has location permissions
- **BLE Connection**: Verify both characteristics are discovered
- **ESP32 Code**: Ensure ESP32 has the receive characteristic configured
- **Serial Monitor**: Check ESP32 serial output to see received packets

### 9. Technical Notes

- Data is sent without response for better performance
- Phone's altitude is included (if available from GPS)
- Timestamp uses phone's local time
- Location updates every 5 seconds, but transmission to ESP32 happens every 2 seconds
- ESP32 will use received data preferentially over its own placeholder GPS coordinates

This implementation ensures seamless two-way communication between the phone and ESP32, allowing the ESP32 to act as a more accurate tracking device by using the phone's GPS capabilities.
