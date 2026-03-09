import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../utils/app_colors.dart';

class AdminMapOverviewScreen extends StatefulWidget {
  const AdminMapOverviewScreen({super.key});

  @override
  State<AdminMapOverviewScreen> createState() => _AdminMapOverviewScreenState();
}

class _AdminMapOverviewScreenState extends State<AdminMapOverviewScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  String _selectedFilter = 'All';
  
  // Default to Colombo, Sri Lanka
  static const LatLng _defaultLocation = LatLng(6.9271, 79.8612);
  
  // Sample pickup requests (in a real app, this would come from Firebase)
  final List<Map<String, dynamic>> _pickupRequests = [
    {
      'id': '1',
      'address': '123 Main Street, Colombo',
      'wasteType': 'General Waste',
      'status': 'pending',
      'urgency': 'Normal',
      'location': const LatLng(6.9271, 79.8612),
      'userName': 'John Doe',
      'date': '2024-01-20',
    },
    {
      'id': '2',
      'address': '456 Galle Road, Colombo',
      'wasteType': 'Recyclable',
      'status': 'completed',
      'urgency': 'Normal',
      'location': const LatLng(6.9350, 79.8700),
      'userName': 'Jane Smith',
      'date': '2024-01-19',
    },
    {
      'id': '3',
      'address': '789 Kandy Road, Colombo',
      'wasteType': 'Organic',
      'status': 'in_progress',
      'urgency': 'Urgent',
      'location': const LatLng(6.9150, 79.8500),
      'userName': 'Mike Johnson',
      'date': '2024-01-20',
    },
    {
      'id': '4',
      'address': '321 Negombo Road',
      'wasteType': 'Hazardous',
      'status': 'pending',
      'urgency': 'Very Urgent',
      'location': const LatLng(6.9400, 79.8550),
      'userName': 'Sarah Wilson',
      'date': '2024-01-20',
    },
    {
      'id': '5',
      'address': '555 Station Road, Colombo',
      'wasteType': 'E-Waste',
      'status': 'pending',
      'urgency': 'Normal',
      'location': const LatLng(6.9200, 79.8650),
      'userName': 'David Brown',
      'date': '2024-01-20',
    },
  ];

  @override
  void initState() {
    super.initState();
    _createMarkers();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _createMarkers() {
    _markers.clear();
    
    var filteredRequests = _pickupRequests;
    if (_selectedFilter != 'All') {
      filteredRequests = _pickupRequests
          .where((req) => req['status'] == _selectedFilter.toLowerCase())
          .toList();
    }
    
    for (var request in filteredRequests) {
      final hue = _getMarkerColor(request['status']);
      _markers.add(
        Marker(
          markerId: MarkerId(request['id']),
          position: request['location'],
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          onTap: () => _showRequestDetails(request),
          infoWindow: InfoWindow(
            title: request['wasteType'],
            snippet: '${request['status']} • ${request['urgency']}',
          ),
        ),
      );
    }
    setState(() {});
  }

  double _getMarkerColor(String status) {
    switch (status) {
      case 'pending':
        return BitmapDescriptor.hueRed;
      case 'in_progress':
        return BitmapDescriptor.hueOrange;
      case 'completed':
        return BitmapDescriptor.hueGreen;
      default:
        return BitmapDescriptor.hueRed;
    }
  }

  void _showRequestDetails(Map<String, dynamic> request) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Title
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: AppColors.accentGreen,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      request['wasteType'],
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusChip(request['status']),
                ],
              ),
              const SizedBox(height: 20),
              
              // Details
              _buildDetailRow(Icons.person, 'Citizen', request['userName']),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.location_city, 'Address', request['address']),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.priority_high, 'Urgency', request['urgency']),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.calendar_today, 'Date', request['date']),
              
              const SizedBox(height: 24),
              
              // Actions
              if (request['status'] != 'completed')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Assign driver feature coming soon')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.assignment),
                    label: const Text(
                      'Assign Driver',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 20),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;
    
    switch (status) {
      case 'pending':
        color = Colors.red;
        text = 'Pending';
        break;
      case 'in_progress':
        color = Colors.orange;
        text = 'In Progress';
        break;
      case 'completed':
        color = Colors.green;
        text = 'Completed';
        break;
      default:
        color = Colors.grey;
        text = status;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int pending = _pickupRequests.where((r) => r['status'] == 'pending').length;
    int inProgress = _pickupRequests.where((r) => r['status'] == 'in_progress').length;
    int completed = _pickupRequests.where((r) => r['status'] == 'completed').length;

    return Scaffold(
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _defaultLocation,
              zoom: 12,
            ),
            markers: _markers,
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          
          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.accentGreen, const Color(0xFF2E7D32)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pickup Requests Map',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'All citizen pickup locations',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Filter Chips
          Positioned(
            top: 120,
            left: 16,
            right: 16,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', _pickupRequests.length),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pending', pending),
                  const SizedBox(width: 8),
                  _buildFilterChip('In_progress', inProgress),
                  const SizedBox(width: 8),
                  _buildFilterChip('Completed', completed),
                ],
              ),
            ),
          ),
          
          // Bottom Info Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag Handle
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Stats
                      const Text(
                        'Request Statistics',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard('Total', _pickupRequests.length.toString(), Colors.blue),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard('Pending', pending.toString(), Colors.red),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard('Active', inProgress.toString(), Colors.orange),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard('Done', completed.toString(), Colors.green),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = label;
          _createMarkers();
        });
      },
      backgroundColor: Colors.white,
      selectedColor: AppColors.accentGreen.withOpacity(0.2),
      checkmarkColor: AppColors.accentGreen,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.accentGreen : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.accentGreen : Colors.grey[300]!,
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
