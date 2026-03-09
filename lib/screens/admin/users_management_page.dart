import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/database_service.dart';
import '../../models/user_model.dart';

class UsersManagementPage extends StatefulWidget {
  const UsersManagementPage({super.key});

  @override
  State<UsersManagementPage> createState() => _UsersManagementPageState();
}

class _UsersManagementPageState extends State<UsersManagementPage> {
  final DatabaseService _databaseService = DatabaseService();
  
  String searchQuery = '';
  String filterRole = 'All';
  String filterStatus = 'All';
  int rowsPerPage = 10;
  int currentPage = 1;
  bool isAllSelected = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _databaseService.getAdminCitizensStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final allUsers = snapshot.data ?? [];
        
        // Transform Firebase data to match UI expectations
        final users = allUsers.map((userData) {
          return {
            'id': userData['uid'] ?? 'N/A',
            'name': userData['name'] ?? 'No Name',
            'email': userData['email'] ?? 'No Email',
            'role': userData['role'] ?? 'citizen',
            'status': (userData['isActive'] == false) ? 'Inactive' : 'Active',
            'joined': userData['createdAt'] != null 
                ? _formatDate(userData['createdAt'])
                : 'N/A',
            'lastActive': 'Recently', // Can be enhanced with real last activity tracking
            'avatarColor': _getColorForUser(userData['uid'] ?? ''),
            'selected': false,
            'phone': userData['phone'] ?? 'N/A',
            'address': userData['address'] ?? 'N/A',
          };
        }).toList();

        // Filtering logic
        final filteredUsers = users.where((user) {
          final matchesSearch = user['name'].toLowerCase().contains(searchQuery.toLowerCase()) ||
              user['email'].toLowerCase().contains(searchQuery.toLowerCase());
          final matchesStatus = filterStatus == 'All' || user['status'] == filterStatus;
          
          return matchesSearch && matchesStatus;
        }).toList();

        return _buildUI(context, filteredUsers);
      },
    );
  }

  String _formatDate(dynamic date) {
    try {
      if (date is DateTime) {
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      } else if (date is Timestamp) {
        final d = date.toDate();
        return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      } else if (date is String) {
        final parsedDate = DateTime.parse(date);
        return '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return 'N/A';
  }

  Color _getColorForUser(String uid) {
    // Generate color based on UID hash
    final hash = uid.hashCode;
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red, Colors.teal];
    return colors[hash.abs() % colors.length];
  }

  Widget _buildUI(BuildContext context, List<Map<String, dynamic>> filteredUsers) {
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
                    'Citizen Management',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage citizens from both users and citizens collections.',
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
                            hintText: 'Search citizens...',
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
                                'Status', 
                                ['All', 'Active', 'Inactive', 'Suspended', 'Banned'], 
                                filterStatus,
                                (val) => setState(() => filterStatus = val),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _showAddUserDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2C3E50),
                                shape: const CircleBorder(),
                                padding: const EdgeInsets.all(12),
                              ),
                              child: const Icon(Icons.add, color: Colors.white, size: 20),
                            ),
                          ],
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
                                hintText: 'Search citizens...',
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
                            'Status', 
                            ['All', 'Active', 'Inactive', 'Suspended', 'Banned'], 
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
                            onPressed: _syncUsersToRTDB,
                            icon: const Icon(Icons.sync, size: 18),
                            label: const Text('Restore Users'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _showAddUserDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Citizen'),
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

                  // Data Display (Table or List)
                  Expanded(
                    child: isMobile 
                      ? _buildMobileListView(filteredUsers)
                      : _buildDesktopTable(filteredUsers),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDesktopTable(List<Map<String, dynamic>> filteredUsers) {
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
                    for (var user in filteredUsers) {
                      user['selected'] = isAllSelected;
                    }
                  });
                }, isHeader: true),
                _buildHeaderCell('Full Name', flex: 3),
                _buildHeaderCell('Email', flex: 3),
                _buildHeaderCell('Status', flex: 2),
                _buildHeaderCell('Joined Date', flex: 2),
                _buildHeaderCell('Last Active', flex: 2),
                _buildHeaderCell('Actions', flex: 1, align: TextAlign.right),
              ],
            ),
          ),
          // Table Body
          Expanded(
            child: ListView.separated(
              itemCount: filteredUsers.length,
              separatorBuilder: (context, index) => const Divider(height: 1, thickness: 0.5),
              itemBuilder: (context, index) {
                final user = filteredUsers[index];
                return Container(
                  color: index % 2 == 0 ? Colors.white : Colors.grey[50], // Alternating rows
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _buildCheckbox(user['selected'], (val) {
                        setState(() {
                          user['selected'] = val;
                          isAllSelected = filteredUsers.every((u) => u['selected']);
                        });
                      }),
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: user['avatarColor'] ?? Colors.blue,
                              child: Text(
                                user['name'][0],
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              user['name'],
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(user['email'], style: TextStyle(color: Colors.grey[700])),
                      ),
                      Expanded(
                        flex: 2,
                        child: _buildStatusBadge(user['status']),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(user['joined'], style: TextStyle(color: Colors.grey[700])),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(user['lastActive'], style: TextStyle(color: Colors.grey[700])),
                      ),
                      Expanded(
                        flex: 1,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility_outlined, size: 18, color: Colors.green),
                              onPressed: () => _showUserProfileDialog(user),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                              onPressed: () => _showEditUserDialog(user),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              onPressed: () => _deleteUser(user),
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
          _buildPaginationFooter(filteredUsers.length),
        ],
      ),
    );
  }

  Widget _buildMobileListView(List<Map<String, dynamic>> filteredUsers) {
    return ListView.builder(
      itemCount: filteredUsers.length,
      padding: const EdgeInsets.only(bottom: 20),
      itemBuilder: (context, index) {
        final user = filteredUsers[index];
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
                      backgroundColor: user['avatarColor'] ?? Colors.blue,
                      child: Text(user['name'][0], style: const TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            user['email'],
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(user['status']),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Joined', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        Text(user['joined'], style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Last Active', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        Text(user['lastActive'], style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showUserProfileDialog(user),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('Profile'),
                      style: TextButton.styleFrom(foregroundColor: Colors.green),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _showEditUserDialog(user),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                      style: TextButton.styleFrom(foregroundColor: Colors.blue),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _deleteUser(user),
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
      case 'pending':
        color = const Color(0xFF1E3A8A); // Dark blue
        break;
      case 'suspended':
        color = Colors.orange;
        break;
      case 'banned':
        color = Colors.red;
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

  void _showAddUserDialog() {
    final _formKey = GlobalKey<FormState>();
    final _nameController = TextEditingController();
    final _emailController = TextEditingController();
    String _selectedStatus = 'Active';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Citizen'),
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
                    hintText: 'John Doe',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
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
                    if (value == null || value.isEmpty) {
                      return 'Please enter an email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Active', 'Inactive', 'Suspended', 'Banned']
                      .map((label) => DropdownMenuItem(
                            value: label,
                            child: Text(label),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _selectedStatus = value;
                    }
                  },
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
                // Generate a temporary ID (In production, this should come from Auth)
                final tempId = 'CIT${DateTime.now().millisecondsSinceEpoch}';
                
                final newCitizen = CitizenModel(
                  uid: tempId,
                  name: _nameController.text,
                  email: _emailController.text,
                  createdAt: DateTime.now(),
                  isActive: _selectedStatus == 'Active',
                  // Default values
                );

                try {
                  await _databaseService.createUser(newCitizen);
                  
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Citizen added successfully'),
                        backgroundColor: Color(0xFF43A047),
                      ),
                    );
                  }
                } catch (e) {
                   if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF43A047)),
            child: const Text('Add Citizen'),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: (user['name'] ?? '').toString());
    final emailController = TextEditingController(text: (user['email'] ?? '').toString());
    final phoneController = TextEditingController(
      text: (user['phone'] ?? '').toString() == 'N/A' ? '' : (user['phone'] ?? '').toString(),
    );
    final addressController = TextEditingController(
      text: (user['address'] ?? '').toString() == 'N/A' ? '' : (user['address'] ?? '').toString(),
    );
    bool isActive = (user['status'] ?? 'Active').toString().toLowerCase() == 'active';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit ${user['name']}'),
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
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Valid email required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Address'),
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
                    (user['id'] ?? '').toString(),
                    {
                      'name': nameController.text.trim(),
                      'email': emailController.text.trim(),
                      'phone': phoneController.text.trim(),
                      'address': addressController.text.trim(),
                      'isActive': isActive,
                      'updatedAt': DateTime.now().millisecondsSinceEpoch,
                    },
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Citizen updated successfully')),
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

  void _showUserProfileDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${user['name']} Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User ID: ${user['id']}'),
            const SizedBox(height: 8),
            Text('Name: ${user['name']}'),
            const SizedBox(height: 8),
            Text('Email: ${user['email']}'),
            const SizedBox(height: 8),
            Text('Phone: ${user['phone'] ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text('Address: ${user['address'] ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text('Status: ${user['status']}'),
            const SizedBox(height: 8),
            Text('Joined: ${user['joined']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _deleteUser(Map<String, dynamic> user) {
     showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Citizen'),
        content: Text('Are you sure you want to deactivate ${user['name']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
               try {
                 await _databaseService.deleteUser(user['id']);
                 if (mounted) {
                   Navigator.pop(context);
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Citizen marked as inactive')),
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

  Future<void> _syncUsersToRTDB() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Restoring citizens from database...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    try {
      // Perform restore
      final count = await _databaseService.restoreAllCitizensFromRTDB();
      
      if (mounted) {
        Navigator.pop(context); // Close loading
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Restoration Complete'),
            content: Text('Successfully restored/verified $count citizens from the Realtime Database.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Restoration Failed'),
            content: Text('Error: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    }
  }

}
