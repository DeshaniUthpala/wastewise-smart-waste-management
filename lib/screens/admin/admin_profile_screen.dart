import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final DatabaseService _databaseService = DatabaseService();
  bool _isUploadingImage = false;

  Future<void> _updateProfileImage(String uid) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final path = 'profile_pictures/$uid/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final downloadUrl = await _databaseService.uploadImage(image, path);
      
      await _databaseService.updateUserData(uid, {
        'profileImageUrl': downloadUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin profile picture updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please login')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      appBar: AppBar(
        title: const Text('Admin Profile'),
        backgroundColor: const Color(0xFF43A047),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<UserModel?>(
        stream: _databaseService.getUserStream(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildRtdbFallback(currentUser.uid);
          }

          final user = snapshot.data;
          if (user == null) {
            return _buildRtdbFallback(currentUser.uid);
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    InkWell(
                      onTap: _isUploadingImage ? null : () => _updateProfileImage(user.uid),
                      borderRadius: BorderRadius.circular(50),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF43A047).withOpacity(0.1),
                            ),
                            child: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
                                ? CircleAvatar(radius: 50, backgroundImage: NetworkImage(user.profileImageUrl!))
                                : const Icon(Icons.person, size: 50, color: Color(0xFF43A047)),
                          ),
                          if (_isUploadingImage)
                            const CircularProgressIndicator(color: Color(0xFF43A047)),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt, size: 18, color: Color(0xFF43A047)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      user.name.isEmpty ? 'Admin User' : user.name,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(user.email, style: TextStyle(color: Colors.grey[700])),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Admin Account',
                        style: TextStyle(color: Colors.purple, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _tile('User ID', user.uid, Icons.badge_outlined),
              _tile('Phone', user.phone ?? 'N/A', Icons.phone_outlined),
              _tile('Role', user.role, Icons.admin_panel_settings_outlined),
              _tile(
                'Created',
                '${user.createdAt.year}-${user.createdAt.month.toString().padLeft(2, '0')}-${user.createdAt.day.toString().padLeft(2, '0')}',
                Icons.calendar_today_outlined,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _showEditDialog(user),
                icon: const Icon(Icons.edit),
                label: const Text('Edit Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF43A047),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRtdbFallback(String uid) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _databaseService.getUserFromRTDB(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data;
        if (data == null) {
          return const Center(child: Text('Admin profile not found'));
        }
        final user = UserModel.fromMap(data, uid);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _tile('User ID', user.uid, Icons.badge_outlined),
            _tile('Name', user.name, Icons.person_outline),
            _tile('Email', user.email, Icons.email_outlined),
            _tile('Phone', user.phone ?? 'N/A', Icons.phone_outlined),
            _tile('Role', user.role, Icons.admin_panel_settings_outlined),
          ],
        );
      },
    );
  }

  Widget _tile(String title, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF43A047)),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }

  void _showEditDialog(UserModel user) {
    final nameController = TextEditingController(text: user.name);
    final phoneController = TextEditingController(text: user.phone ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Admin Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await _databaseService.updateUserData(user.uid, {
                'name': nameController.text.trim(),
                'phone': phoneController.text.trim(),
              });
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Admin profile updated')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF43A047)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
