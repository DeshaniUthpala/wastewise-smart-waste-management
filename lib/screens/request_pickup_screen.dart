import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../services/database_service.dart';
import '../models/pickup_request_model.dart';
import '../models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/citizen_page_header.dart';


class RequestPickupScreen extends StatefulWidget {
  const RequestPickupScreen({super.key});

  @override
  State<RequestPickupScreen> createState() => _RequestPickupScreenState();
}

class _RequestPickupScreenState extends State<RequestPickupScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _databaseService = DatabaseService();
  String _wasteType = 'General Waste';
  String _urgency = 'Normal';
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  // Location & Map State
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  bool _isLoadingLocation = false;
  final Set<Marker> _markers = {};
  
  // Default to Colombo, Sri Lanka if no location found
  static const LatLng _defaultLocation = LatLng(6.9271, 79.8612);

  final List<Map<String, dynamic>> _wasteTypes = [
    {'name': 'General Waste', 'icon': Icons.delete, 'color': Colors.grey},
    {'name': 'Recyclable', 'icon': Icons.recycling, 'color': Colors.blue},
    {'name': 'Organic', 'icon': Icons.eco, 'color': Colors.green},
    {'name': 'Hazardous', 'icon': Icons.warning, 'color': Colors.red},
    {'name': 'E-Waste', 'icon': Icons.electrical_services, 'color': Colors.orange},
  ];

  @override
  void dispose() {
    _notesController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled.';
      }

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

      setState(() {
        _selectedLocation = latLng;
        _markers.clear();
        _markers.add(
          Marker(
            markerId: const MarkerId('selected'),
            position: latLng,
            infoWindow: const InfoWindow(title: 'Pickup Location'),
          ),
        );
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 15),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  void _onMapTapped(LatLng position) {
    setState(() {
      _selectedLocation = position;
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('selected'),
          position: position,
          infoWindow: const InfoWindow(title: 'Pickup Location'),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.accentGreen.withValues(alpha: 0.1),
              AppColors.backgroundGreenTint,
            ],
          ),
        ),
        child: Column(
          children: [
            const CitizenPageHeader(
              title: 'Request Pickup',
              subtitle: 'Create a pickup request and share the exact location',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  _buildHeroCard(),
                  const SizedBox(height: 16),
                  _buildSectionTitle(
                    icon: Icons.place_outlined,
                    title: 'Pickup Location',
                    subtitle: 'Tap on map to pin your waste collection spot',
                  ),
                  const SizedBox(height: 10),
                  _buildSectionCard(
                    child: Container(
                      height: 250,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            GoogleMap(
                              initialCameraPosition: const CameraPosition(
                                target: _defaultLocation,
                                zoom: 12,
                              ),
                              markers: _markers,
                              onMapCreated: (controller) => _mapController = controller,
                              onTap: _onMapTapped,
                              myLocationEnabled: true,
                              myLocationButtonEnabled: false,
                            ),
                            if (_isLoadingLocation)
                              const Center(child: CircularProgressIndicator()),
                            Positioned(
                              top: 16,
                              left: 16,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Search location...',
                                    border: InputBorder.none,
                                    icon: Icon(Icons.search, color: Colors.grey[600]),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.clear, size: 20),
                                      onPressed: () {},
                                    ),
                                  ),
                                  style: const TextStyle(fontSize: 14),
                                  onSubmitted: (value) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Location search will be implemented'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 16,
                              right: 16,
                              child: FloatingActionButton(
                                mini: true,
                                backgroundColor: Colors.white,
                                onPressed: _getCurrentLocation,
                                child: const Icon(Icons.my_location, color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                   if (_selectedLocation == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Please select a location on the map',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 32),

                  _buildSectionTitle(
                    icon: Icons.recycling,
                    title: 'Select Waste Type',
                    subtitle: 'Choose the category to route your request correctly',
                  ),
                  const SizedBox(height: 10),
                  _buildSectionCard(
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: _wasteTypes.length,
                      itemBuilder: (context, index) {
                        final type = _wasteTypes[index];
                        final isSelected = _wasteType == type['name'];
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _wasteType = type['name'];
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? type['color']
                                    : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected
                                      ? type['color'].withValues(alpha: 0.3)
                                      : Colors.black.withValues(alpha: 0.05),
                                  blurRadius: isSelected ? 15 : 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: type['color'].withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    type['icon'],
                                    size: 40,
                                    color: type['color'],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  type['name'],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle(
                    icon: Icons.priority_high,
                    title: 'Urgency Level',
                    subtitle: 'Set priority so the team can handle urgent requests first',
                  ),
                  const SizedBox(height: 10),
                  _buildSectionCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildUrgencyButton('Normal', Icons.schedule, Colors.green),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildUrgencyButton('Urgent', Icons.priority_high, Colors.orange),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildUrgencyButton('Very Urgent', Icons.warning, Colors.red),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle(
                    icon: Icons.note_alt_outlined,
                    title: 'Additional Notes',
                    subtitle: 'Share access details or special instructions',
                  ),
                  const SizedBox(height: 10),
                  _buildSectionCard(
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: TextFormField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              hintText: 'Add any special instructions...',
                              prefixIcon: Icon(Icons.note_outlined),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(20),
                            ),
                            maxLines: 4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Your request will be processed within 24 hours',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.accentGreen, AppColors.hoverPressedGreen],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentGreen.withValues(alpha: 0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                          if (_formKey.currentState!.validate()) {
                            if (_selectedLocation == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please select a pickup location'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            try {
                              User? user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                setState(() => _isSubmitting = true);

                                final request = PickupRequestModel(
                                  citizenId: user.uid,
                                  location: LocationModel(
                                    latitude: _selectedLocation!.latitude,
                                    longitude: _selectedLocation!.longitude,
                                    address:
                                        'Lat: ${_selectedLocation!.latitude.toStringAsFixed(4)}, '
                                        'Lng: ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                                  ),
                                  wasteType: _wasteType,
                                  wasteCategory: _wasteType,
                                  status: 'pending',
                                  requestedDate: DateTime.now(),
                                  specialInstructions: _notesController.text.trim().isEmpty
                                      ? null
                                      : _notesController.text.trim(),
                                );

                                await _databaseService
                                    .createPickupRequest(request)
                                    .timeout(
                                      const Duration(seconds: 15),
                                      onTimeout: () => throw Exception(
                                        'Pickup request timed out. Please try again.',
                                      ),
                                    );

                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Row(
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.white),
                                        SizedBox(width: 12),
                                        Text('Pickup request submitted!'),
                                      ],
                                    ),
                                    backgroundColor: AppColors.accentGreen,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                                Navigator.pop(context);
                              } else {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('You must be logged in to request a pickup'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _isSubmitting = false);
                              }
                            }
                          }
                        },

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Submit Request',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgencyButton(String label, IconData icon, Color color) {
    final isSelected = _urgency == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _urgency = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF43A047),
            Color(0xFF2E7D32),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_shipping_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Submit pickup requests in a few steps and track updates from the admin team.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF2E7D32), size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF43A047).withValues(alpha: 0.15)),
      ),
      child: child,
    );
  }
}
