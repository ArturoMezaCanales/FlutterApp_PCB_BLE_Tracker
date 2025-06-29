import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class SimpleMapWidget extends StatefulWidget {
  final Position? phoneLocation;
  final Position? espLocation;
  final double? phoneHeading;  // Heading in degrees (0-360)

  const SimpleMapWidget({
    super.key,
    this.phoneLocation,
    this.espLocation,
    this.phoneHeading,
  });

  @override
  State<SimpleMapWidget> createState() => _SimpleMapWidgetState();
}

class _SimpleMapWidgetState extends State<SimpleMapWidget> {
  final MapController _mapController = MapController();
  double _currentZoom = 15.0;
  bool _hasAutoFitted = false; // Flag to track if we've already auto-fitted
  bool _userHasInteracted = false; // Flag to track if user has manually interacted with map

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitMapToLocations();
    });
  }

  @override
  void didUpdateWidget(SimpleMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only auto-fit on the first time we get both locations, not on every update
    if (!_hasAutoFitted && !_userHasInteracted) {
      bool hadBothLocations = oldWidget.phoneLocation != null && oldWidget.espLocation != null;
      bool nowHasBothLocations = widget.phoneLocation != null && widget.espLocation != null;
      
      // Auto-fit only when we first get both locations
      if (!hadBothLocations && nowHasBothLocations) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitMapToLocations();
        });
      }
    }
  }

  void _fitMapToLocations() {
    if (widget.phoneLocation != null && widget.espLocation != null) {
      // Calculate bounds for both locations
      final bounds = LatLngBounds.fromPoints([
        LatLng(widget.phoneLocation!.latitude, widget.phoneLocation!.longitude),
        LatLng(widget.espLocation!.latitude, widget.espLocation!.longitude),
      ]);
      
      // Add some padding to the bounds
      final paddedBounds = LatLngBounds(
        LatLng(
          bounds.south - 0.001, // Add padding
          bounds.west - 0.001,
        ),
        LatLng(
          bounds.north + 0.001,
          bounds.east + 0.001,
        ),
      );
      
      _mapController.fitCamera(CameraFit.bounds(bounds: paddedBounds));
      _hasAutoFitted = true; // Mark that we've auto-fitted
    } else if (widget.phoneLocation != null) {
      // Center on phone location
      _mapController.move(
        LatLng(widget.phoneLocation!.latitude, widget.phoneLocation!.longitude),
        16.0,
      );
      _hasAutoFitted = true;
    } else if (widget.espLocation != null) {
      // Center on ESP location
      _mapController.move(
        LatLng(widget.espLocation!.latitude, widget.espLocation!.longitude),
        16.0,
      );
      _hasAutoFitted = true;
    }
  }

  void _onMapEvent(MapEvent event) {
    // Track user interactions (pan, zoom, etc.)
    if (event is MapEventMove || event is MapEventFlingAnimationStart || 
        event is MapEventDoubleTapZoom || event is MapEventScrollWheelZoom) {
      _userHasInteracted = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Create markers for the map
    List<Marker> markers = [];
    
    if (widget.phoneLocation != null) {
      markers.add(
        Marker(
          point: LatLng(widget.phoneLocation!.latitude, widget.phoneLocation!.longitude),
          width: 60,
          height: 60,
          child: widget.phoneHeading != null 
            ? Transform.rotate(
                angle: (widget.phoneHeading! * 3.14159 / 180), // Convert degrees to radians
                child: const Icon(
                  Icons.navigation,  // Arrow icon that points in the direction
                  color: Colors.blue,
                  size: 35,
                ),
              )
            : const Icon(
                Icons.phone_android,
                color: Colors.blue,
                size: 30,
              ),
        ),
      );
    }
    
    if (widget.espLocation != null) {
      markers.add(
        Marker(
          point: LatLng(widget.espLocation!.latitude, widget.espLocation!.longitude),
          width: 50,
          height: 50,
          child: const Icon(
            Icons.device_hub,
            color: Colors.red,
            size: 30,
          ),
        ),
      );
    }
    
    // Create polyline connecting the two points
    List<Polyline> polylines = [];
    if (widget.phoneLocation != null && widget.espLocation != null) {
      polylines.add(
        Polyline(
          points: [
            LatLng(widget.phoneLocation!.latitude, widget.phoneLocation!.longitude),
            LatLng(widget.espLocation!.latitude, widget.espLocation!.longitude),
          ],
          color: Colors.orange,
          strokeWidth: 3.0,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Stack(
        children: [
          // FlutterMap widget
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.phoneLocation != null 
                ? LatLng(widget.phoneLocation!.latitude, widget.phoneLocation!.longitude)
                : widget.espLocation != null
                  ? LatLng(widget.espLocation!.latitude, widget.espLocation!.longitude)
                  : const LatLng(37.7749, -122.4194), // Default to San Francisco
              initialZoom: 15.0,
              minZoom: 3.0,
              maxZoom: 18.0,
              onPositionChanged: (position, hasGesture) {
                setState(() {
                  _currentZoom = position.zoom;
                });
                // Mark user interaction on gesture
                if (hasGesture) {
                  _userHasInteracted = true;
                }
              },
              onMapEvent: _onMapEvent,
            ),
            children: [
              // Tile layer (map tiles)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flutter_gps',
                maxZoom: 19,
              ),
              
              // Polylines (connection lines)
              PolylineLayer(
                polylines: polylines,
              ),
              
              // Markers layer
              MarkerLayer(
                markers: markers,
              ),
            ],
          ),
          
          // Map controls
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              children: [
                // Zoom in button
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () {
                      final newZoom = (_currentZoom + 1).clamp(3.0, 18.0);
                      _mapController.move(_mapController.camera.center, newZoom);
                    },
                    icon: const Icon(Icons.add),
                    tooltip: 'Zoom in',
                  ),
                ),
                const SizedBox(height: 8),
                
                // Zoom out button
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () {
                      final newZoom = (_currentZoom - 1).clamp(3.0, 18.0);
                      _mapController.move(_mapController.camera.center, newZoom);
                    },
                    icon: const Icon(Icons.remove),
                    tooltip: 'Zoom out',
                  ),
                ),
                const SizedBox(height: 8),
                
                // Auto-fit button
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () {
                      // Reset interaction flags and force auto-fit
                      _userHasInteracted = false;
                      _hasAutoFitted = false;
                      _fitMapToLocations();
                    },
                    icon: const Icon(Icons.center_focus_strong),
                    tooltip: 'Auto-fit map',
                  ),
                ),
              ],
            ),
          ),
          
          // Location info overlay
          if (widget.phoneLocation != null || widget.espLocation != null)
            Positioned(
              bottom: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.phoneLocation != null) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_android, color: Colors.blue, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Phone: ${widget.phoneLocation!.latitude.toStringAsFixed(6)}, ${widget.phoneLocation!.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      if (widget.phoneHeading != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.explore, color: Colors.blue, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Heading: ${widget.phoneHeading!.toStringAsFixed(0)}°',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ],
                    if (widget.espLocation != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.device_hub, color: Colors.red, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'ESP32: ${widget.espLocation!.latitude.toStringAsFixed(6)}, ${widget.espLocation!.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                    if (widget.phoneLocation != null && widget.espLocation != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Distance: ${_calculateDistance().toStringAsFixed(1)}m',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _calculateDistance() {
    if (widget.phoneLocation == null || widget.espLocation == null) return 0.0;
    
    return Geolocator.distanceBetween(
      widget.phoneLocation!.latitude,
      widget.phoneLocation!.longitude,
      widget.espLocation!.latitude,
      widget.espLocation!.longitude,
    );
  }
}
