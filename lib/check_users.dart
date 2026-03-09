import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Simple script to check if users exist in Firestore and sync them to RTDB
/// Run with: flutter run lib/check_users.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('\n========================================');
  print('🔍 CHECKING FIRESTORE FOR USERS...');
  print('========================================\n');

  final db = FirebaseFirestore.instance;
  
  // Check Citizens
  print('📋 Checking CITIZENS collection...');
  final citizensSnapshot = await db.collection('citizens').get();
  print('   Found: ${citizensSnapshot.docs.length} citizens');
  for (var doc in citizensSnapshot.docs) {
    final data = doc.data();
    print('   - ${data['name'] ?? 'No name'} (${data['email'] ?? 'No email'})');
  }
  
  // Check Drivers
  print('\n📋 Checking DRIVERS collection...');
  final driversSnapshot = await db.collection('drivers').get();
  print('   Found: ${driversSnapshot.docs.length} drivers');
  for (var doc in driversSnapshot.docs) {
    final data = doc.data();
    print('   - ${data['name'] ?? 'No name'} (${data['email'] ?? 'No email'})');
  }
  
  // Check Admins
  print('\n📋 Checking ADMINS collection...');
  final adminsSnapshot = await db.collection('admins').get();
  print('   Found: ${adminsSnapshot.docs.length} admins');
  for (var doc in adminsSnapshot.docs) {
    final data = doc.data();
    print('   - ${data['name'] ?? 'No name'} (${data['email'] ?? 'No email'})');
  }
  
  final totalUsers = citizensSnapshot.docs.length + 
                     driversSnapshot.docs.length + 
                     adminsSnapshot.docs.length;
  
  print('\n========================================');
  print('📊 TOTAL USERS IN FIRESTORE: $totalUsers');
  print('========================================\n');
  
  if (totalUsers == 0) {
    print('❌ NO USERS FOUND IN FIRESTORE!');
    print('   This is why users are not showing in RTDB.');
    print('   You need to CREATE users first by:');
    print('   1. Registering new users in your app');
    print('   2. Or adding users through admin panel');
    print('\n   Once users exist in Firestore, they will sync to RTDB.\n');
  } else {
    print('✅ Users found! Now syncing to RTDB...\n');
    
    try {
      await DatabaseService().syncUsersToRTDB();
      print('\n✅ SYNC COMPLETED!');
      print('   Check Firebase RTDB: https://wasteapp-93fd6-default-rtdb.firebaseio.com/');
      print('   You should now see citizens/, drivers/, and admins/ nodes.\n');
    } catch (e) {
      print('\n❌ SYNC FAILED: $e\n');
    }
  }
  
  print('========================================\n');
}
