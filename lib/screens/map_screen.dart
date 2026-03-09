import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/app_colors.dart';
import '../widgets/citizen_page_header.dart';
import '../services/database_service.dart';
import 'dart:ui' as ui;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  final Map<MarkerId, Marker> _markers = {};
  StreamSubscription? _locationSubscription;
  BitmapDescriptor? _truckIcon;
  LatLng? _currentPosition;
  bool _isLoading = true;

  // Default location (Colombo, Sri Lanka)
  static const CameraPosition _kInitial = CameraPosition(
    target: LatLng(6.9271, 79.8612),
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _initMapResources();
    _startTracking();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initMapResources() async {
    try {
      final Uint8List markerIcon = await _getBytesFromAsset('assets/images/truck-.png', 120);
      if (mounted) {
        setState(() {
          _truckIcon = BitmapDescriptor.fromBytes(markerIcon);
        });
      }
    } catch (e) {
      debugPrint('Error loading truck icon: $e');
    }
    
    // Get initial position
    try {
      Position position = await _determinePosition();
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });
        final GoogleMapController controller = await _controller.future;
        controller.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition!, 15));
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Uint8List> _getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Location services are disabled.');

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return Future.error('Location permissions are denied');
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    return await Geolocator.getCurrentPosition();
  }

  void _startTracking() {
    _locationSubscription = DatabaseService().getDriverLocationsStream().listen((locations) {
      if (!mounted) return;
      _updateDriverMarkers(locations);
    });
  }

  void _updateDriverMarkers(Map<String, dynamic> locations) {
    final Map<MarkerId, Marker> newMarkers = {};
    
    locations.forEach((driverId, data) {
      if (data is! Map) return;
      
      final isOnline = data['isOnline'] ?? false;
      if (!isOnline) return;

      final lat = data['latitude'] as double?;
      final lng = data['longitude'] as double?;
      
      if (lat != null && lng != null) {
        final markerId = MarkerId(driverId);
        newMarkers[markerId] = Marker(
          markerId: markerId,
          position: LatLng(lat, lng),
          icon: _truckIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'Waste Collection Truck',
            snippet: 'Status: Online',
          ),
        );
      }
    });

    setState(() {
      _markers.clear();
      _markers.addAll(newMarkers);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const CitizenPageHeader(
            title: 'Live Tracking',
            subtitle: 'Real-time waste collection status',
          ),
          Expanded(
            child: Stack(
              children: [
                _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : GoogleMap(
                      mapType: MapType.normal,
                      initialCameraPosition: _kInitial,
                      onMapCreated: (GoogleMapController controller) {
                        _controller.complete(controller);
                      },
                      markers: Set<Marker>.of(_markers.values),
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                    ),
                
                // Active Trucks Status
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_markers.length} Active Trucks',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Positioned(
                  bottom: 24,
                  left: 20,
                  right: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.accentGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.local_shipping_rounded,
                                  color: AppColors.accentGreen,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Collection Services',
                                      style: TextStyle(
                                        fontWeight: ui.FontWeight.w900,
                                        fontSize: 18,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                    Text(
                                      'Tracking live trucks near you',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF6B7280),
                                        fontWeight: ui.FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.my_location_rounded, color: Colors.blue),
                                onPressed: () async {
                                  final controller = await _controller.future;
                                  if (_currentPosition != null) {
                                    controller.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition!, 16));
                                  }
                                },
                              ),
                            ],
                          ),
                          if (_markers.isEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, color: Colors.amber.shade800, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'No collection trucks are currently active in your area.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.amber.shade900,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
