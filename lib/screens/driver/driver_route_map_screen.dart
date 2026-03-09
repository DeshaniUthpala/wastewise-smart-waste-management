import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/database_service.dart';
import '../../models/pickup_request_model.dart';

class DriverRouteMapScreen extends StatefulWidget {
  const DriverRouteMapScreen({super.key});

  @override
  State<DriverRouteMapScreen> createState() => _DriverRouteMapScreenState();
}

class _DriverRouteMapScreenState extends State<DriverRouteMapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  LatLng? _currentLocation;
  bool _isLoadingLocation = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<List<PickupRequestModel>>? _requestsSubscription;

  final DatabaseService _dbService = DatabaseService();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  List<PickupRequestModel> _driverRequests = [];
  String? _updatingRequestId;

  static const LatLng _defaultLocation = LatLng(6.9271, 79.8612);

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _listenToDriverRequests();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _stopLocationUpdates();
    _requestsSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _listenToDriverRequests() {
    if (_uid == null) return;
    _requestsSubscription = _dbService
        .getPickupRequestsStream(driverId: _uid)
        .listen((requests) async {
      if (!mounted) return;
      setState(() {
        _driverRequests = requests;
      });
      _rebuildMapOverlays();
      await _fitCameraToRoute();
    });
  }

  void _rebuildMapOverlays() {
    final markers = <Marker>{};
    final lines = <Polyline>{};

    final sorted = [..._driverRequests]
      ..sort((a, b) => a.requestedDate.compareTo(b.requestedDate));

    final routePoints = <LatLng>[];
    for (int i = 0; i < sorted.length; i++) {
      final req = sorted[i];
      final point = LatLng(req.location.latitude, req.location.longitude);
      routePoints.add(point);

      final markerHue = req.status == 'completed'
          ? BitmapDescriptor.hueGreen
          : req.status == 'in_progress'
              ? BitmapDescriptor.hueAzure
              : BitmapDescriptor.hueRed;

      markers.add(
        Marker(
          markerId: MarkerId(req.id ?? 'req_$i'),
          position: point,
          icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
          infoWindow: InfoWindow(
            title: 'Stop ${i + 1}: ${req.location.address ?? 'Pickup Location'}',
            snippet: '${req.wasteType} • ${req.status}',
          ),
        ),
      );
    }

    if (_currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    }

    if (routePoints.length >= 2) {
      lines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: routePoints,
          color: Colors.blue,
          width: 5,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _markers
        ..clear()
        ..addAll(markers);
      _polylines
        ..clear()
        ..addAll(lines);
    });
  }

  Future<void> _fitCameraToRoute() async {
    if (_mapController == null || _driverRequests.isEmpty) return;
    final points = _driverRequests
        .map((r) => LatLng(r.location.latitude, r.location.longitude))
        .toList();

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60,
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Location services are disabled.';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied.';
      }

      Position position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);
      _updateMapLocation(latLng);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _startLocationUpdates() {
    if (_uid == null) return;
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    _dbService.setDriverOnlineStatus(_uid, true);

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        final latLng = LatLng(position.latitude, position.longitude);
        _updateMapLocation(latLng);
        _dbService.updateDriverLocation(_uid, position.latitude, position.longitude);
      },
      onError: (e) => debugPrint('Location Stream Error: $e'),
    );
  }

  void _stopLocationUpdates() {
    _positionStreamSubscription?.cancel();
    if (_uid != null) _dbService.setDriverOnlineStatus(_uid, false);
  }

  void _updateMapLocation(LatLng latLng) {
    if (!mounted) return;
    setState(() => _currentLocation = latLng);
    _rebuildMapOverlays();
  }

  Future<void> _markPickupCompleted(PickupRequestModel request) async {
    if (request.id == null || request.id!.isEmpty) return;
    if (_updatingRequestId != null) return;

    setState(() => _updatingRequestId = request.id);
    try {
      await _dbService.updatePickupStatus(request.id!, 'completed');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pickup marked as completed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to complete pickup: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _updatingRequestId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completedStops = _driverRequests.where((r) => r.status.toLowerCase().trim() == 'completed').length;
    final totalStops = _driverRequests.length;
    final pendingStops = totalStops - completedStops;
    final pendingRequests = _driverRequests
        .where((r) => r.status.toLowerCase().trim() != 'completed')
        .toList()
      ..sort((a, b) => a.requestedDate.compareTo(b.requestedDate));

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _defaultLocation,
              zoom: 12,
            ),
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            padding: const EdgeInsets.only(bottom: 300),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 60, bottom: 40, left: 16, right: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0F172A).withOpacity(0.95),
                    const Color(0xFF0F172A).withOpacity(0.85),
                    const Color(0xFF0F172A).withOpacity(0.0),
                  ],
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Navigation Room',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'LIVE TRACKING ON',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.radar_rounded, color: Color(0xFF10B981), size: 24),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.15),
                    blurRadius: 40,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _improvedStatCard('TOTAL', '$totalStops', Icons.flag_rounded, const Color(0xFF6366F1)),
                        const SizedBox(width: 12),
                        _improvedStatCard('DONE', '$completedStops', Icons.check_circle_rounded, const Color(0xFF10B981)),
                        const SizedBox(width: 12),
                        _improvedStatCard('PENDING', '$pendingStops', Icons.hourglass_top_rounded, const Color(0xFFF59E0B)),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Upcoming Stops',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Color(0xFF0F172A)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$pendingStops REMAINING',
                            style: TextStyle(color: Colors.grey[600], fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (pendingRequests.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFDCFCE7)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.celebration_rounded, color: Color(0xFF10B981), size: 40),
                            const SizedBox(height: 12),
                            const Text(
                              'Mission Accomplished!',
                              style: TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.w900, fontSize: 18),
                            ),
                            Text(
                              'All pickups for today are completed.',
                              style: TextStyle(color: const Color(0xFF166534).withOpacity(0.7), fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        height: 180,
                        child: ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: pendingRequests.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final req = pendingRequests[index];
                            final isUpdating = _updatingRequestId == req.id;
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: const Color(0xFFF1F5F9)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A))),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          req.location.address ?? 'Stop Location',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                                        ),
                                        Text(
                                          'Waste: ${req.wasteType}',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    onPressed: isUpdating ? null : () => _markPickupCompleted(req),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F172A),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    child: isUpdating
                                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Text('DONE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 310,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'loc_btn',
              backgroundColor: Colors.white,
              elevation: 4,
              onPressed: _getCurrentLocation,
              child: _isLoadingLocation
                  ? const CircularProgressIndicator(strokeWidth: 3)
                  : const Icon(Icons.my_location_rounded, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _improvedStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.15), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color.withOpacity(0.7),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
