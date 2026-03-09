import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/route_model.dart';

import 'package:firebase_database/firebase_database.dart';

/// Helper class to initialize Firebase with default data
class FirebaseInitializer {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final DatabaseReference _rtdb = FirebaseDatabase.instance.ref();

  /// Initialize default waste types
  Future<void> initializeWasteTypes() async {
    try {
      print('🗑️ Initializing default waste types...');
      
      // TEST RTDB CONNECTION
      try {
        await _rtdb.child('_connection_test').set({
          'status': 'connected', 
          'timestamp': DateTime.now().toIso8601String(),
          'device': 'android_emulator_or_device'
        });
        print('✅ RTDB Connection Test PASSED - Data written to _connection_test');
      } catch (e) {
        print('❌ RTDB Connection Test FAILED: $e');
        print('⚠️ Make sure your databaseURL in firebase_options.dart matches your Console URL!');
      }

      final wasteTypesCollection = _db.collection('wasteTypes');

      // Check if waste types already exist in Firestore
      final existingTypes = await wasteTypesCollection.limit(1).get();
      // Check if waste types exist in RTDB
      final rtdbSnapshot = await _rtdb.child('wasteTypes').limitToFirst(1).get();

      final bool firestoreExists = existingTypes.docs.isNotEmpty;
      final bool rtdbExists = rtdbSnapshot.exists;
      
      print('🔍 STATUS: Firestore Data Exists: $firestoreExists | RTDB Data Exists: $rtdbExists');

      if (firestoreExists && rtdbExists) {
        print('ℹ️ Waste types already initialized in both DBs - Skipping');
        return;
      }

      // Default waste types
      final defaultWasteTypes = [
        WasteTypeModel(
          name: 'Organic Waste',
          category: 'Organic',
          description: 'Food scraps, garden waste, biodegradable materials',
          color: '#4CAF50',
          isRecyclable: false,
          disposalInstructions: [
            'Separate food waste from packaging',
            'Use compostable bags if possible',
            'No plastic or metal should be mixed',
          ],
        ),
        WasteTypeModel(
          name: 'Plastic',
          category: 'Recyclable',
          description: 'Plastic bottles, containers, packaging',
          color: '#2196F3',
          isRecyclable: true,
          disposalInstructions: [
            'Clean and dry plastic items',
            'Remove caps and labels',
            'Crush bottles to save space',
          ],
        ),
        WasteTypeModel(
          name: 'Paper & Cardboard',
          category: 'Recyclable',
          description: 'Newspapers, magazines, cardboard boxes',
          color: '#FF9800',
          isRecyclable: true,
          disposalInstructions: [
            'Keep paper dry',
            'Flatten cardboard boxes',
            'Remove any non-paper materials',
          ],
        ),
        WasteTypeModel(
          name: 'Glass',
          category: 'Recyclable',
          description: 'Glass bottles and jars',
          color: '#00BCD4',
          isRecyclable: true,
          disposalInstructions: [
            'Rinse glass containers',
            'Remove metal lids and caps',
            'Separate by color if required',
          ],
        ),
        WasteTypeModel(
          name: 'Metal',
          category: 'Recyclable',
          description: 'Aluminum cans, tin cans, metal scraps',
          color: '#9E9E9E',
          isRecyclable: true,
          disposalInstructions: [
            'Rinse metal containers',
            'Crush cans to save space',
            'Remove labels if possible',
          ],
        ),
        WasteTypeModel(
          name: 'Electronic Waste',
          category: 'Electronic',
          description: 'Old electronics, batteries, circuit boards',
          color: '#673AB7',
          isRecyclable: true,
          disposalInstructions: [
            'Do not throw in regular trash',
            'Remove batteries separately',
            'Take to designated e-waste collection centers',
            'Data should be erased from devices',
          ],
        ),
        WasteTypeModel(
          name: 'Hazardous Waste',
          category: 'Hazardous',
          description: 'Chemicals, paints, medicines, batteries',
          color: '#F44336',
          isRecyclable: false,
          disposalInstructions: [
            'Keep in original containers',
            'Never mix different chemicals',
            'Take to hazardous waste facility',
            'Do not pour down drains',
          ],
        ),
        WasteTypeModel(
          name: 'General Waste',
          category: 'General',
          description: 'Non-recyclable, non-hazardous waste',
          color: '#607D8B',
          isRecyclable: false,
          disposalInstructions: [
            'Items that cannot be recycled or composted',
            'Use appropriate waste bags',
            'Dispose in general waste bins',
          ],
        ),
        WasteTypeModel(
          name: 'Textiles',
          category: 'Recyclable',
          description: 'Old clothes, fabrics, shoes',
          color: '#E91E63',
          isRecyclable: true,
          disposalInstructions: [
            'Clean items before disposal',
            'Donate wearable items',
            'Separate by material type',
            'Use textile recycling bins',
          ],
        ),
        WasteTypeModel(
          name: 'Construction Waste',
          category: 'General',
          description: 'Concrete, bricks, tiles, wood',
          color: '#795548',
          isRecyclable: false,
          disposalInstructions: [
            'Arrange for special collection',
            'Separate wood, metal, and concrete',
            'Some materials may be recyclable',
            'Contact waste management for large amounts',
          ],
        ),
      ];



      // Add all waste types
      for (final wasteType in defaultWasteTypes) {
        // Add to Firestore if missing
        if (!firestoreExists) {
          final docRef = await wasteTypesCollection.add(wasteType.toMap());
          // Sync to RTDB using same ID
          await _rtdb.child('wasteTypes').child(docRef.id).set(wasteType.toMap());
          print('✅ Added to Firestore & RTDB: ${wasteType.name}');
        } else if (!rtdbExists) {
           // Firestore exists but RTDB doesn't - Backfill RTDB
           print('⚠️ Backfilling Waste Type to RTDB: ${wasteType.name}');
           await _rtdb.child('wasteTypes').push().set(wasteType.toMap());
           print('✅ Backfilled to RTDB: ${wasteType.name}');
        }
      }

      print('✅ Default waste types initialized successfully!');
    } catch (e) {
      print('❌ Error initializing waste types: $e');
    }
  }

  /// Initialize sample schedules for different areas
  Future<void> initializeSampleSchedules() async {
    try {
      print('📅 Initializing sample schedules...');

      final schedulesCollection = _db.collection('schedules');

      // Check if schedules already exist
      final existingSchedules = await schedulesCollection.limit(1).get();
      final rtdbSnapshot = await _rtdb.child('schedules').limitToFirst(1).get();
      
      final bool firestoreExists = existingSchedules.docs.isNotEmpty;
      final bool rtdbExists = rtdbSnapshot.exists;

      if (firestoreExists && rtdbExists) {
        print('ℹ️ Schedules already initialized in both DBs');
        return;
      }

      // Sample schedules
      final defaultSchedules = [
        {
          'area': 'Downtown Area',
          'wasteType': 'Organic Waste',
          'daysOfWeek': ['Monday', 'Thursday'],
          'collectionTime': '07:00 AM',
          'isActive': true,
          'createdAt': Timestamp.now(),
          'description': 'Organic waste collection for downtown residential areas',
        },
        {
          'area': 'Downtown Area',
          'wasteType': 'Recyclable',
          'daysOfWeek': ['Tuesday', 'Friday'],
          'collectionTime': '08:00 AM',
          'isActive': true,
          'createdAt': Timestamp.now(),
          'description': 'Recyclable materials collection',
        },
        {
          'area': 'Suburban Zone',
          'wasteType': 'General Waste',
          'daysOfWeek': ['Wednesday', 'Saturday'],
          'collectionTime': '06:00 AM',
          'isActive': true,
          'createdAt': Timestamp.now(),
          'description': 'General waste collection for suburban areas',
        },
        {
          'area': 'Industrial Area',
          'wasteType': 'General Waste',
          'daysOfWeek': ['Monday', 'Wednesday', 'Friday'],
          'collectionTime': '09:00 AM',
          'isActive': true,
          'createdAt': Timestamp.now(),
          'description': 'Industrial area waste collection',
        },
      ];

      for (final schedule in defaultSchedules) {
        // Convert Timestamp to milliseconds for RTDB explicitly if needed, but let's try direct map
        final Map<String, dynamic> scheduleData = Map.from(schedule);
        
        // RTDB adjustment
        if (scheduleData['createdAt'] is Timestamp) {
           scheduleData['createdAt'] = (scheduleData['createdAt'] as Timestamp).millisecondsSinceEpoch;
        }
        
        if (!firestoreExists) {
            final docRef = await schedulesCollection.add(schedule);
             await _rtdb.child('schedules').child(docRef.id).set(scheduleData);
             print('✅ Added schedule to Firestore & RTDB: ${schedule['area']}');
        } else if (!rtdbExists) {
             await _rtdb.child('schedules').push().set(scheduleData);
             print('✅ Backfilled schedule to RTDB: ${schedule['area']}');
        }
      }

      print('✅ Sample schedules initialized successfully!');
    } catch (e) {
      print('❌ Error initializing schedules: $e');
    }
  }

  /// Run all initializations
  Future<void> initializeAll() async {
    print('🚀 Starting Firebase initialization...\n');
    
    await initializeWasteTypes();
    print('');
    await initializeSampleSchedules();
    
    print('\n✨ Firebase initialization completed!');
  }
}
