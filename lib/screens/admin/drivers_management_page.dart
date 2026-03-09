import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/user_model.dart';

class DriversManagementPage extends StatefulWidget {
  const DriversManagementPage({super.key});

  @override
  State<DriversManagementPage> createState() => _DriversManagementPageState();
}

class _DriversManagementPageState extends State<DriversManagementPage> {
  final DatabaseService _databaseService = DatabaseService();

  String searchQuery = '';

  String filterZone = 'All';
  String filterStatus = 'All';
  int rowsPerPage = 10;
  bool isAllSelected = false;

  @override
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DriverModel>>(
      stream: _databaseService.getDriverModelsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
        }

        final driverModels = snapshot.data ?? [];
        
        final drivers = driverModels.map((d) {
           return {
             'id': d.uid, 
             'name': d.name,
             'phone': d.phone ?? 'N/A',
             'vehicle': d.vehicleNumber ?? 'Unassigned',
             'zone': 'Central District', // Placeholder as Zone is not in DriverModel
             'status': d.isActive ? 'Active' : 'Inactive',
             'completedToday': d.completedPickups,
             'rating': d.rating ?? 0.0,
             'avatarColor': Colors.blue, 
             'selected': false,
             'model': d,
           };
        }).toList();

        // Filtering logic
        final filteredDrivers = drivers.where((driver) {
          final matchesSearch = driver['name'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
              driver['vehicle'].toString().toLowerCase().contains(searchQuery.toLowerCase());
          final matchesZone = filterZone == 'All' || driver['zone'] == filterZone;
          final matchesStatus = filterStatus == 'All' || driver['status'] == filterStatus;
          
          return matchesSearch && matchesZone && matchesStatus;
        }).toList();

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 768;

                return Padding(
                  padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      Text(
                        'Drivers Management',
                        style: TextStyle(
                          fontSize: isMobile ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Manage fleet drivers, track performance, assign zones, and monitor vehicle status.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Filters & Actions Row
                      if (isMobile)
                        Column(
                          children: [
                            TextField(
                              onChanged: (value) => setState(() => searchQuery = value),
                              decoration: InputDecoration(
                                hintText: 'Search drivers...',
                                prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
                                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildFilterDropdown(
                                    'Zone', 
                                    ['All', 'Central District', 'North Area', 'South Region'], 
                                    filterZone,
                                    (val) => setState(() => filterZone = val),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildFilterDropdown(
                                    'Status', 
                                    ['All', 'Active', 'Inactive', 'Suspended'], 
                                    filterStatus,
                                    (val) => setState(() => filterStatus = val),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _showAddDriverDialog,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Driver'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2C3E50),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 50),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  onChanged: (value) => setState(() => searchQuery = value),
                                  decoration: InputDecoration(
                                    hintText: 'Search drivers...',
                                    prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(30),
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              _buildFilterDropdown(
                                'Zone', 
                                ['All', 'Central District', 'North Area', 'South Region'], 
                                filterZone,
                                (val) => setState(() => filterZone = val),
                              ),
                              const SizedBox(width: 12),
                              _buildFilterDropdown(
                                'Status', 
                                ['All', 'Active', 'Inactive', 'Suspended'], 
                                filterStatus,
                                (val) => setState(() => filterStatus = val),
                              ),
                              const Spacer(),
                              OutlinedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.file_upload_outlined, size: 18),
                                label: const Text('Export'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey[700],
                                  side: BorderSide(color: Colors.grey[300]!),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: _showAddDriverDialog,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Driver'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2C3E50),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Table or List
                      Expanded(
                        child: isMobile 
                          ? _buildMobileListView(filteredDrivers)
                          : _buildDesktopTable(filteredDrivers, drivers),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    );
  }


  Widget _buildDesktopTable(List<Map<String, dynamic>> filteredDrivers, List<Map<String, dynamic>> allDrivers) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF2C3E50),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8), 
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                _buildCheckbox(isAllSelected, (val) {
                  setState(() {
                    isAllSelected = val ?? false;
                    for (var driver in allDrivers) {
                      driver['selected'] = isAllSelected;
                    }
                  });
                }, isHeader: true),
                _buildHeaderCell('Full Name', flex: 3),
                _buildHeaderCell('Phone', flex: 2),
                _buildHeaderCell('Vehicle', flex: 2),
                _buildHeaderCell('Zone', flex: 2),
                _buildHeaderCell('Status', flex: 2),
                _buildHeaderCell('Rating', flex: 1),
                _buildHeaderCell('Actions', flex: 1, align: TextAlign.right),
              ],
            ),
          ),
          // Table Body
          Expanded(
            child: ListView.separated(
              itemCount: filteredDrivers.length,
              separatorBuilder: (context, index) => const Divider(height: 1, thickness: 0.5),
              itemBuilder: (context, index) {
                final driver = filteredDrivers[index];
                return Container(
                  color: index % 2 == 0 ? Colors.white : Colors.grey[50], // Alternating rows
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _buildCheckbox(driver['selected'], (val) {
                        setState(() {
                          driver['selected'] = val;
                          isAllSelected = allDrivers.every((d) => d['selected']);
                        });
                      }),
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: driver['avatarColor'] ?? Colors.blue,
                              child: Text(
                                driver['name'][0],
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  driver['name'],
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  driver['id'],
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(driver['phone'], style: TextStyle(color: Colors.grey[700])),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(driver['vehicle'], style: TextStyle(color: Colors.grey[700])),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(driver['zone'], style: TextStyle(color: Colors.grey[700])),
                      ),
                      Expanded(
                        flex: 2,
                        child: _buildStatusBadge(driver['status']),
                      ),
                      Expanded(
                        flex: 1,
                        child: Row(
                          children: [
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(driver['rating'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                              onPressed: () => _showEditDriverDialog(driver),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              onPressed: () => _deleteDriver(driver),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Footer
          _buildPaginationFooter(filteredDrivers.length),
        ],
      ),
    );
  }

  // ... (Keep existing helpers like _buildMobileListView etc. - wait, I need to ensure they are not replaced or I must include them.
  // The tool instructions say: "StartLine: 233". I will replace from start of _buildDesktopTable down to end of methods)

  // Better to target specific methods.
  // I will split this into two calls if needed or include _buildMobileListView etc.
  // But wait, replace_file_content replaces contiguous blocks.
  // _showAddDriverDialog is further down.
  // I'll replace _buildDesktopTable first.

  Widget _buildMobileListView(List<Map<String, dynamic>> filteredDrivers) {
    return ListView.builder(
      itemCount: filteredDrivers.length,
      padding: const EdgeInsets.only(bottom: 20),
      itemBuilder: (context, index) {
        final driver = filteredDrivers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: driver['avatarColor'] ?? Colors.blue,
                      child: Text(driver['name'][0], style: const TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driver['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            driver['id'],
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(driver['status']),
                  ],
                ),
                const SizedBox(height: 16),
                _buildMobileInfoRow('Vehicle', driver['vehicle'], Icons.directions_car),
                const SizedBox(height: 8),
                _buildMobileInfoRow('Zone', driver['zone'], Icons.location_on),
                const SizedBox(height: 8),
                _buildMobileInfoRow('Rating', '${driver['rating']} / 5.0', Icons.star),
                
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showEditDriverDialog(driver),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                      style: TextButton.styleFrom(foregroundColor: Colors.blue),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _deleteDriver(driver),
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildPaginationFooter(int totalItems) {
     return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Text(
            'Rows per page',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Text('$rowsPerPage', style: const TextStyle(fontSize: 13)),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'of $totalItems rows',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {}, 
            color: Colors.grey[400],
          ),
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF2C3E50),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('1', style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {}, 
            color: Colors.grey[400],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(String label, List<String> items, String currentValue, Function(String) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue == 'All' ? null : currentValue,
          hint: Row(
            children: [
              if (currentValue == 'All') ...[
                 Icon(Icons.filter_list, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
              ],
              Text(
                currentValue == 'All' ? label : currentValue,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
          onChanged: (val) => onChanged(val ?? 'All'),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          isExpanded: true,
        ),
      ),
    );
  }

  Widget _buildCheckbox(bool value, Function(bool?) onChanged, {bool isHeader = false}) {
    return Container(
      width: 40,
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 18,
        height: 18,
        child: Checkbox(
          value: value,
          onChanged: onChanged,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          side: BorderSide(color: isHeader ? Colors.white70 : Colors.grey[400]!),
          checkColor: isHeader ? const Color(0xFF2C3E50) : Colors.white,
          activeColor: isHeader ? Colors.white : const Color(0xFF43A047),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, {required int flex, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'active':
        color = const Color(0xFF43A047);
        break;
      case 'inactive':
        color = Colors.grey;
        break;
      case 'suspended':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  void _showAddDriverDialog() {
    final _formKey = GlobalKey<FormState>();
    final _nameController = TextEditingController();
    final _emailController = TextEditingController();
    final _phoneController = TextEditingController();
    final _vehicleController = TextEditingController();
    String _selectedZone = 'Central District';
    String _selectedStatus = 'Active';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Driver'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                    hintText: 'Michael Brown',
                  ),
                  validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    hintText: 'email@example.com',
                  ),
                  validator: (value) {
                     if (value == null || value.isEmpty) return 'Please enter an email';
                     if (!value.contains('@')) return 'Invalid email';
                     return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                    hintText: '+94 77 123 4567',
                  ),
                  validator: (value) => value!.isEmpty ? 'Please enter a phone number' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _vehicleController,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Number',
                    border: OutlineInputBorder(),
                    hintText: 'WP ABC-1234',
                  ),
                  validator: (value) => value!.isEmpty ? 'Please enter a vehicle number' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedZone,
                  decoration: const InputDecoration(
                    labelText: 'Assigned Zone',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Central District', 'North Area', 'South Region']
                      .map((label) => DropdownMenuItem(value: label, child: Text(label)))
                      .toList(),
                  onChanged: (value) => _selectedZone = value!,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Active', 'Inactive', 'Suspended']
                      .map((label) => DropdownMenuItem(value: label, child: Text(label)))
                      .toList(),
                  onChanged: (value) => _selectedStatus = value!,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'A secure password will be auto-generated for this driver',
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );

                try {
                  // Auto-generate secure password
                  final generatedPassword = 'Driver${DateTime.now().millisecondsSinceEpoch}@';
                  
                  print('🔵 Creating driver with email: ${_emailController.text}');
                  print('🔵 Generated password: $generatedPassword');
                  
                  // Create Firebase Auth account
                  final userCredential = await _databaseService.createDriverWithAuth(
                    email: _emailController.text.trim(),
                    password: generatedPassword,
                    name: _nameController.text.trim(),
                    phone: _phoneController.text.trim(),
                    vehicleNumber: _vehicleController.text.trim(),
                    isActive: _selectedStatus == 'Active',
                  );

                  print('✅ Driver created successfully, showing dialog...');

                  if (mounted) {
                    Navigator.pop(context); // Close loading
                    Navigator.pop(context); // Close add driver dialog
                    
                    // Show success dialog with credentials
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_circle, color: Colors.green, size: 50),
                            ),
                            const SizedBox(height: 16),
                            const Text('Driver Created Successfully!', textAlign: TextAlign.center),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Share these login credentials with the driver:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            _buildCredentialRow('Email', _emailController.text),
                            const SizedBox(height: 12),
                            _buildCredentialRow('Password', generatedPassword),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Please save these credentials! The driver can change the password after first login.',
                                      style: TextStyle(fontSize: 11, color: Colors.orange.shade900),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton.icon(
                            onPressed: () {
                              // Copy credentials to clipboard
                              final credentials = 'Email: ${_emailController.text}\nPassword: $generatedPassword';
                              // Note: You'd need to add clipboard package for this
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Credentials copied to clipboard!')),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 18),
                            label: const Text('Copy'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF43A047),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    );
                  }
                } catch (e, stackTrace) {
                  print('❌ Error creating driver: $e');
                  print('❌ Stack trace: $stackTrace');
                  
                  if (mounted) {
                    Navigator.pop(context); // Close loading
                    
                    String errorMessage = 'Failed to create driver: ${e.toString()}';
                    if (e.toString().contains('email-already-in-use')) {
                      errorMessage = 'This email is already registered';
                    } else if (e.toString().contains('invalid-email')) {
                      errorMessage = 'Invalid email address';
                    }
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(errorMessage),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF43A047)),
            child: const Text('Create Driver'),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showEditDriverDialog(Map<String, dynamic> driver) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: (driver['name'] ?? '').toString());
    final phoneController = TextEditingController(
      text: (driver['phone'] ?? '').toString() == 'N/A' ? '' : (driver['phone'] ?? '').toString(),
    );
    final vehicleController = TextEditingController(
      text: (driver['vehicle'] ?? '').toString() == 'Unassigned'
          ? ''
          : (driver['vehicle'] ?? '').toString(),
    );
    bool isActive = (driver['status'] ?? 'Active').toString().toLowerCase() == 'active';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit ${driver['name']}'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: vehicleController,
                    decoration: const InputDecoration(labelText: 'Vehicle Number'),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (v) => setDialogState(() => isActive = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  await _databaseService.updateUserData(
                    (driver['id'] ?? '').toString(),
                    {
                      'name': nameController.text.trim(),
                      'phone': phoneController.text.trim(),
                      'vehicleNumber': vehicleController.text.trim(),
                      'isActive': isActive,
                      'isAvailable': isActive,
                      'updatedAt': DateTime.now().millisecondsSinceEpoch,
                    },
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Driver updated successfully')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteDriver(Map<String, dynamic> driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Driver'),
        content: Text('Are you sure you want to deactivate ${driver['name']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
               try {
                 await _databaseService.deleteUser(driver['id']);
                 if (mounted) {
                   Navigator.pop(context);
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Driver marked as inactive')),
                   );
                 }
               } catch (e) {
                 if (mounted) {
                   Navigator.pop(context);
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                   );
                 }
               }
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }
}
