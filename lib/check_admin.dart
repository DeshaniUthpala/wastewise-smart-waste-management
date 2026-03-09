import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Diagnostic script to check admin account and verify it's in the correct collection
/// Run with: flutter run lib/check_admin.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('\n========================================');
  print('🔍 ADMIN ACCOUNT DIAGNOSTIC');
  print('========================================\n');

  final auth = FirebaseAuth.instance;
  final db = FirebaseFirestore.instance;
  final dbService = DatabaseService();

  // Check Firebase Auth users
  print('📋 Checking Firebase Authentication...');
  try {
    // Try to find user by email (requires Admin SDK in production, but we can check after login)
    print('   Note: Cannot query all users without Admin SDK');
    print('   Current authenticated user: ${auth.currentUser?.email ?? "None"}');
  } catch (e) {
    print('   Error: $e');
  }

  // Check Firestore Collections
  print('\n📋 Checking Firestore ADMINS collection...');
  final adminsSnapshot = await db.collection('admins').get();
  print('   Found: ${adminsSnapshot.docs.length} admins');
  for (var doc in adminsSnapshot.docs) {
    final data = doc.data();
    print('   - ${data['name'] ?? 'No name'} (${data['email'] ?? 'No email'}) [UID: ${doc.id}]');
  }

  print('\n📋 Checking Firestore CITIZENS collection for admin@gmail.com...');
  final citizensSnapshot = await db.collection('citizens').get();
  bool foundInCitizens = false;
  for (var doc in citizensSnapshot.docs) {
    final data = doc.data();
    if (data['email'] == 'admin@gmail.com') {
      print('   ⚠️  FOUND admin@gmail.com in CITIZENS collection!');
      print('      UID: ${doc.id}');
      print('      Role: ${data['role']}');
      print('      This is the problem! Admin should be in admins collection.');
      foundInCitizens = true;

      // FIX IT: Move to admins collection
      print('\n🔧 FIXING: Moving to admins collection...');
      try {
        await dbService.changeUserRole(doc.id, 'admin');
        print('   ✅ Successfully moved to admins collection!');
      } catch (e) {
        print('   ❌ Failed to move: $e');
      }
    }
  }
  if (!foundInCitizens) {
    print('   Not found in citizens collection');
  }

  print('\n📋 Checking Firestore DRIVERS collection for admin@gmail.com...');
  final driversSnapshot = await db.collection('drivers').get();
  bool foundInDrivers = false;
  for (var doc in driversSnapshot.docs) {
    final data = doc.data();
    if (data['email'] == 'admin@gmail.com') {
      print('   ⚠️  FOUND admin@gmail.com in DRIVERS collection!');
      print('      UID: ${doc.id}');
      print('      Role: ${data['role']}');
      print('      This is the problem! Admin should be in admins collection.');
      foundInDrivers = true;

      // FIX IT: Move to admins collection
      print('\n🔧 FIXING: Moving to admins collection...');
      try {
        await dbService.changeUserRole(doc.id, 'admin');
        print('   ✅ Successfully moved to admins collection!');
      } catch (e) {
        print('   ❌ Failed to move: $e');
      }
    }
  }
  if (!foundInDrivers) {
    print('   Not found in drivers collection');
  }

  // Final verification
  print('\n========================================');
  print('📊 FINAL VERIFICATION');
  print('========================================\n');

  final finalAdminsSnapshot = await db.collection('admins').get();
  print('Total admins in correct collection: ${finalAdminsSnapshot.docs.length}');
  for (var doc in finalAdminsSnapshot.docs) {
    final data = doc.data();
    print('   - ${data['email']} [UID: ${doc.id}]');
  }

  if (finalAdminsSnapshot.docs.isEmpty) {
    print('\n❌ NO ADMINS FOUND!');
    print('   Solution: Go to admin login screen and click "Admin Account" button');
    print('   Or manually create an admin in Firebase Console.');
  } else {
    print('\n✅ Admin account(s) found and ready!');
    print('   You can now login with: admin@gmail.com / admin123');
  }

  print('\n========================================\n');
}
