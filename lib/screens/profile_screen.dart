import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../utils/app_colors.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../widgets/citizen_page_header.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  User? _currentUser;
  DateTime? _passwordLastChangedAt;
  Stream<UserModel?>? _userStream;
  bool _isUploadingImage = false;
  
  @override
  void initState() {
    super.initState();
    _currentUser = _authService.currentUser;
    if (_currentUser != null) {
      _userStream = _databaseService.getUserStream(_currentUser!.uid);
    }
  }

  void _editProfile(UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildEditProfileSheet(user),
    );
  }

  Future<void> _updateProfileImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image == null || _currentUser == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final path = 'profile_pictures/${_currentUser!.uid}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final downloadUrl = await _databaseService.uploadImage(image, path);
      
      await _databaseService.updateUserData(_currentUser!.uid, {
        'profileImageUrl': downloadUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated!'),
            backgroundColor: AppColors.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  void _viewRewards() {
    Navigator.pushNamed(context, '/rewards');
  }

  void _viewActivityHistory() {
    Navigator.pushNamed(context, '/activity-history');
  }

  void _viewHelpSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📞 Contact Support: +94 11 234 5678'),
            SizedBox(height: 8),
            Text('✉️ Email: support@ecowise.com'),
            SizedBox(height: 8),
            Text('⏰ Available: 24/7'),
            SizedBox(height: 16),
            Text(
              'For assistance with waste pickup, rewards, or any issues, please contact our support team.',
              style: TextStyle(fontSize: 12),
            ),
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

  void _viewPrivacyPolicy() {
    Navigator.pushNamed(context, '/privacy-policy');
  }

  void _showChangePasswordDialog() {
    final formKey = GlobalKey<FormState>();
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Change Password'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentPasswordController,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                        ),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Enter current password' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: const Icon(Icons.password_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Enter new password';
                        if (value.length < 6) return 'Password must be at least 6 characters';
                        if (value == currentPasswordController.text) {
                          return 'New password must be different';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Confirm new password';
                        if (value != newPasswordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() => isSaving = true);
                          final changedAt = DateTime.now();
                          try {
                            await _authService.changePassword(
                              currentPassword: currentPasswordController.text.trim(),
                              newPassword: newPasswordController.text.trim(),
                            );

                            if (_currentUser != null) {
                              await _databaseService.updateUserData(_currentUser!.uid, {
                                'passwordLastChangedAt': changedAt.millisecondsSinceEpoch,
                                'passwordLastChangedAtIso': changedAt.toIso8601String(),
                              });
                            }

                            if (!mounted) return;
                            setState(() {
                              _passwordLastChangedAt = changedAt;
                            });
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password changed successfully'),
                                backgroundColor: AppColors.accentGreen,
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            setDialogState(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to change password: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _logout() {
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              _authService.signOut();
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildEditProfileSheet(UserModel user) {
    final TextEditingController nameController =
        TextEditingController(text: user.name);
    final TextEditingController phoneController =
        TextEditingController(text: user.phone ?? '');
    
    String currentAddress = '';
    if (user is CitizenModel) {
      currentAddress = user.address ?? '';
    }
    final TextEditingController addressController =
        TextEditingController(text: currentAddress);

    return Container(
      padding: const EdgeInsets.only(top: 20),
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 60,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Edit Profile',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _buildTextField(nameController, 'Full Name', Icons.person),
              const SizedBox(height: 16),
              _buildTextField(phoneController, 'Phone Number', Icons.phone),
              const SizedBox(height: 16),
              if (user.role == 'citizen')
                 _buildTextField(addressController, 'Address', Icons.home),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      Map<String, dynamic> updates = {
                        'name': nameController.text.trim(),
                        'phone': phoneController.text.trim(),
                      };
                      if (user.role == 'citizen') {
                        updates['address'] = addressController.text.trim();
                      }
                      await _databaseService.updateUserData(user.uid, updates);
                      if (mounted) Navigator.pop(context);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.accentGreen),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) return const Scaffold(body: Center(child: Text('Please log in')));
    
    return StreamBuilder<UserModel?>(
      stream: _userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snapshot.data;
        if (user == null) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => _databaseService.ensureUserExistsInFirestore(_currentUser!.uid),
                child: const Text('Restore Profile'),
              ),
            ),
          );
        }
        
        return _buildProfileScaffold(user);
      }
    );
  }

  Widget _buildProfileScaffold(UserModel user) {
    String memberSince = DateFormat('yyyy-MM-dd').format(user.createdAt);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: SingleChildScrollView(
        child: Column(
          children: [
            CitizenPageHeader(
              title: 'My Profile',
              subtitle: 'View and manage your account details',
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () => _editProfile(user),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                   Container(
                    transform: Matrix4.translationValues(0, -6, 0),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: _isUploadingImage ? null : _updateProfileImage,
                          borderRadius: BorderRadius.circular(50),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(colors: [AppColors.accentGreen, AppColors.accentGreen.withOpacity(0.8)]),
                                ),
                                child: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
                                    ? CircleAvatar(radius: 50, backgroundImage: NetworkImage(user.profileImageUrl!))
                                    : const Icon(Icons.person, size: 60, color: Colors.white),
                              ),
                              if (_isUploadingImage)
                                const CircularProgressIndicator(color: Colors.white),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  child: Icon(Icons.camera_alt, size: 18, color: AppColors.accentGreen),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(user.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        Text(user.email, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                        const SizedBox(height: 16),
                        if (user is CitizenModel)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.accentGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.accentGreen.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.stars, color: AppColors.accentGreen, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  '${user.rewardPoints} Eco Points',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentGreen),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildSectionCard(
                    title: 'Personal Information',
                    icon: Icons.person_outline,
                    children: [
                      _buildInfoItem(Icons.phone_rounded, 'Phone Number', user.phone ?? 'N/A'),
                      if (user is CitizenModel)
                        _buildInfoItem(Icons.home_rounded, 'Address', user.address ?? 'N/A'),
                      _buildInfoItem(Icons.calendar_today_rounded, 'Member Since', memberSince),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _buildSectionCard(
                    title: 'Account & Safety',
                    icon: Icons.shield_outlined,
                    children: [
                      if (user is CitizenModel) ...[
                        _buildActionItem(Icons.stars_rounded, 'My Rewards', _viewRewards),
                        _buildActionItem(Icons.history_rounded, 'Activity History', _viewActivityHistory),
                      ],
                      _buildActionItem(Icons.lock_reset_rounded, 'Change Password', _showChangePasswordDialog),
                      _buildActionItem(Icons.help_outline_rounded, 'Help & Support', _viewHelpSupport),
                      _buildActionItem(Icons.privacy_tip_rounded, 'Privacy Policy', _viewPrivacyPolicy),
                    ],
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _logout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.1),
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.red.withOpacity(0.3)),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, size: 20),
                          SizedBox(width: 12),
                          Text('Logout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.accentGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: AppColors.accentGreen, size: 22),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.grey.shade600, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: Colors.grey.shade600, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
