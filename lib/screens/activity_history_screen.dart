import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../widgets/citizen_page_header.dart';

class ActivityHistoryScreen extends StatelessWidget {
  const ActivityHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: Column(
        children: [
          const CitizenPageHeader(
            title: 'Activity History',
            subtitle: 'Track your past waste pickups and reports',
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.history_rounded, size: 80, color: Colors.grey[300]),
                   const SizedBox(height: 16),
                   Text(
                    'No activities yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your pickup requests and reports will appear here.',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
