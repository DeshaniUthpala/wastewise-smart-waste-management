import 'package:flutter/material.dart';
import 'services/database_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

/// Quick test script to manually sync users to RTDB
/// Run this with: flutter run lib/test_sync.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('🔄 Starting manual user sync...');
  
  try {
    await DatabaseService().syncUsersToRTDB();
    print('✅ Sync completed successfully!');
  } catch (e) {
    print('❌ Sync failed: $e');
  }
  
  // Exit after sync
  print('Exiting...');
}
