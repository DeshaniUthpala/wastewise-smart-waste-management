import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

/// Creates a test user in Firestore and syncs to RTDB
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('\n🔍 Checking for users in Firestore...\n');

  final firestore = FirebaseFirestore.instance;
  final rtdb = FirebaseDatabase.instance.ref();
  
  // Check citizens
  final citizensSnapshot = await firestore.collection('citizens').get();
  print('Citizens in Firestore: ${citizensSnapshot.docs.length}');
  
  // Check drivers
  final driversSnapshot = await firestore.collection('drivers').get();
  print('Drivers in Firestore: ${driversSnapshot.docs.length}');
  
  // Check admins
  final adminsSnapshot = await firestore.collection('admins').get();
  print('Admins in Firestore: ${adminsSnapshot.docs.length}');
  
  final total = citizensSnapshot.docs.length + driversSnapshot.docs.length + adminsSnapshot.docs.length;
  
  print('\nTotal users in Firestore: $total\n');
  
  if (total == 0) {
    print('❌ NO USERS FOUND!');
    print('Creating a test user...\n');
    
    // Create test user
    final testUser = {
      'uid': 'test_user_123',
      'name': 'Test User',
      'email': 'test@example.com',
      'role': 'citizen',
      'phone': '1234567890',
      'address': 'Test Address',
      'createdAt': Timestamp.now(),
    };
    
    // Add to Firestore
    await firestore.collection('citizens').doc('test_user_123').set(testUser);
    print('✅ Created test user in Firestore');
    
    // Add to RTDB
    await rtdb.child('citizens').child('test_user_123').set({
      'uid': 'test_user_123',
      'name': 'Test User',
      'email': 'test@example.com',
      'role': 'citizen',
      'phone': '1234567890',
      'address': 'Test Address',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    print('✅ Created test user in RTDB');
    
    print('\n✅ DONE! Check Firebase Console:');
    print('   Firestore: citizens/test_user_123');
    print('   RTDB: https://wasteapp-93fd6-default-rtdb.firebaseio.com/citizens/test_user_123');
  } else {
    print('✅ Users found! Syncing to RTDB...\n');
    
    // Sync citizens
    for (var doc in citizensSnapshot.docs) {
      await rtdb.child('citizens').child(doc.id).set(doc.data());
    }
    print('✅ Synced ${citizensSnapshot.docs.length} citizens');
    
    // Sync drivers
    for (var doc in driversSnapshot.docs) {
      await rtdb.child('drivers').child(doc.id).set(doc.data());
    }
    print('✅ Synced ${driversSnapshot.docs.length} drivers');
    
    // Sync admins
    for (var doc in adminsSnapshot.docs) {
      await rtdb.child('admins').child(doc.id).set(doc.data());
    }
    print('✅ Synced ${adminsSnapshot.docs.length} admins');
    
    print('\n✅ ALL USERS SYNCED TO RTDB!');
    print('   Check: https://wasteapp-93fd6-default-rtdb.firebaseio.com/');
  }
  
  print('\n');
}
