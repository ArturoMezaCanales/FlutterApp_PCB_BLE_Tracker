# Flutter BLE GPS Tracker - Simple Architecture (MVP)

## Overview

This document outlines a **minimal viable product (MVP)** for the Flutter BLE GPS Tracker that we can build incrementally, adding features one at a time.

## Simple Application Flow

```
App Startup → Connection Prompt → Home Screen (Map + Single Device Status)
```

## MVP Phase 1: Core Features Only

### 1. Connection Flow (Keep It Simple)

#### Launch Screen
- **Purpose**: Connect to ONE ESP32 device
- **Actions**: 
  - Scan for ESP32 devices
  - Show list of found devices
  - Tap to connect OR skip to enter app
- **Success**: Go to home screen
- **Skip**: Enter app without device (demo mode)

### 2. Home Screen (Single Device Focus)

#### Simple Layout
```
┌─────────────────────────────────────────┐
│              App Title                  │
├─────────────────────────────────────────┤
│                                         │
│              Map View                   │
│         (Shows 2 points only)          │
│       - Phone location (blue)          │
│       - ESP device (red)               │
│                                         │
├─────────────────────────────────────────┤
│         Single Device Status           │
│  📡 ESP32-Device        🟢 Connected    │
│  Signal: -45 dBm    Last: 2s ago       │
│  [🐛 Debug]                             │
└─────────────────────────────────────────┘
```

#### Core Components
1. **Map**: Shows phone + ESP device locations only
2. **Status Bar**: One device status with connection indicator
3. **Debug Button**: Access to existing packet viewer

## MVP Implementation Steps (Additive Development)

### Step 1: Basic Connection Screen
- Create simple connection prompt
- Scan and list ESP32 devices
- Connect to selected device OR skip

### Step 2: Simple Home Screen
- Basic map showing 2 points (phone + ESP)
- Simple status bar showing connection
- Debug button linking to existing interface

### Step 3: Real-time Updates
- Update map markers when new GPS data arrives
- Update connection status in real-time
- Use existing background service

### Step 4: Polish Basic Features
- Improve map controls (zoom, center)
- Better status indicators
- Error handling for disconnections

## Technical Requirements (MVP)

### Data Flow (Simple)
```
ESP32 → BLE Packets → Background Service → Map Updates + Status Bar
```

### Core Files Needed
1. **connection_screen.dart** - Initial device connection
2. **simple_home_screen.dart** - Map + status bar
3. **simple_map_widget.dart** - Basic map with 2 markers
4. Use existing: background service, debug screen, database

### Future Additions (After MVP)
- Multiple device support
- Device settings/renaming  
- Advanced map features
- Data export
- Analytics

## Why This Approach Works

### ✅ Additive Development Benefits
- **Start Small**: Get basic functionality working first
- **Test Early**: Validate core concept before adding complexity
- **Learn Fast**: Discover what users actually need
- **Less Risk**: Smaller changes = fewer bugs

### 🎯 MVP Success Criteria
1. User can connect to ESP32 device
2. Map shows phone and device locations
3. Real-time updates work
4. Debug interface accessible
5. App doesn't crash

### 🚀 Growth Path
Once MVP works, we can add:
- Second device support
- Device management features
- Map enhancements
- Data analysis tools
- Export capabilities

This simplified architecture focuses on getting the core experience right before adding advanced features.
