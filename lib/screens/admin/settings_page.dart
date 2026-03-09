import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/database_service.dart';
import 'admin_profile_screen.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final DatabaseService _dbService = DatabaseService();
  bool notificationsEnabled = true;
  bool emailNotifications = true;
  bool pushNotifications = false;
  String selectedLanguage = 'English';
  String selectedTheme = 'Light';
  bool _isRestoring = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Manage your preferences',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSettingsSection(
                      'Account',
                      [
                        _buildSettingItem(
                          Icons.person,
                          'Profile',
                          'Update your information',
                          () => _showProfileSettings(),
                        ),
                        _buildSettingItem(
                          Icons.lock,
                          'Change Password',
                          'Update security credentials',
                          () => _showPasswordDialog(),
                        ),
                        _buildSettingItem(
                          Icons.email,
                          'Email Preferences',
                          'Manage email settings',
                          () => _showEmailPreferences(),
                        ),
                      ],
                    ),
                    _buildSettingsSection(
                      'Notifications',
                      [
                        _buildSwitchItem(
                          Icons.notifications,
                          'Enable Notifications',
                          'Receive system notifications',
                          notificationsEnabled,
                          (value) {
                            setState(() => notificationsEnabled = value);
                          },
                        ),
                        _buildSwitchItem(
                          Icons.email_outlined,
                          'Email Notifications',
                          'Get updates via email',
                          emailNotifications,
                          (value) {
                            setState(() => emailNotifications = value);
                          },
                        ),
                        _buildSwitchItem(
                          Icons.phone_android,
                          'Push Notifications',
                          'Mobile push notifications',
                          pushNotifications,
                          (value) {
                            setState(() => pushNotifications = value);
                          },
                        ),
                      ],
                    ),
                    _buildSettingsSection(
                      'Application',
                      [
                        _buildSettingItem(
                          Icons.language,
                          'Language',
                          selectedLanguage,
                          () => _showLanguageDialog(),
                        ),
                        _buildSettingItem(
                          Icons.palette,
                          'Theme',
                          selectedTheme,
                          () => _showThemeDialog(),
                        ),
                        _buildSettingItem(
                          Icons.location_on,
                          'Default Zone',
                          'Central District',
                          () => _showZoneDialog(),
                        ),
                      ],
                    ),
                    _buildSettingsSection(
                      'System Security & Repair',
                      [
                        _buildSettingItem(
                          Icons.cloud_sync,
                          'Repair Database',
                          'Sync missing data from RTDB to Firestore',
                          () => _showRestoreTools(),
                        ),
                        _buildSettingItem(
                          Icons.security,
                          'Security Settings',
                          'System security options',
                          () => _showSecuritySettings(),
                        ),
                        _buildSettingItem(
                          Icons.storage,
                          'Clear Cache',
                          'Free up storage space',
                          () => _showClearCacheDialog(),
                        ),
                      ],
                    ),
                    _buildSettingsSection(
                      'About',
                      [
                        _buildSettingItem(
                          Icons.info,
                          'App Information',
                          'Version 1.0.0',
                          () => _showAboutDialog(),
                        ),
                        _buildSettingItem(
                          Icons.description,
                          'Terms & Conditions',
                          'Legal information',
                          () => _showTermsDialog(),
                        ),
                        _buildSettingItem(
                          Icons.privacy_tip,
                          'Privacy Policy',
                          'Data protection info',
                          () => _showPrivacyDialog(),
                        ),
                        _buildSettingItem(
                          Icons.help,
                          'Help & Support',
                          'Get assistance',
                          () => _showHelpDialog(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        Container(
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
          child: Column(children: items),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSettingItem(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF43A047).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF43A047)),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[600],
        ),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
      onTap: onTap,
    );
  }

  Widget _buildSwitchItem(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF43A047).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF43A047)),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[600],
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF43A047),
      ),
    );
  }

  void _showProfileSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
    );
  }

  void _showRestoreTools() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Repair Database (RTDB -> Firestore)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'If the admin panel is empty but your Realtime Database has data, use these buttons to restore Firestore collections.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              if (_isRestoring)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text('Syncing data... please wait.'),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.people),
                      label: const Text('Restore All Citizens'),
                      onPressed: () async {
                        setDialog(() => _isRestoring = true);
                        try {
                          int count = await _dbService.restoreAllCitizensFromRTDB();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('✅ Successfully restored $count citizens!')),
                            );
                          }
                        } finally {
                          setDialog(() => _isRestoring = false);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.local_shipping),
                      label: const Text('Restore All Drivers'),
                      onPressed: () async {
                        setDialog(() => _isRestoring = true);
                        try {
                          int count = await _dbService.restoreAllDriversFromRTDB();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('✅ Successfully restored $count drivers!')),
                            );
                          }
                        } finally {
                          setDialog(() => _isRestoring = false);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Self-Heal Admin Permissions'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      onPressed: () async {
                        setDialog(() => _isRestoring = true);
                        try {
                          bool success = await _dbService.ensureUserExistsInFirestore(FirebaseAuth.instance.currentUser?.uid ?? '');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(success ? '✅ Permissions repaired!' : '❌ Repair failed.')),
                            );
                          }
                        } finally {
                          setDialog(() => _isRestoring = false);
                        }
                      },
                    ),
                  ],
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
      ),
    );
  }

  void _showPasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Change Password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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
            onPressed: () {
              if (newPasswordController.text == confirmPasswordController.text) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password changed successfully'),
                    backgroundColor: Color(0xFF43A047),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Passwords do not match'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF43A047)),
            child: const Text('Change Password'),
          ),
        ],
      ),
    );
  }

  void _showEmailPreferences() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Email Preferences'),
        content: const Text('Configure your email notification preferences here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    final languages = ['English', 'Sinhala', 'Tamil'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages.map((lang) {
            return RadioListTile<String>(
              value: lang,
              groupValue: selectedLanguage,
              title: Text(lang),
              onChanged: (value) {
                setState(() => selectedLanguage = value!);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Language changed to $value')),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showThemeDialog() {
    final themes = ['Light', 'Dark', 'System'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Select Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: themes.map((theme) {
            return RadioListTile<String>(
              value: theme,
              groupValue: selectedTheme,
              title: Text(theme),
              onChanged: (value) {
                setState(() => selectedTheme = value!);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Theme changed to $value')),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showZoneDialog() {
    final zones = ['Central District', 'North Area', 'South Region', 'East Zone', 'West Zone'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Select Default Zone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: zones.map((zone) {
            return ListTile(
              title: Text(zone),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Default zone set to $zone')),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showSecuritySettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Security Settings'),
        content: const Text('Configure two-factor authentication and other security options here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Cache'),
        content: const Text('This will clear all cached data and free up storage space. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache cleared successfully'),
                  backgroundColor: Color(0xFF43A047),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear Cache'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF43A047).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.eco, color: Color(0xFF43A047)),
            ),
            const SizedBox(width: 12),
            const Text('WasteWise Admin'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Version 1.0.0',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Smart Waste Management System',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Text(
              '© 2024 WasteWise. All rights reserved.',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Terms & Conditions'),
        content: const SingleChildScrollView(
          child: Text(
            'Terms and conditions content will be displayed here. '
            'This should include all legal agreements and user responsibilities.',
          ),
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

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'Privacy policy content will be displayed here. '
            'This should include information about data collection, usage, and protection.',
          ),
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

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Help & Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.email, color: Color(0xFF43A047)),
              title: const Text('Email Support'),
              subtitle: const Text('support@wastewise.com'),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.phone, color: Color(0xFF43A047)),
              title: const Text('Phone Support'),
              subtitle: const Text('+94 11 234 5678'),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Color(0xFF43A047)),
              title: const Text('Live Chat'),
              subtitle: const Text('Available 24/7'),
              contentPadding: EdgeInsets.zero,
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
}
