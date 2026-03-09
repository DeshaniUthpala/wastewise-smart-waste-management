import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_colors.dart';
import '../widgets/citizen_page_header.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFFF8E1),
              AppColors.backgroundGreenTint,
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: CitizenPageHeader(
                title: 'Rewards',
                subtitle: 'Track points and redeem eco-friendly rewards',
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  StreamBuilder<UserModel?>(
                    stream: uid == null ? const Stream.empty() : DatabaseService().getUserStream(uid),
                    builder: (context, snapshot) {
                      final points = snapshot.data is CitizenModel
                          ? (snapshot.data as CitizenModel).rewardPoints
                          : 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFFCA28),
                              Color(0xFFF57F17),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.stars, size: 44, color: Colors.white),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Total Points',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$points',
                              style: const TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  // Monthly Stats
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          '250',
                          'This Month',
                          Icons.trending_up,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Silver',
                          'Current Level',
                          Icons.workspace_premium,
                          Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // How to Earn Points
                  const Text(
                    'Earn More Points',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildEarnCard(
                    'Timely Disposal',
                    'Place waste before scheduled time',
                    '50',
                    Icons.schedule,
                    Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _buildEarnCard(
                    'Proper Segregation',
                    'Separate waste correctly',
                    '30',
                    Icons.recycling,
                    Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  _buildEarnCard(
                    'Report Issues',
                    'Help improve services',
                    '20',
                    Icons.report,
                    Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  _buildEarnCard(
                    'Refer Friends',
                    'Invite others to join',
                    '100',
                    Icons.people,
                    Colors.purple,
                  ),
                  const SizedBox(height: 32),

                  // Level Progress
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFE8F5E9), Color(0xFFFFF3E0)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.18),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
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
                              'Level Progress',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Silver',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('1,250 points'),
                            Text(
                              '2,000 points',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: 0.625,
                            minHeight: 14,
                            backgroundColor: Colors.white.withValues(alpha: 0.5),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFF9A825),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '750 points to Gold level 🏆',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Level Badges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildBadge('Bronze', true, Colors.brown),
                      _buildBadge('Silver', true, Colors.grey),
                      _buildBadge('Gold', false, Colors.amber),
                      _buildBadge('Platinum', false, Colors.blueGrey),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Redeem Rewards
                  const Text(
                    'Redeem Rewards',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildRewardCard(
                    'Waste Bin Discount',
                    '10% off on new bins',
                    '500',
                    Icons.delete_outline,
                    Colors.blue,
                    true,
                  ),
                  const SizedBox(height: 12),
                  _buildRewardCard(
                    'Free Pickup',
                    'One special collection',
                    '800',
                    Icons.local_shipping,
                    Colors.green,
                    true,
                  ),
                  const SizedBox(height: 12),
                  _buildRewardCard(
                    'Shopping Voucher',
                    'Rs. 500 eco products',
                    '1500',
                    Icons.shopping_bag,
                    Colors.purple,
                    false,
                  ),
                  const SizedBox(height: 12),
                  _buildRewardCard(
                    'Plant a Tree',
                    'In your name',
                    '2000',
                    Icons.park,
                    Colors.green,
                    false,
                  ),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 12),
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
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarnCard(
    String title,
    String subtitle,
    String points,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.stars, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text(
                  points,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, bool unlocked, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: unlocked ? color.withValues(alpha: 0.1) : Colors.grey.shade200,
            shape: BoxShape.circle,
            border: Border.all(
              color: unlocked ? color : Colors.grey.shade400,
              width: 3,
            ),
            boxShadow: unlocked
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Icon(
            unlocked ? Icons.workspace_premium : Icons.lock,
            color: unlocked ? color : Colors.grey,
            size: 32,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: unlocked ? FontWeight.bold : FontWeight.normal,
            color: unlocked ? Colors.black87 : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildRewardCard(
    String title,
    String subtitle,
    String points,
    IconData icon,
    Color color,
    bool canRedeem,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: canRedeem ? color.withValues(alpha: 0.3) : Colors.grey.shade200,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: canRedeem
                ? color.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: canRedeem ? 0.1 : 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: canRedeem ? color : Colors.grey,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: canRedeem ? Colors.black87 : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.stars,
                      size: 16,
                      color: canRedeem ? Colors.amber : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$points pts',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: canRedeem ? Colors.amber : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: canRedeem ? () {} : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canRedeem ? color : Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Redeem',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
