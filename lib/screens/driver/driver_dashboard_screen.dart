import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/task_model.dart';
import '../../models/pickup_request_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'driver_route_map_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  int _selectedIndex = 0;
  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      DatabaseService().setDriverOnlineStatus(uid, false);
    }
    super.dispose();
  }

  void _startLocationTracking() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

      DatabaseService().setDriverOnlineStatus(uid, true);

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        DatabaseService().updateDriverLocation(uid, position.latitude, position.longitude);
      });
    } catch (e) {
      debugPrint('Error starting driver tracking: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login as driver')),
      );
    }

    final pages = <Widget>[
      _DriverOverviewTab(onOpenProfile: () => setState(() => _selectedIndex = 3)),
      const _DriverActiveRouteTab(),
      const _DriverHistoryTab(),
      const _DriverPanelProfileTab(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF064E3B), // Matches Header
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF064E3B).withOpacity(0.35),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: const Color(0xFF34D399),
              unselectedItemColor: Colors.white.withOpacity(0.4),
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_rounded),
                  label: 'OVERVIEW',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.near_me_rounded),
                  label: 'NAVIGATE',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.receipt_long_rounded),
                  label: 'HISTORY',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.manage_accounts_rounded),
                  label: 'ACCOUNT',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverOverviewTab extends StatelessWidget {
  final VoidCallback onOpenProfile;

  const _DriverOverviewTab({required this.onOpenProfile});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<List<TaskModel>>(
      stream: DatabaseService().getTasksStream(driverId: user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final tasks = snapshot.data ?? [];
        final completedTasks = tasks.where((t) => t.status.toLowerCase().trim() == 'completed').toList();
        final activeTasks = tasks
            .where((t) => ['assigned', 'accepted', 'in_progress'].contains(t.status.toLowerCase().trim()))
            .toList();
        final pendingCount = activeTasks.length;

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _DriverPanelHeader(
                title: 'Operations Room',
                subtitle: 'Performance & Active Tasks',
                onOpenProfile: onOpenProfile,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatBox(
                            label: 'TOTAL ORDERS',
                            value: '${tasks.length}',
                            color: const Color(0xFF10B981),
                            icon: Icons.assignment_rounded,
                            isLarge: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _StatBox(
                            label: 'PENDING',
                            value: '$pendingCount',
                            color: const Color(0xFFF59E0B),
                            icon: Icons.pending_actions_rounded,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatBox(
                            label: 'COMPLETED',
                            value: '${completedTasks.length}',
                            color: const Color(0xFF16A34A),
                            icon: Icons.check_circle_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Current Checklist',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF111827), letterSpacing: -0.8),
                        ),
                        if (activeTasks.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$pendingCount TO DO',
                              style: const TextStyle(
                                color: Color(0xFFD97706),
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (activeTasks.isEmpty)
                      const _EmptyTaskCard(message: 'Workspace clear! No pending orders.')
                    else
                      ...activeTasks.take(10).map((task) => _TaskTileCard(task: task, showDone: true)),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DriverActiveRouteTab extends StatelessWidget {
  const _DriverActiveRouteTab();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final db = DatabaseService();
    return StreamBuilder<List<TaskModel>>(
      stream: db.getTasksStream(driverId: user.uid),
      builder: (context, taskSnapshot) {
        final tasks = taskSnapshot.data ?? [];
        final activeTasks = tasks
            .where((t) => t.status != 'completed' && t.status != 'failed')
            .toList();

        return StreamBuilder<List<PickupRequestModel>>(
          stream: db.getPickupRequestsStream(driverId: user.uid),
          builder: (context, pickupSnapshot) {
            if (taskSnapshot.connectionState == ConnectionState.waiting &&
                pickupSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final pickups = pickupSnapshot.data ?? [];
            final routePending = pickups
                .where((p) => !['completed', 'cancelled'].contains(p.status.toLowerCase().trim()))
                .toList();
            final routeCompleted = pickups.where((p) => p.status.toLowerCase().trim() == 'completed').length;
            final routeTotal = pickups.length;
            final progress = routeTotal == 0 ? 0.0 : routeCompleted / routeTotal;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                _DriverPanelHeader(
                  title: 'Tracking Center',
                  subtitle: 'Real-time route & pickup logistics',
                  onOpenProfile: () {},
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(36),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF064E3B).withOpacity(0.06),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Daily Logistics',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              color: Color(0xFF111827),
                              letterSpacing: -0.6,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${(progress * 100).toInt()}% READY',
                              style: const TextStyle(
                                color: Color(0xFF059669),
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 14,
                          backgroundColor: const Color(0xFFF1F5F9),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          _miniStat('IDLE', '${routePending.length}', const Color(0xFFF59E0B), Icons.hourglass_empty_rounded),
                          const SizedBox(width: 14),
                          _miniStat('TOTAL', '$routeTotal', const Color(0xFF10B981), Icons.flag_rounded),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF065F46), Color(0xFF047857)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(36),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF065F46).withOpacity(0.2),
                        blurRadius: 25,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.navigation_rounded, size: 28, color: Colors.white),
                          ),
                          const SizedBox(width: 18),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Proprietary Navigation',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 19,
                                    color: Colors.white,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                Text(
                                  'Voice-guided optimized stops',
                                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DriverRouteMapScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF065F46),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 0,
                          ),
                          child: const Text('LAUNCH MISSION CONTROL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Upcoming Tasks', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                if (activeTasks.isEmpty)
                  const _EmptyTaskCard(message: 'No upcoming tasks')
                else
                  ...activeTasks.asMap().entries.map((entry) {
                    final index = entry.key;
                    final task = entry.value;
                    return _UpcomingTaskCard(task: task, index: index);
                  }),
              ],
            );
          },
        );
      },
    );
  }

  Widget _miniStat(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      color: color.withOpacity(0.7),
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverHistoryTab extends StatefulWidget {
  const _DriverHistoryTab();

  @override
  State<_DriverHistoryTab> createState() => _DriverHistoryTabState();
}

class _DriverHistoryTabState extends State<_DriverHistoryTab> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<List<TaskModel>>(
      stream: DatabaseService().getTasksStream(driverId: user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final tasks = snapshot.data ?? [];
        final completed = tasks.where((t) => t.status.toLowerCase().trim() == 'completed').toList();
        final failed = tasks.where((t) => t.status.toLowerCase().trim() == 'failed').toList();
        final distance = (completed.length * 1.5).toStringAsFixed(1);

        final filtered = _filter == 'Completed'
            ? completed
            : _filter == 'Skipped'
                ? failed
                : tasks; // 'All' shows everything

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _DriverPanelHeader(
                title: 'Performance Logs',
                subtitle: 'History of your workspace activity',
                onOpenProfile: () {},
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatBox(
                            label: 'TOTAL COMPLETED',
                            value: '${completed.length}',
                            color: const Color(0xFF10B981),
                            icon: Icons.task_alt_rounded,
                            isLarge: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _StatBox(label: 'EFFICIENCY', value: '${completed.isEmpty ? 0 : 98}%', color: const Color(0xFF3B82F6), icon: Icons.auto_graph_rounded)),
                        const SizedBox(width: 16),
                        Expanded(child: _StatBox(label: 'DISTANCE', value: '${distance}km', color: const Color(0xFF8B5CF6), icon: Icons.route_rounded)),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Row(
                        children: [
                          _FilterChip(label: 'All Tasks', isActive: _filter == 'All', onTap: () => setState(() => _filter = 'All')),
                          _FilterChip(label: 'Completed', isActive: _filter == 'Completed', onTap: () => setState(() => _filter = 'Completed')),
                          _FilterChip(label: 'Failed', isActive: _filter == 'Skipped', onTap: () => setState(() => _filter = 'Skipped')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (filtered.isEmpty)
                      const _EmptyTaskCard(message: 'No records found for the selected category.')
                    else
                      ...filtered.map((task) => _TaskTileCard(task: task, showDone: false)),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DriverPanelProfileTab extends StatefulWidget {
  const _DriverPanelProfileTab();

  @override
  State<_DriverPanelProfileTab> createState() => _DriverPanelProfileTabState();
}

class _DriverPanelProfileTabState extends State<_DriverPanelProfileTab> {
  final _db = DatabaseService();
  final _auth = AuthService();
  bool _updatingAvailability = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _DriverPanelHeader(
            title: 'Account Settings',
            subtitle: 'Personal & Professional profile',
            onOpenProfile: () {},
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                StreamBuilder<UserModel?>(
                  stream: _db.getUserStream(user.uid),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      return _buildDriverCard(snapshot.data!);
                    }
                    return FutureBuilder<Map<String, dynamic>?>(
                      future: _db.getUserFromRTDB(user.uid),
                      builder: (context, fallback) {
                        if (fallback.connectionState == ConnectionState.waiting) {
                          return Container(
                            height: 200,
                            padding: const EdgeInsets.all(40),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        }
                        final map = fallback.data;
                        if (map != null) {
                          return _buildDriverCard(DriverModel.fromMap(map, user.uid));
                        }
                        return _buildDriverCard(
                          UserModel(
                            uid: user.uid,
                            name: 'Driver Account',
                            email: user.email ?? '',
                            role: 'driver',
                            createdAt: DateTime.now(),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    children: [
                      _actionButton(
                        icon: Icons.edit_note_rounded,
                        label: 'Edit Workspace Profile',
                        color: const Color(0xFF6366F1),
                        onTap: () => _showEditProfileDialog(),
                      ),
                      const SizedBox(height: 12),
                      _actionButton(
                        icon: Icons.lock_person_rounded,
                        label: 'Update Credentials',
                        color: const Color(0xFFF59E0B),
                        onTap: () => _showChangePasswordDialog(),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirm Logout'),
                                content: const Text('Are you sure you want to exit the driver panel?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    child: const Text('Logout'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await _auth.signOut();
                              if (!context.mounted) return;
                              Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                            }
                          },
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('TERMINATE SESSION'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            backgroundColor: Colors.redAccent.withOpacity(0.05),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDriverCard(UserModel profile) {
    final phone = profile.phone ?? 'N/A';
    final isDriver = profile is DriverModel;
    final vehicle = isDriver ? (profile.vehicleNumber ?? 'N/A') : 'N/A';
    final isAvailable = isDriver ? profile.isAvailable : true;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.accentGreen.withOpacity(0.1), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Row(
              children: [
                Hero(
                  tag: 'driver_avatar_profile',
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundGreenTint,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentGreen.withOpacity(0.2),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(Icons.person_rounded, color: AppColors.accentGreen, size: 40),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        profile.email,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              children: [
                _buildInfoRow(Icons.phone_rounded, 'Phone', phone),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.local_shipping_rounded, 'Vehicle', vehicle),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Availability',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        Text(
                          isAvailable ? 'Currently Online' : 'Currently Offline',
                          style: TextStyle(
                            color: isAvailable ? AppColors.accentGreen : Colors.grey,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Switch.adaptive(
                      value: isAvailable,
                      activeColor: AppColors.accentGreen,
                      onChanged: _updatingAvailability
                          ? null
                          : (value) async {
                              setState(() => _updatingAvailability = true);
                              try {
                                await _db.updateUserData(profile.uid, {'isAvailable': value});
                                await _db.setDriverOnlineStatus(profile.uid, value);
                              } finally {
                                if (mounted) setState(() => _updatingAvailability = false);
                              }
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: Colors.grey[700]),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w700)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ],
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditProfileDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final current = await _db.getUser(user.uid);
    final nameController = TextEditingController(text: current?.name ?? '');
    final phoneController = TextEditingController(text: current?.phone ?? '');
    final vehicleController = TextEditingController(
      text: current is DriverModel ? (current.vehicleNumber ?? '') : '',
    );

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Driver Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: vehicleController,
                decoration: const InputDecoration(labelText: 'Vehicle Number'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updates = <String, dynamic>{
                'name': nameController.text.trim(),
                'phone': phoneController.text.trim(),
                'vehicleNumber': vehicleController.text.trim(),
              };
              await _db.updateUserData(user.uid, updates);
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile updated')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPassword = TextEditingController();
    final newPassword = TextEditingController();
    final confirmPassword = TextEditingController();

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPassword,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current Password'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: newPassword,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmPassword,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm Password'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPassword.text.trim().length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('New password must be at least 6 characters')),
                );
                return;
              }
              if (newPassword.text.trim() != confirmPassword.text.trim()) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }
              try {
                await _auth.changePassword(
                  currentPassword: currentPassword.text.trim(),
                  newPassword: newPassword.text.trim(),
                );
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password changed successfully')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to change password: $e')),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}

class _DriverPanelHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onOpenProfile;

  const _DriverPanelHeader({
    required this.title,
    required this.subtitle,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF064E3B), // Deep Emerald
            Color(0xFF065F46), // Dark Green
            Color(0xFF047857), // Emerald
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(44),
          bottomRight: Radius.circular(44),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF065F46).withOpacity(0.3),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 30,
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onOpenProfile,
                child: Hero(
                  tag: 'driver_avatar',
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white30,
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person_rounded, color: const Color(0xFF065F46), size: 34),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.sensors_rounded, color: Color(0xFF059669), size: 24),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Live Navigation Sync',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFF34D399),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0xFF34D399), blurRadius: 10, spreadRadius: 2),
                    ],
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

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool isLarge;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isLarge ? 24 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.05), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: isLarge ? 28 : 22),
              ),
              if (isLarge)
                Icon(Icons.trending_up_rounded, color: color.withOpacity(0.5), size: 20),
            ],
          ),
          SizedBox(height: isLarge ? 24 : 16),
          Text(
            value,
            style: TextStyle(
              fontSize: isLarge ? 36 : 28,
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskTileCard extends StatelessWidget {
  final TaskModel task;
  final bool showDone;

  const _TaskTileCard({required this.task, required this.showDone});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    final status = task.status.toUpperCase();
    final time = DateFormat('hh:mm a').format(task.assignedDate);
    final priority = _priorityFromNotes(task.notes);
    final accent = _statusColor(task.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withOpacity(0.1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: accent.withOpacity(0.08),
              child: Row(
                children: [
                  _Badge(text: status.toUpperCase(), color: accent),
                  const SizedBox(width: 10),
                  _Badge(text: priority.toUpperCase(), color: _priorityColor(priority)),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        time,
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.notes?.isNotEmpty == true ? task.notes! : 'Pickup #${task.requestId.substring(task.requestId.length.clamp(0, 4))}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(6)),
                        child: Icon(Icons.pin_drop_rounded, size: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Request ID: ${task.requestId}',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DriverRouteMapScreen()),
                            );
                          },
                          icon: const Icon(Icons.map_rounded, size: 20),
                          label: const Text('VIEW MAP'),
                          style: TextButton.styleFrom(
                            foregroundColor: accent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: accent.withOpacity(0.05),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (showDone && task.id != null && task.status.toLowerCase().trim() != 'completed')
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await db.updateTask(task.id!, {
                                'status': 'completed',
                                'completionDate': DateTime.now(),
                              });
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Delivery confirmed! Great job.'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Color(0xFF0F172A),
                                ),
                              );
                            },
                            icon: const Icon(Icons.done_all_rounded, size: 20),
                            label: const Text('CONFIRM'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: accent.withOpacity(0.4),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingTaskCard extends StatelessWidget {
  final TaskModel task;
  final int index;

  const _UpcomingTaskCard({required this.task, required this.index});

  @override
  Widget build(BuildContext context) {
    final etaMin = 5 + (index * 3);
    final time = DateFormat('hh:mm a').format(task.assignedDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.backgroundGreenTint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: AppColors.accentGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stop #${task.requestId.substring(task.requestId.length - 4)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                const Text('ETA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black45)),
                Text('$etaMin min', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF374151))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF16A34A) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF374151),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}

class _EmptyTaskCard extends StatelessWidget {
  final String message;

  const _EmptyTaskCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _whiteCardDecoration(),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Text(message, style: TextStyle(color: Colors.grey[700])),
        ],
      ),
    );
  }
}

BoxDecoration _whiteCardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.03),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

String _priorityFromNotes(String? notes) {
  final lower = (notes ?? '').toLowerCase();
  if (lower.contains('high') || lower.contains('urgent')) return 'HIGH';
  if (lower.contains('medium')) return 'MEDIUM';
  return 'NORMAL';
}

Color _priorityColor(String priority) {
  switch (priority) {
    case 'HIGH':
      return const Color(0xFFDC2626); // Red
    case 'MEDIUM':
      return const Color(0xFFD97706); // Orange
    default:
      return const Color(0xFF059669); // Green
  }
}

Color _statusColor(String status) {
  switch (status.toLowerCase().trim()) {
    case 'completed':
      return const Color(0xFF059669); // Emerald
    case 'in_progress':
    case 'accepted':
      return const Color(0xFF0891B2); // Cyan
    case 'failed':
      return const Color(0xFF4B5563); // Gray
    default:
      return const Color(0xFFCA8A04); // Yellow/Orange
  }
}
