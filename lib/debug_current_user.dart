import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Debug script to check current logged-in user and their Firestore data
/// Run with: flutter run lib/debug_current_user.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('\n========================================');
  print('🔍 CHECKING CURRENT USER...');
  print('========================================\n');

  final auth = FirebaseAuth.instance;
  final currentUser = auth.currentUser;
  
  if (currentUser == null) {
    print('❌ NO USER IS CURRENTLY LOGGED IN!');
    print('   Please log in first and try again.\n');
    return;
  }
  
  print('✅ Current User:');
  print('   UID: ${currentUser.uid}');
  print('   Email: ${currentUser.email}');
  print('   Display Name: ${currentUser.displayName ?? "Not set"}');
  
  print('\n========================================');
  print('🔍 CHECKING FIRESTORE FOR THIS USER...');
  print('========================================\n');
  
  final db = FirebaseFirestore.instance;
  final uid = currentUser.uid;
  
  // Check in citizens collection
  print('📋 Checking CITIZENS collection...');
  var doc = await db.collection('citizens').doc(uid).get();
  if (doc.exists) {
    print('   ✅ FOUND in citizens collection!');
    print('   Data: ${doc.data()}');
  } else {
    print('   ❌ NOT FOUND in citizens collection');
  }
  
  // Check in drivers collection
  print('\n📋 Checking DRIVERS collection...');
  doc = await db.collection('drivers').doc(uid).get();
  if (doc.exists) {
    print('   ✅ FOUND in drivers collection!');
    print('   Data: ${doc.data()}');
  } else {
    print('   ❌ NOT FOUND in drivers collection');
  }
  
  // Check in admins collection
  print('\n📋 Checking ADMINS collection...');
  doc = await db.collection('admins').doc(uid).get();
  if (doc.exists) {
    print('   ✅ FOUND in admins collection!');
    print('   Data: ${doc.data()}');
  } else {
    print('   ❌ NOT FOUND in admins collection');
  }
  
  // Check in users collection (fallback)
  print('\n📋 Checking USERS collection (fallback)...');
  doc = await db.collection('users').doc(uid).get();
  if (doc.exists) {
    print('   ✅ FOUND in users collection!');
    print('   Data: ${doc.data()}');
  } else {
    print('   ❌ NOT FOUND in users collection');
  }
  
  print('\n========================================');
  print('🔍 TESTING getUserRole METHOD...');
  print('========================================\n');
  
  try {
    final role = await DatabaseService().getUserRole(uid);
    print('   Role detected: $role');
  } catch (e) {
    print('   ❌ Error: $e');
  }
  
  print('\n========================================\n');
}
