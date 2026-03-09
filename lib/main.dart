import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/request_pickup_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/report_issue_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/map_screen.dart';
import 'screens/rewards_screen.dart';
import 'screens/activity_history_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'utils/app_colors.dart';
import 'screens/auth/admin_login_screen.dart';
import 'screens/auth/driver_login_screen.dart';
import 'screens/admin/admin_home_page.dart';
import 'screens/admin/admin_profile_screen.dart';
import 'services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // CLEAR PERSISTENCE TO FIX "INTERNAL ASSERTION FAILED"
  try {
    await FirebaseFirestore.instance.clearPersistence();
    print('✅ Firestore persistence cleared');
  } catch (e) {
    print('⚠️ Compacting persistence instead');
  }

  // Sync existing Firestore users to Realtime Database - DISABLED FOR PERFORMANCE AND SECURITY
  // try {
  //   print('🔄 Syncing users to RTDB on startup...');
  //   await DatabaseService().syncUsersToRTDB();
  //   print('✅ User sync completed!');
  // } catch (e) {
  //   print('⚠️ User sync warning: $e');
  // }

  runApp(const WasteWiseApp());
}

class WasteWiseApp extends StatelessWidget {
  const WasteWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WasteWise',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primaryGreen,
        scaffoldBackgroundColor: AppColors.backgroundGreenTint,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryGreen,
          primary: AppColors.primaryGreen,
          secondary: AppColors.secondaryGreen,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            shadowColor: AppColors.accentGreen.withOpacity(0.4),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.accentGreen, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const HomeScreen(),
        '/request-pickup': (context) => const RequestPickupScreen(),
        '/schedule': (context) => const ScheduleScreen(),
        '/report-issue': (context) => const ReportIssueScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/map': (context) => const MapScreen(),
        '/rewards': (context) => const RewardsScreen(),
        '/activity-history': (context) => const ActivityHistoryScreen(),
        '/privacy-policy': (context) => const PrivacyPolicyScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/admin-login': (context) => const AdminLoginScreen(),
        '/driver-login': (context) => const DriverLoginScreen(),
        '/admin-panel': (context) => const DashboardScreen(),
        '/admin-profile': (context) => const AdminProfileScreen(),
      },
    );
  }
}



