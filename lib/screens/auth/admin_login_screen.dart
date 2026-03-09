import 'package:flutter/material.dart';
import 'package:wasteapp/screens/auth/driver_login_screen.dart';
import 'package:wasteapp/screens/admin/admin_home_page.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';


class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false; // Add loading state

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeIn));

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.arrow_back,
                              size: 24,
                              color: Colors.grey.shade800,
                            ),
                            onPressed: () {
                              // Go back to citizen login screen
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                          ), 
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Admin/Driver Toggle
                      Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildToggleButton(
                                'Admin',
                                isSelected: true,
                                onTap: () {
                                  // Already on Admin
                                },
                              ),
                              _buildToggleButton(
                                'Driver',
                                isSelected: false,
                                onTap: () {
                                  // Navigate to Driver login
                                  Navigator.pushReplacement(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder:
                                          (
                                            context,
                                            animation,
                                            secondaryAnimation,
                                          ) => const DriverLoginScreen(),
                                      transitionsBuilder:
                                          (
                                            context,
                                            animation,
                                            secondaryAnimation,
                                            child,
                                          ) {
                                            return FadeTransition(
                                              opacity: animation,
                                              child: child,
                                            );
                                          },
                                      transitionDuration: const Duration(
                                        milliseconds: 300,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'Let\'s login to your account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, color: Colors.black87),
                      ),
                      const SizedBox(height: 35),

                      // Logo
                      Center(
                        child: Image.asset(
                          'assets/images/working.png',
                          width: 200,
                          height: 200,
                          fit: BoxFit.contain,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        enableSuggestions: false, // Try to disable suggestions
                        autocorrect: false,
                        autofillHints: const [], // Disable autofill hints
                        decoration: InputDecoration(
                          labelText: 'Admin Email',
                          hintText: 'Enter admin email',
                          prefixIcon: Icon(
                            Icons.email_rounded,
                            color: Colors.green.shade700,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: Colors.green.shade700,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Please enter admin email' : null,
                      ),

                      const SizedBox(height: 18),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        enableSuggestions: false,
                        autocorrect: false,
                        autofillHints: const [],
                        decoration: InputDecoration(
                          labelText: 'Admin Password',
                          hintText: 'Enter admin password',
                          prefixIcon: Icon(
                            Icons.lock_rounded,
                            color: Colors.green.shade700,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey.shade600,
                            ),
                            onPressed: () => setState(() {
                              _obscurePassword = !_obscurePassword;
                            }),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: Colors.green.shade700,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Please enter password' : null,
                      ),

                      const SizedBox(height: 30),

                      // Login Button
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () async {
                            if (_formKey.currentState!.validate()) {
                              setState(() => _isLoading = true);
                              try {
                                // 1. Sign In
                                UserCredential cred = await AuthService().signInWithEmailAndPassword(
                                  _emailController.text.trim(),
                                  _passwordController.text.trim(),
                                );

                                // 2. Check Role
                                if (cred.user != null) {
                                  await DatabaseService().ensureUserExistsInFirestore(cred.user!.uid);
                                  print('🔍 Checking role for UID: ${cred.user!.uid}');
                                  String? role = await DatabaseService().getUserRole(cred.user!.uid);
                                  print('🔍 Role result: "$role"');
                                  
                                  if (role == 'admin') {
                                    if (mounted) {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const DashboardScreen(),
                                        ),
                                      );
                                    }
                                  } else {
                                    print('❌ Access Denied. Unexpected Role: "$role"');
                                    await AuthService().signOut();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          duration: const Duration(seconds: 10),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Access Denied: Role is "$role"'),
                                              const SizedBox(height: 4),
                                              Text('UID: ${cred.user!.uid}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                              const Text('Make sure your "admins" document ID matches this UID!', style: TextStyle(fontSize: 10)),
                                            ],
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Login Failed: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _isLoading = false);
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: _isLoading 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text(
                                'Login as Admin',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                        ),
                      ),

                      // RE-ADDED TO HELP FIX LOGIN ISSUES
                      Center(
                        child: TextButton(
                          onPressed: _seedAdmin,
                          child: const Text(
                            ' Admin Account',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // DEVELOPMENT ONLY: Seed a default admin account
  Future<void> _seedAdmin() async {
    setState(() => _isLoading = true);
    try {
      // 1. Try to register
      UserCredential cred = await AuthService().registerWithEmailAndPassword(
        'admin@gmail.com',
        'admin123',
      );

      // 2. Create Admin Document if registration succeeded
      if (cred.user != null) {
        final adminUser = UserModel(
          uid: cred.user!.uid,
          name: 'Super Admin',
          email: 'admin@gmail.com',
          role: 'admin',
          createdAt: DateTime.now(),
        );
        await DatabaseService().createUser(adminUser);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Admin Account Fixed! You can now login.'),
              backgroundColor: Colors.green,
            ),
          );
          _emailController.text = 'admin@gmail.com';
          _passwordController.text = 'admin123';
        }
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Error: $e';
        if (e.toString().contains('email-already-in-use')) {
           msg = '⚠️ Email already exists. Go to Firebase Console -> Authentication and DELETE this user first!';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            content: Text(msg),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildToggleButton(
    String text, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
