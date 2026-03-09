import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../models/report_model.dart';
import '../models/user_model.dart';
import '../widgets/citizen_page_header.dart';
import 'package:image_picker/image_picker.dart';


class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  String _issueType = 'Overflowing Bin';
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  bool _hasImage = false;
  XFile? _imageFile;
  bool _isSubmitting = false;
  final DatabaseService _databaseService = DatabaseService();
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  // Map State
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  bool _isLoadingLocation = false;
  final Set<Marker> _markers = {};
  static const LatLng _defaultLocation = LatLng(6.9271, 79.8612); // Colombo, Sri Lanka

  final List<Map<String, dynamic>> _issueTypes = [
    {
      'type': 'Overflowing Bin',
      'icon': Icons.delete_sweep_rounded,
      'color': const Color(0xFFEF5350),
      'gradient': [Color(0xFFEF5350), Color(0xFFE53935)],
    },
    {
      'type': 'Missed Collection',
      'icon': Icons.calendar_today_rounded,
      'color': const Color(0xFF42A5F5),
      'gradient': [Color(0xFF42A5F5), Color(0xFF1976D2)],
    },
    {
      'type': 'Illegal Dumping',
      'icon': Icons.warning_rounded,
      'color': const Color(0xFFFF9800),
      'gradient': [Color(0xFFFF9800), Color(0xFFF57C00)],
    },
    {
      'type': 'Damaged Bin',
      'icon': Icons.build_rounded,
      'color': const Color(0xFF8D6E63),
      'gradient': [Color(0xFF8D6E63), Color(0xFF5D4037)],
    },
    {
      'type': 'Hazardous Waste',
      'icon': Icons.dangerous_rounded,
      'color': const Color(0xFFAB47BC),
      'gradient': [Color(0xFFAB47BC), Color(0xFF7B1FA2)],
    },
    {
      'type': 'Other Issue',
      'icon': Icons.report_problem_rounded,
      'color': const Color(0xFF78909C),
      'gradient': [Color(0xFF78909C), Color(0xFF546E7A)],
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _animationController.dispose();
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
        _locationController.text = 'Lat: ${latLng.latitude.toStringAsFixed(4)}, Lng: ${latLng.longitude.toStringAsFixed(4)}';
        _markers.clear();
        _markers.add(
          Marker(
            markerId: const MarkerId('selected'),
            position: latLng,
            infoWindow: const InfoWindow(title: 'Report Location'),
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
      _locationController.text = 'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}';
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('selected'),
          position: position,
          infoWindow: const InfoWindow(title: 'Report Location'),
        ),
      );
    });
  }

  void _submitReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select the issue location on the map'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      String? imageUrl;
      String? imageUploadWarning;
      if (_imageFile != null) {
        final path = 'report_images/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        try {
          imageUrl = await _databaseService
              .uploadImage(_imageFile!, path)
              .timeout(
                const Duration(seconds: 25),
                onTimeout: () => throw Exception('Image upload timed out'),
              );
        } catch (e) {
          // Do not block issue reporting because of optional photo failures.
          imageUrl = null;
          String errorMsg = e.toString();
          if (errorMsg.contains('permission-denied')) {
            imageUploadWarning = 'Photo upload failed: Permission Denied. Check Firebase Storage rules.';
          } else if (errorMsg.contains('object-not-found')) {
            imageUploadWarning = 'Photo upload failed: Storage not initialized.';
          } else {
            imageUploadWarning = 'Photo upload failed: $e. Report sent without photo.';
          }
        }
      }

      final report = ReportModel(
        reporterId: user.uid,
        title: _issueType,
        description: _descriptionController.text.trim(),
        type: _issueType.toLowerCase().replaceAll(' ', '_'),
        priority: _issueType == 'Hazardous Waste' ? 'high' : 'medium',
        status: 'open',
        location: LocationModel(
          latitude: _selectedLocation!.latitude,
          longitude: _selectedLocation!.longitude,
          address: _locationController.text.trim(),
        ),
        imageUrls: imageUrl != null ? [imageUrl] : null,
        createdAt: DateTime.now(),
      );

      await _databaseService
          .createReport(report)
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw Exception('Report submission timed out. Please try again.'),
          );

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });

      if (imageUploadWarning != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(imageUploadWarning),
            backgroundColor: Colors.orange,
          ),
        );
      }

      _showSuccessDialog();

      _formKey.currentState!.reset();
      setState(() {
        _hasImage = false;
        _imageFile = null;
        _issueType = 'Overflowing Bin';
        _selectedLocation = null;
        _markers.clear();
      });
      _descriptionController.clear();
      _locationController.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: child,
            ),
          );
        },
        child: Column(
          children: [
            const CitizenPageHeader(
              title: 'Report Issue',
              subtitle: 'Help us maintain a cleaner environment by reporting issues',
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Issue Type Selection with Modern Cards
                      _buildSectionTitle('Issue Type', Icons.category_rounded),
                      const SizedBox(height: 20),
                      
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _issueTypes.map((type) {
                          final isSelected = _issueType == type['type'];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _issueType = type['type'] as String;
                              });
                            },
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 300),
                              width: (MediaQuery.of(context).size.width - 52) / 2,
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? LinearGradient(
                                        colors: type['gradient'] as List<Color>,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: isSelected ? null : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  if (isSelected)
                                    BoxShadow(
                                      color: (type['color'] as Color).withOpacity(0.4),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    )
                                  else
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                ],
                                border: isSelected
                                    ? null
                                    : Border.all(
                                        color: Colors.grey.shade200,
                                        width: 1.5,
                                      ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white.withOpacity(0.2)
                                            : (type['color'] as Color).withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        type['icon'] as IconData,
                                        color: isSelected ? Colors.white : type['color'] as Color,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      type['type'] as String,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 32),

                      // Location with Modern Card
                      _buildSectionTitle('Location', Icons.location_on_rounded),
                      const SizedBox(height: 20),
                      
                      // Map Container
                      Container(
                        height: 250,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
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
                              
                              // Search Bar
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
                                        color: Colors.black.withOpacity(0.1),
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
                                        onPressed: () {
                                          // Clear search field
                                        },
                                      ),
                                    ),
                                    style: const TextStyle(fontSize: 14),
                                    onSubmitted: (value) {
                                      // Implement search functionality
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
                              
                              // My Location Button
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
                      if (_selectedLocation == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Please select a location on the map',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),

                      const SizedBox(height: 32),

                      // Description with Modern Card - FIXED LAYOUT
                      _buildSectionTitle('Description', Icons.description_rounded),
                      const SizedBox(height: 20),
                      
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.white, Colors.grey.shade50],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 6),
                                        TextFormField(
                                          controller: _descriptionController,
                                          decoration: InputDecoration(
                                            hintText: 'Provide specific details about the issue...',
                                            hintStyle: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 14,
                                            ),
                                            border: InputBorder.none,
                                          ),
                                          maxLines: 5,
                                          style: const TextStyle(
                                            fontSize: 15,
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Please describe the issue';
                                            }
                                            if (value.length < 20) {
                                              return 'Please provide more details (min. 20 characters)';
                                            }
                                            return null;
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '📝 Tips for better description:',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.purple.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ...['Be specific about the location', 'Mention time if applicable', 'Note any safety concerns', 'Include relevant details']
                                        .map((tip) => Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Icon(Icons.circle, size: 6, color: Colors.purple.shade400),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  tip,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ))
                                        .toList(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Photo Upload with Modern Card
                      _buildSectionTitle('Photo Evidence', Icons.camera_alt_rounded),
                      const SizedBox(height: 20),
                      
                      InkWell(
                        onTap: () => _pickImage(context),
                        borderRadius: BorderRadius.circular(24),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          height: 180,
                          decoration: BoxDecoration(
                            gradient: _hasImage
                                ? LinearGradient(
                                    colors: [
                                      Colors.green.shade100,
                                      Colors.green.shade50,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : LinearGradient(
                                    colors: [
                                      const Color.fromARGB(255, 255, 255, 255),
                                      const Color.fromARGB(255, 255, 255, 255),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: _hasImage ? Colors.green.shade300 : Colors.orange.shade300,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: _hasImage ? Colors.green : Colors.orange,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _hasImage ? Icons.check : Icons.camera_alt_rounded,
                                        color: Colors.white,
                                        size: 36,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _hasImage ? 'Photo Added' : 'Add Photo',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: _hasImage ? Color(0xFF1B5E20) : Color(0xFFE65100),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _hasImage ? 'Tap to change photo' : 'Optional - Helps us understand better',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_hasImage)
                                Positioned(
                                  top: 16,
                                  right: 16,
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.edit_rounded,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Submit Button with Animation
                      _isSubmitting
                          ? Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.accentGreen.withOpacity(0.1),
                                    AppColors.accentGreen.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.accentGreen.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: AppColors.accentGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    'Submitting Report...',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1B5E20),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _submitReport,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentGreen,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 22),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: 0,
                                  shadowColor: AppColors.accentGreen.withOpacity(0.5),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.send_rounded, size: 24),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'SUBMIT REPORT',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                      const SizedBox(height: 40),
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

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.accentGreen,
                Color(0xFF2E7D32),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentGreen.withOpacity(0.3),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
  Future<void> _pickImage(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    
    // Show selection dialog for Camera or Gallery
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 70,
    );
    
    if (image != null) {
      setState(() {
        _imageFile = image;
        _hasImage = true;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green.shade600,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Report Submitted!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Thank you for reporting this issue. We will review it shortly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
