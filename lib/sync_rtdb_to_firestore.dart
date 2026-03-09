import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

/// Script to sync users exclusively from RTDB to Firestore
/// Use this if you have data in RTDB but "User Not Found" in the app (which uses Firestore)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('\n========================================');
  print('🔄 SYNCING RTDB USERS TO FIRESTORE');
  print('========================================\n');

  final firestore = FirebaseFirestore.instance;
  final rtdb = FirebaseDatabase.instance.ref();

  // 1. Sync 'users' node (Legacy/Generic)
  print('📂 Reading RTDB "users" node...');
  final usersSnapshot = await rtdb.child('users').get();
  
  if (usersSnapshot.exists) {
    Map<dynamic, dynamic> users = usersSnapshot.value as Map<dynamic, dynamic>;
    print('   Found ${users.length} users in RTDB/users');
    
    for (var entry in users.entries) {
      String uid = entry.key;
      Map<String, dynamic> userData = Map<String, dynamic>.from(entry.value as Map);
      
      String role = userData['role'] ?? 'citizen'; // Default to citizen
      
      print('   Processing $uid ($role)...');
      
      // Determine target collection based on role
      CollectionReference targetCol;
      if (role == 'driver') {
        targetCol = firestore.collection('drivers');
      } else if (role == 'admin') {
        targetCol = firestore.collection('admins');
      } else {
        targetCol = firestore.collection('citizens');
      }
      
      // Check if exists in Firestore
      final doc = await targetCol.doc(uid).get();
      if (!doc.exists) {
        // Fix Timestamp fields (RTDB stores as int/string, Firestore needs Timestamp)
        if (userData['createdAt'] is int) {
           userData['createdAt'] = Timestamp.fromMillisecondsSinceEpoch(userData['createdAt']);
        } else if (userData['createdAt'] is String) {
           // Try parsing or default
           userData['createdAt'] = Timestamp.now();
        }
        
        if (userData['lastLogin'] is int) {
           userData['lastLogin'] = Timestamp.fromMillisecondsSinceEpoch(userData['lastLogin']);
        }

        // Write to Firestore
        await targetCol.doc(uid).set(userData);
        print('   ✅ Restored to Firestore ${targetCol.path}');
      } else {
        print('   Example: Already exists in Firestore');
      }
    }
  } else {
    print('   ⚠️ No users found in RTDB/users');
  }

  // 2. Sync 'citizens' node
  print('\n📂 Reading RTDB "citizens" node...');
  final citizensSnapshot = await rtdb.child('citizens').get();
  if (citizensSnapshot.exists) {
    Map<dynamic, dynamic> citizens = citizensSnapshot.value as Map<dynamic, dynamic>;
    print('   Found ${citizens.length} citizens');
    await _syncCollection(citizens, firestore.collection('citizens'));
  }

  // 3. Sync 'drivers' node
  print('\n📂 Reading RTDB "drivers" node...');
  final driversSnapshot = await rtdb.child('drivers').get();
  if (driversSnapshot.exists) {
    Map<dynamic, dynamic> drivers = driversSnapshot.value as Map<dynamic, dynamic>;
    print('   Found ${drivers.length} drivers');
    await _syncCollection(drivers, firestore.collection('drivers'));
  }
  
  print('\n========================================');
  print('✅ SYNC COMPLETE');
  print('   Please restart the app to verify.');
  print('========================================\n');
}

Future<void> _syncCollection(Map<dynamic, dynamic> rtdbData, CollectionReference firestoreCol) async {
  for (var entry in rtdbData.entries) {
    String uid = entry.key;
    Map<String, dynamic> userData = Map<String, dynamic>.from(entry.value as Map);
    
    final doc = await firestoreCol.doc(uid).get();
    if (!doc.exists) {
       // Convert Timestamps
       if (userData['createdAt'] is int) {
           userData['createdAt'] = Timestamp.fromMillisecondsSinceEpoch(userData['createdAt']);
       }
       
       await firestoreCol.doc(uid).set(userData);
       print('   ✅ Restored user $uid to Firestore');
    } else {
      print('   ⏭️ User $uid already exists in Firestore');
    }
  }
}
