import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import 'users_management_page.dart';
import 'drivers_management_page.dart';
import 'reports_page.dart';
import 'settings_page.dart';
import 'admin_home_content.dart';
import 'schedule_management_page.dart';
import 'issues_management_page.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      print('🚀 Running self-healing permission check for admin...');
      await DatabaseService().ensureUserExistsInFirestore(user.uid);
    }
  }

  final List<Widget> _pages = [
    const AdminHomePage(),
    const UsersManagementPage(),
    const DriversManagementPage(),
    const ScheduleManagementPage(),
    const IssuesManagementPage(),
    const ReportsPage(),
    const SettingsPage(),
  ];

  final List<String> _pageTitles = [
    'Dashboard',
    'Citizens',
    'Drivers',
    'Schedules',
    'Pickups & Issues',
    'Analytics',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_pageTitles[_selectedIndex]),
          backgroundColor: const Color(0xFF43A047),
          foregroundColor: Colors.white,
          actions: [
            PopupMenuButton(
              icon: const Icon(Icons.account_circle),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('Profile'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'profile') {
                  Navigator.pushNamed(context, '/admin-profile');
                } else if (value == 'logout') {
                  _showLogoutDialog();
                }
              },
            ),
          ],
        ),
        body: _pages[_selectedIndex],
        bottomNavigationBar: _buildMobileNavBar(),
      );
    } else {
      return Scaffold(
        body: Row(
          children: [
            _buildSideNavBar(),
            Expanded(
              child: Column(
                children: [
                  _buildTopMenuBar(),
                  Expanded(child: _pages[_selectedIndex]),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildMobileNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF43A047),
          unselectedItemColor: Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_rounded),
              label: 'Citizens',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_shipping_rounded),
              label: 'Drivers',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event_rounded),
              label: 'Schedules',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_rounded),
              label: 'Pickups & Issues',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_rounded),
              label: 'Analytics',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideNavBar() {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1B5E20),
            const Color(0xFF43A047),
          ],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Logo
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.eco,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'WasteWise\nAdmin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildNavItem(0, Icons.dashboard_rounded, 'Dashboard'),
          _buildNavItem(1, Icons.people_rounded, 'Citizens'),
          _buildNavItem(2, Icons.local_shipping_rounded, 'Drivers'),
          _buildNavItem(3, Icons.event_rounded, 'Schedules'),
          _buildNavItem(4, Icons.assignment_rounded, 'Pickups & Issues'),
          _buildNavItem(5, Icons.analytics_rounded, 'Analytics'),
          _buildNavItem(6, Icons.settings_rounded, 'Settings'),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton.icon(
              onPressed: () {
                _showLogoutDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Logout'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () => setState(() => _selectedIndex = index),
      ),
    );
  }

  Widget _buildTopMenuBar() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 20),
          Text(
            _pageTitles[_selectedIndex],
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          // Menu items visible on desktop
          ..._buildMenuItems(),
          const SizedBox(width: 20),
          // Desktop Profile & Logout
          PopupMenuButton(
            offset: const Offset(0, 50),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey.shade200,
                  child: const Icon(Icons.person, color: Colors.grey),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Admin',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.black54),
              ],
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'profile') {
                Navigator.pushNamed(context, '/admin-profile');
              } else if (value == 'logout') {
                _showLogoutDialog();
              }
            },
          ),
          const SizedBox(width: 20),
        ],
      ),
    );
  }

  List<Widget> _buildMenuItems() {
    final menuItems = [
      {'index': 0, 'icon': Icons.dashboard_rounded, 'label': 'Dashboard'},
      {'index': 1, 'icon': Icons.people_rounded, 'label': 'Citizens'},
      {'index': 2, 'icon': Icons.local_shipping_rounded, 'label': 'Drivers'},
      {'index': 3, 'icon': Icons.event_rounded, 'label': 'Schedules'},
      {'index': 4, 'icon': Icons.assignment_rounded, 'label': 'Pickups & Issues'},
      {'index': 5, 'icon': Icons.analytics_rounded, 'label': 'Analytics'},
      {'index': 6, 'icon': Icons.settings_rounded, 'label': 'Settings'},
    ];

    return menuItems.map((item) {
      final isSelected = _selectedIndex == item['index'] as int;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _selectedIndex = item['index'] as int),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF43A047).withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: const Color(0xFF43A047), width: 2)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item['icon'] as IconData,
                    size: 18,
                    color: isSelected ? const Color(0xFF43A047) : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item['label'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF43A047) : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await AuthService().signOut();
              if (mounted) {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF43A047),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
