import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/date_formatter.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final DatabaseService _databaseService = DatabaseService();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dashboard Overview',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              // Stats Grid with Real Data
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _databaseService.getCitizensStream(),
                builder: (context, citizensSnapshot) {
                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _databaseService.getDriversStream(),
                    builder: (context, driversSnapshot) {
                      return StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _databaseService.getPickupRequestsStream().map((requests) => 
                          requests.map((r) => r.toMap()).toList()
                        ),
                        builder: (context, pickupsSnapshot) {
                          // Calculate stats
                          final totalUsers = citizensSnapshot.data?.length ?? 0;
                          final activeDrivers = driversSnapshot.data?.length ?? 0;
                          final pendingPickups = pickupsSnapshot.data
                                  ?.where((p) => p['status'] == 'pending')
                                  .length ??
                              0;

                          return GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.5,
                            children: [
                              _buildStatCard(
                                'Total Citizens',
                                totalUsers.toString(),
                                Icons.people,
                                Colors.blue,
                                citizensSnapshot.connectionState == ConnectionState.waiting,
                              ),
                              _buildStatCard(
                                'Active Drivers',
                                activeDrivers.toString(),
                                Icons.local_shipping,
                                Colors.green,
                                driversSnapshot.connectionState == ConnectionState.waiting,
                              ),
                              _buildStatCard(
                                'Pending Pickups',
                                pendingPickups.toString(),
                                Icons.pending_actions,
                                Colors.orange,
                                pickupsSnapshot.connectionState == ConnectionState.waiting,
                              ),
                              _buildStatCard(
                                'Total Pickups',
                                (pickupsSnapshot.data?.length ?? 0).toString(),
                                Icons.check_circle,
                                Colors.purple,
                                pickupsSnapshot.connectionState == ConnectionState.waiting,
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
// Replaced dummy data with real streams
              const Text(
                'Recent Pickup Requests',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _databaseService.getPickupRequestsStream().map((requests) => 
                  requests.map((r) => r.toMap()).toList()
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text("No recent activity.");
                  }

                  // Take last 5 requests
                  final recent = snapshot.data!.take(5).toList();

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      children: recent.map((request) {
                        return Column(
                          children: [
                            _buildActivityItem(
                              Icons.local_shipping,
                              'Pickup Request: ${request['wasteType'] ?? 'General'}',
                              request['requestedDate'] != null ? _formatDate(request['requestedDate']) : 'Just now',
                              Colors.blue,
                            ),
                            const Divider(height: 1),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date is Timestamp) {
      return DateFormatter.timeAgo(date.toDate());
    } else if (date is DateTime) {
      return DateFormatter.timeAgo(date);
    }
    return date?.toString() ?? 'Recent';
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              if (isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(IconData icon, String title, String time, Color color) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      trailing: Text(
        time,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
    );
  }
}
