import 'dart:async';
// import 'dart:io'; // Removed for web compatibility
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart' hide Query;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/pickup_request_model.dart';
import '../models/schedule_model.dart';
import '../models/route_model.dart';
import '../models/notification_model.dart';
import '../models/report_model.dart';
import '../models/vehicle_model.dart';
import '../models/task_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final DatabaseReference _rtdb = FirebaseDatabase.instance.ref();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ========== COLLECTION REFERENCES ==========
  
  CollectionReference get _usersCollection => _db.collection('users'); // For legacy/lookup
  CollectionReference get _citizensCollection => _db.collection('citizens');
  CollectionReference get _driversCollection => _db.collection('drivers');
  CollectionReference get _adminsCollection => _db.collection('admins');
  CollectionReference get _pickupRequestsCollection => _db.collection('pickupRequests');
  CollectionReference get _schedulesCollection => _db.collection('schedules');
  CollectionReference get _routesCollection => _db.collection('routes');
  CollectionReference get _wasteTypesCollection => _db.collection('wasteTypes');
  CollectionReference get _notificationsCollection => _db.collection('notifications');
  CollectionReference get _reportsCollection => _db.collection('reports');
  CollectionReference get _statisticsCollection => _db.collection('statistics');
  CollectionReference get _vehiclesCollection => _db.collection('vehicles');
  CollectionReference get _tasksCollection => _db.collection('tasks');
  CollectionReference get _countersCollection => _db.collection('_counters');
  static const int _pointsPerCompletedPickup = 10;

  Future<String?> _getUserRoleFromFirestoreOnly(String uid) async {
    // 1. Try Direct Lookup (Document ID == Auth UID)
    var doc = await _citizensCollection.doc(uid).get();
    if (doc.exists) return 'citizen';

    doc = await _driversCollection.doc(uid).get();
    if (doc.exists) return 'driver';

    doc = await _adminsCollection.doc(uid).get();
    if (doc.exists) return 'admin';

    doc = await _usersCollection.doc(uid).get();
    if (doc.exists) {
      return (doc.data() as Map<String, dynamic>)['role'] as String?;
    }

    // 2. Try Query Lookup (Field 'uid' == Auth UID) - Handle custom Document IDs
    // This is needed if the Document ID (Key) is diverse from the Auth UID
    var query = await _citizensCollection.where('uid', isEqualTo: uid).limit(1).get();
    if (query.docs.isNotEmpty) return 'citizen';

    query = await _driversCollection.where('uid', isEqualTo: uid).limit(1).get();
    if (query.docs.isNotEmpty) return 'driver';

    query = await _adminsCollection.where('uid', isEqualTo: uid).limit(1).get();
    if (query.docs.isNotEmpty) return 'admin';

    query = await _usersCollection.where('uid', isEqualTo: uid).limit(1).get();
    if (query.docs.isNotEmpty) {
      return (query.docs.first.data() as Map<String, dynamic>)['role'] as String?;
    }

    return null;
  }

  Future<String> _nextPrefixedId({
    required String counterKey,
    required String prefix,
    int pad = 3,
  }) async {
    final counterRef = _countersCollection.doc(counterKey);
    try {
      return await _db.runTransaction<String>((tx) async {
        final snap = await tx.get(counterRef);
        final current = snap.exists
            ? ((snap.data() as Map<String, dynamic>)['last'] ?? 0) as num
            : 0;
        final next = current.toInt() + 1;
        tx.set(counterRef, {
          'last': next,
          'updatedAt': Timestamp.now(),
        }, SetOptions(merge: true));
        return '$prefix${next.toString().padLeft(pad, '0')}';
      });
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      print('⚠️ Firestore counter denied for $counterKey. Falling back to RTDB ID scan.');
      return _nextPrefixedIdFromRtdb(
        counterKey: counterKey,
        prefix: prefix,
        pad: pad,
      );
    } catch (_) {
      return _nextPrefixedIdFromRtdb(
        counterKey: counterKey,
        prefix: prefix,
        pad: pad,
      );
    }
  }

  /// Recursively convert Map keys to String and ensure Map<String, dynamic>
  /// This fixes TypeErrors from Realtime Database LinkedMap<Object?, Object?>
  dynamic _recursiveConvert(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _recursiveConvert(v)));
    } else if (value is List) {
      return value.map((e) => _recursiveConvert(e)).toList();
    }
    return value;
  }

  ({String node, String idField}) _counterTarget(String counterKey) {
    switch (counterKey) {
      case 'citizen':
        return (node: 'citizens', idField: 'citizenId');
      case 'driver':
        return (node: 'drivers', idField: 'driverId');
      case 'admin':
        return (node: 'admins', idField: 'adminId');
      case 'schedule':
        return (node: 'schedules', idField: 'scheduleId');
      case 'notification':
        return (node: 'notifications', idField: 'notificationId');
      case 'report':
        return (node: 'reports', idField: 'reportId');
      case 'waste_type':
        return (node: 'wasteTypes', idField: 'wasteTypeId');
      default:
        return (node: counterKey, idField: 'customId');
    }
  }

  int _extractIdNumber(String? value, String prefix) {
    if (value == null) return 0;
    if (!value.startsWith(prefix)) return 0;
    final suffix = value.substring(prefix.length);
    return int.tryParse(suffix) ?? 0;
  }

  Future<String> _nextPrefixedIdFromRtdb({
    required String counterKey,
    required String prefix,
    required int pad,
  }) async {
    try {
      final target = _counterTarget(counterKey);
      final snap = await _rtdb.child(target.node).get();
      int maxValue = 0;

      if (snap.exists && snap.value is Map) {
        final data = Map<dynamic, dynamic>.from(snap.value as Map);
        for (final entry in data.entries) {
          if (entry.value is! Map) continue;
          final row = Map<dynamic, dynamic>.from(entry.value as Map);
          final fromPrimary = _extractIdNumber(row[target.idField]?.toString(), prefix);
          final fromCustom = _extractIdNumber(row['customId']?.toString(), prefix);
          if (fromPrimary > maxValue) maxValue = fromPrimary;
          if (fromCustom > maxValue) maxValue = fromCustom;
        }
      }

      final next = maxValue + 1;
      return '$prefix${next.toString().padLeft(pad, '0')}';
    } catch (_) {
      final fallback = DateTime.now().millisecondsSinceEpoch;
      return '$prefix$fallback';
    }
  }

  Future<(CollectionReference, String)?> _findUserCollectionAndDocId(
      String uid) async {
    final checks = <CollectionReference>[
      _citizensCollection,
      _driversCollection,
      _adminsCollection,
      _usersCollection,
    ];

    for (final col in checks) {
      final byId = await col.doc(uid).get();
      if (byId.exists) return (col, uid);

      final byUidField = await col.where('uid', isEqualTo: uid).limit(1).get();
      if (byUidField.docs.isNotEmpty) {
        return (col, byUidField.docs.first.id);
      }
    }
    return null;
  }

  Future<void> _updateUserInRtdbFallback(String uid, Map<String, dynamic> data) async {
    final roleNodes = ['citizens', 'drivers', 'admins', 'users'];
    bool updated = false;
    for (final node in roleNodes) {
      final directRef = _rtdb.child(node).child(uid);
      final directSnap = await directRef.get();
      if (directSnap.exists) {
        await directRef.update(data);
        updated = true;
      }
    }

    if (!updated) {
      // Last fallback: keep data writable even when user record was keyed incorrectly.
      await _rtdb.child('users').child(uid).update(data);
    }
  }

  // ========== USER OPERATIONS ==========

  /// Create or Update User Data
  Future<void> createUser(UserModel user) async {
    try {
      print('Starting user creation for:  ()');
      final rawMap = user.toMap();
      final userMap = Map<String, dynamic>.from(rawMap);

      String? customId;
      try {
        if (user.role == 'citizen') {
          customId = await _nextPrefixedId(counterKey: 'citizen', prefix: 'citi');
          userMap['citizenId'] = customId;
        } else if (user.role == 'driver') {
          customId = await _nextPrefixedId(counterKey: 'driver', prefix: 'dri');
          userMap['driverId'] = customId;
        } else if (user.role == 'admin') {
          customId = await _nextPrefixedId(counterKey: 'admin', prefix: 'ad');
          userMap['adminId'] = customId;
        }
      } catch (e) {
        print('Counter generation failed, using timestamp fallback: ');
        customId = '';
      }

      if (customId != null) {
        userMap['customId'] = customId;
      }

      // Convert map for RTDB (replace Timestamps with ints)
      final rtdbMap = _convertToRtdb(userMap);

      // Save to role-specific collection
      final collection = user.role == 'citizen'
          ? _citizensCollection
          : user.role == 'driver'
              ? _driversCollection
              : user.role == 'admin'
                  ? _adminsCollection
                  : _usersCollection;

      final rtdbNode = user.role == 'citizen'
          ? 'citizens'
          : user.role == 'driver'
              ? 'drivers'
              : user.role == 'admin'
                  ? 'admins'
                  : 'users';

      bool wroteRtdb = false;
      Object? rtdbError;
      print('Saving to RTDB node: $rtdbNode');
      try {
        await _rtdb.child(rtdbNode).child(user.uid).set(rtdbMap);
        wroteRtdb = true;
        print('RTDB save successful');
      } catch (e) {
        rtdbError = e;
      }

      bool wroteFirestore = false;
      Object? firestoreError;
      print('Saving document to Firestore collection: ${collection.path}');
      try {
        await collection.doc(user.uid).set(userMap);
        wroteFirestore = true;
        print('Firestore save successful');
      } on FirebaseException catch (e) {
        firestoreError = e;
        if (e.code != 'permission-denied') rethrow;
        print('Firestore permission denied on createUser, continuing with RTDB data.');
      } catch (e) {
        firestoreError = e;
      }

      if (!wroteRtdb && !wroteFirestore) {
        throw Exception(
          'Failed to save user profile. RTDB: $rtdbError, Firestore: $firestoreError',
        );
      }

      print('User registration flow complete for ${user.uid}');
    } catch (e) {
      print('Fatal error in createUser: $e');
      rethrow;
    }
  }

  /// Helper to convert Firestore types (Timestamp) to RTDB types (int)
  dynamic _convertToRtdb(dynamic value) {
    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    } else if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _convertToRtdb(v)));
    } else if (value is List) {
      return value.map((e) => _convertToRtdb(e)).toList();
    }
    return value;
  }

  /// Update User Data (merge)
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      print('ðŸ’¾ Updating user data for UID: $uid');
      
      // CHECK IF ROLE IS BEING CHANGED
      if (data.containsKey('role')) {
        String newRole = data['role'];
        
        // Get current role
        String? currentRole = await getUserRole(uid);
        
        if (currentRole != null && currentRole != newRole) {
          print('ðŸ”„ Role change detected: $currentRole â†’ $newRole');
          
          // Use the dedicated changeUserRole method which properly moves the document
          await changeUserRole(uid, newRole);
          
          // Remove 'role' from data since it was already handled
          data = Map.from(data)..remove('role');
          
          // If there are other fields to update, continue with normal update
          if (data.isEmpty) {
            print('âœ… Role change completed');
            return;
          }
        }
      }
      
      // NORMAL UPDATE (no role change)
      final target = await _findUserCollectionAndDocId(uid);
      final collection = target?.$1 ?? _usersCollection;
      final docId = target?.$2 ?? uid;

      await collection.doc(docId).set(data, SetOptions(merge: true))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Firestore write timed out after 10 seconds');
            },
          );
      
      // Update Realtime Database as well
      await _updateUserInRtdbFallback(uid, data);

      print('âœ… User data updated successfully');
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // Keep profile editable even when Firestore rules/data shape are still migrating.
        await _updateUserInRtdbFallback(uid, data);
        return;
      }
      print('âŒ Firestore error: $e');
      rethrow;
    } catch (e) {
      print('âŒ Firestore error: $e');
      rethrow;
    }
  }

  /// Get User by ID
  Future<UserModel?> getUser(String uid) async {
    try {
      // Helper to find doc by Key or Field
      Future<DocumentSnapshot?> findDoc(CollectionReference col) async {
        final d = await col.doc(uid).get();
        if (d.exists) return d;
        final q = await col.where('uid', isEqualTo: uid).limit(1).get();
        if (q.docs.isNotEmpty) return q.docs.first;
        return null;
      }

      // Try to find in Citizens
      var doc = await findDoc(_citizensCollection);
      if (doc != null) {
        return CitizenModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      
      // Try Drivers
      doc = await findDoc(_driversCollection);
      if (doc != null) {
        return DriverModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      
      // Try Admins
      doc = await findDoc(_adminsCollection);
      if (doc != null) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }

      // Try Legacy Users
      doc = await findDoc(_usersCollection);
      if (doc != null) {
        return _parseUserModelByRole(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }
      
      return null;
    } catch (e) {
      print('❌ Error getting user: $e');
      return null;
    }
  }

  UserModel _parseUserModelByRole(Map<String, dynamic> data, String uid) {
    final role = (data['role'] ?? '').toString().toLowerCase();
    if (role == 'citizen') {
      return CitizenModel.fromMap(data, uid);
    }
    if (role == 'driver') {
      return DriverModel.fromMap(data, uid);
    }
    return UserModel.fromMap(data, uid);
  }

  /// Get User Stream (real-time)
  Stream<UserModel?> getUserStream(String uid) {
    print('getUserStream called for UID: $uid');

    final controller = StreamController<UserModel?>();
    Map<String, dynamic>? citizenData;
    String? citizenDocId;
    Map<String, dynamic>? driverData;
    String? driverDocId;
    Map<String, dynamic>? adminData;
    String? adminDocId;
    Map<String, dynamic>? legacyUserData;
    String? legacyDocId;

    // Track whether each listener has received its first snapshot
    bool citizenReady = false;
    bool driverReady = false;
    bool adminReady = false;
    bool legacyReady = false;
    bool allReady = false;

    // Fallback to RTDB if Firestore fails
    StreamSubscription? rtdbSub;
    void fallbackToRTDB(String uid, StreamController<UserModel?> controller) {
      if (rtdbSub != null) return; // Already listening to RTDB
      print('âš ï¸ Firestore failed. Falling back to RTDB for user $uid');
      
      // Try to find user in all RTDB collections
      // Note: This is a bit inefficient but necessary for fallback
      rtdbSub = _rtdb.child('citizens').orderByChild('uid').equalTo(uid).onValue.listen((event) {
          final data = event.snapshot.value as Map?;
          if (data != null && data.isNotEmpty) {
             final val = data.values.first as Map;
             controller.add(CitizenModel.fromMap(Map<String, dynamic>.from(val), uid));
             return;
          }
          // Try Drivers
           _rtdb.child('drivers').orderByChild('uid').equalTo(uid).once().then((dSnap) {
              final dData = dSnap.snapshot.value as Map?;
              if (dData != null && dData.isNotEmpty) {
                  final val = dData.values.first as Map;
                  controller.add(DriverModel.fromMap(Map<String, dynamic>.from(val), uid));
                  return;
              }
              // Try Admins
               _rtdb.child('admins').orderByChild('uid').equalTo(uid).once().then((aSnap) {
                  final aData = aSnap.snapshot.value as Map?;
                  if (aData != null && aData.isNotEmpty) {
                      final val = aData.values.first as Map;
                      controller.add(UserModel.fromMap(Map<String, dynamic>.from(val), uid));
                      return;
                  }
                   // Try Users (Legacy)
                   _rtdb.child('users').orderByChild('uid').equalTo(uid).once().then((uSnap) {
                      final uData = uSnap.snapshot.value as Map?;
                      if (uData != null && uData.isNotEmpty) {
                          final val = uData.values.first as Map;
                          controller.add(_parseUserModelByRole(Map<String, dynamic>.from(val), uid));
                          return;
                      }
                      controller.add(null);
                   });
               });
           });
      });
    }

    void emitUser() {
      if (controller.isClosed) return;

      // Don't emit until all listeners have reported in at least once
      if (!allReady) {
        if (citizenReady && driverReady && adminReady && legacyReady) {
          allReady = true;
        } else {
          // If one of the listeners found data, emit immediately
          if (citizenData != null || driverData != null ||
              adminData != null || legacyUserData != null) {
            allReady = true;
          } else {
            return; // wait for all listeners
          }
        }
      }

      if (citizenData != null) {
        // Use the actual document ID if found, otherwise assume Auth UID
        // This handles cases where user changed document ID to custom ID
        controller.add(CitizenModel.fromMap(citizenData!, citizenDocId ?? uid));
        return;
      }
      if (driverData != null) {
        controller.add(DriverModel.fromMap(driverData!, driverDocId ?? uid));
        return;
      }
      if (adminData != null) {
        controller.add(UserModel.fromMap(adminData!, adminDocId ?? uid));
        return;
      }
      if (legacyUserData != null) {
        controller.add(_parseUserModelByRole(legacyUserData!, legacyDocId ?? uid));
        return;
      }
      controller.add(null);
    }

    // Listen to queries instead of direct docs to handle Custom IDs
    final citizenSub = _citizensCollection
        .where('uid', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        citizenData = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        citizenDocId = doc.id;
      } else {
        citizenData = null;
        citizenDocId = null;
      }
      citizenReady = true;
      emitUser();
    }, onError: (e) {
      print('Firestore Citizen Error: $e');
      fallbackToRTDB(uid, controller);
    });

    final driverSub = _driversCollection
        .where('uid', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        driverData = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        driverDocId = doc.id;
      } else {
        driverData = null;
        driverDocId = null;
      }
      driverReady = true;
      emitUser();
    }, onError: (e) {
      print('Firestore Driver Error: $e');
      fallbackToRTDB(uid, controller);
    });

    final adminSub = _adminsCollection
        .where('uid', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        adminData = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        adminDocId = doc.id;
      } else {
        adminData = null;
        adminDocId = null;
      }
      adminReady = true;
      emitUser();
    }, onError: (e) {
      print('Firestore Admin Error: $e');
      fallbackToRTDB(uid, controller);
    });

    final usersSub = _usersCollection
        .where('uid', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        legacyUserData = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        legacyDocId = doc.id;
      } else {
        legacyUserData = null;
        legacyDocId = null;
      }
      legacyReady = true;
      emitUser();
    }, onError: (e) {
      print('Firestore Legacy Error: $e');
      fallbackToRTDB(uid, controller);
    });

    controller.onCancel = () async {
      await citizenSub.cancel();
      await driverSub.cancel();
      await adminSub.cancel();
      await usersSub.cancel();
      await controller.close();
      await rtdbSub?.cancel();
    };

    return controller.stream;
  }

  /// Get All Citizens Stream
  Stream<List<Map<String, dynamic>>> getCitizensStream({bool includeInactive = false}) {
    final controller = StreamController<List<Map<String, dynamic>>>();
    List<Map<String, dynamic>> firestoreRows = [];
    List<Map<String, dynamic>> rtdbRows = [];

    void emitCombined() {
      if (controller.isClosed) return;
      final merged = <String, Map<String, dynamic>>{};
      for (final item in [...firestoreRows, ...rtdbRows]) {
        final uid = (item['uid'] ?? '').toString();
        if (uid.isEmpty) continue;
        merged[uid] = item;
      }
      final rows = merged.values.where((item) {
        if (includeInactive) return true;
        return item['isActive'] != false;
      }).toList();
      controller.add(rows);
    }

    final fsSub = _citizensCollection.snapshots().listen((snapshot) {
      firestoreRows = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['uid'] = data['uid'] ?? doc.id;
        data['role'] = data['role'] ?? 'citizen';
        return data;
      }).toList();
      emitCombined();
    }, onError: (_) {
      firestoreRows = [];
      emitCombined();
    });

    final rtdbSub = getCitizensFromRTDB().listen((rows) {
      rtdbRows = rows.map((r) {
        final data = Map<String, dynamic>.from(r);
        data['role'] = data['role'] ?? 'citizen';
        return data;
      }).toList();
      emitCombined();
    }, onError: (_) {
      rtdbRows = [];
      emitCombined();
    });

    controller.onCancel = () async {
      await fsSub.cancel();
      await rtdbSub.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  /// Admin-friendly citizens stream from both `citizens` and legacy `users`.
  Stream<List<Map<String, dynamic>>> getAdminCitizensStream({bool includeInactive = false}) {
    final controller = StreamController<List<Map<String, dynamic>>>();
    List<Map<String, dynamic>> citizens = [];
    List<Map<String, dynamic>> legacyUsers = [];
    List<Map<String, dynamic>> rtdbCitizens = [];

    void emitCombined() {
      if (controller.isClosed) return;
      final merged = <String, Map<String, dynamic>>{};
      for (final item in [...legacyUsers, ...citizens, ...rtdbCitizens]) {
        final uid = item['uid'] as String?;
        if (uid == null || uid.isEmpty) continue;
        merged[uid] = item;
      }

      final rows = merged.values.where((item) {
        if (includeInactive) return true;
        return item['isActive'] != false;
      }).toList();

      rows.sort((a, b) {
        final aName = (a['name'] ?? '').toString().toLowerCase();
        final bName = (b['name'] ?? '').toString().toLowerCase();
        return aName.compareTo(bName);
      });

      controller.add(rows);
    }

    final citizensSub = _citizensCollection.snapshots().listen((snapshot) {
      citizens = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['uid'] = data['uid'] ?? doc.id;
        data['role'] = data['role'] ?? 'citizen';
        return data;
      }).toList();
      emitCombined();
    }, onError: (e) {
      citizens = [];
      emitCombined();
    });

    final usersSub =
        _usersCollection.where('role', isEqualTo: 'citizen').snapshots().listen((snapshot) {
      legacyUsers = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['uid'] = data['uid'] ?? doc.id;
        return data;
      }).toList();
      emitCombined();
    }, onError: (e) {
      legacyUsers = [];
      emitCombined();
    });

    final rtdbCitizensSub = getCitizensFromRTDB().listen((rows) {
      rtdbCitizens = rows.map((r) => Map<String, dynamic>.from(r)).toList();
      emitCombined();
    }, onError: (_) {});

    controller.onCancel = () async {
      await citizensSub.cancel();
      await usersSub.cancel();
      await rtdbCitizensSub.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  /// Get All Drivers Stream  
  Stream<List<Map<String, dynamic>>> getDriversStream({bool includeInactive = false}) {
    final controller = StreamController<List<Map<String, dynamic>>>();
    List<Map<String, dynamic>> firestoreRows = [];
    List<Map<String, dynamic>> rtdbRows = [];

    void emitCombined() {
      if (controller.isClosed) return;
      final merged = <String, Map<String, dynamic>>{};
      for (final item in [...firestoreRows, ...rtdbRows]) {
        final uid = (item['uid'] ?? '').toString();
        if (uid.isEmpty) continue;
        merged[uid] = item;
      }
      final rows = merged.values.where((item) {
        if (includeInactive) return true;
        return item['isActive'] != false;
      }).toList();
      controller.add(rows);
    }

    final fsSub = _driversCollection.snapshots().listen((snapshot) {
      firestoreRows = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['uid'] = data['uid'] ?? doc.id;
        data['role'] = data['role'] ?? 'driver';
        return data;
      }).toList();
      emitCombined();
    }, onError: (_) {
      firestoreRows = [];
      emitCombined();
    });

    final rtdbSub = getDriversFromRTDB().listen((rows) {
      rtdbRows = rows.map((r) {
        final data = Map<String, dynamic>.from(r);
        data['role'] = data['role'] ?? 'driver';
        return data;
      }).toList();
      emitCombined();
    }, onError: (_) {
      rtdbRows = [];
      emitCombined();
    });

    controller.onCancel = () async {
      await fsSub.cancel();
      await rtdbSub.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  /// Get All Drivers as Models
  Stream<List<DriverModel>> getDriverModelsStream({bool includeInactive = false}) {
    return getDriversStream(includeInactive: includeInactive).map((rows) {
      return rows.map((row) {
        final uid = (row['uid'] ?? '').toString();
        return DriverModel.fromMap(row, uid);
      }).toList();
    });
  }

  /// Admin view: merge drivers from both `drivers` and legacy `users` collections.
  Stream<List<Map<String, dynamic>>> getAdminDriversStream({bool includeInactive = false}) {
    final controller = StreamController<List<Map<String, dynamic>>>();
    List<Map<String, dynamic>> drivers = [];
    List<Map<String, dynamic>> legacyUsers = [];
    List<Map<String, dynamic>> rtdbDrivers = [];

    void emitCombined() {
      if (controller.isClosed) return;
      final merged = <String, Map<String, dynamic>>{};
      for (final item in [...legacyUsers, ...drivers, ...rtdbDrivers]) {
        final uid = item['uid'] as String?;
        if (uid == null || uid.isEmpty) continue;
        merged[uid] = item;
      }

      final rows = merged.values.where((item) {
        if (includeInactive) return true;
        return item['isActive'] != false;
      }).toList();

      rows.sort((a, b) {
        final aName = (a['name'] ?? '').toString().toLowerCase();
        final bName = (b['name'] ?? '').toString().toLowerCase();
        return aName.compareTo(bName);
      });
      controller.add(rows);
    }

    final driversSub = _driversCollection.snapshots().listen((snapshot) {
      drivers = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['uid'] = data['uid'] ?? doc.id;
        data['role'] = data['role'] ?? 'driver';
        return data;
      }).toList();
      emitCombined();
    }, onError: (e) {
      drivers = [];
      emitCombined();
    });

    final usersSub =
        _usersCollection.where('role', isEqualTo: 'driver').snapshots().listen((snapshot) {
      legacyUsers = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['uid'] = data['uid'] ?? doc.id;
        return data;
      }).toList();
      emitCombined();
    }, onError: (e) {
      legacyUsers = [];
      emitCombined();
    });

    final rtdbDriversSub = getDriversFromRTDB().listen((rows) {
      rtdbDrivers = rows.map((r) => Map<String, dynamic>.from(r)).toList();
      emitCombined();
    }, onError: (_) {});

    controller.onCancel = () async {
      await driversSub.cancel();
      await usersSub.cancel();
      await rtdbDriversSub.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  /// Display lookup map by uid across users, citizens, drivers, admins.
  Stream<Map<String, Map<String, dynamic>>> getAllUserDisplayMapStream() {
    final controller = StreamController<Map<String, Map<String, dynamic>>>();
    List<Map<String, dynamic>> fsUsers = [];
    List<Map<String, dynamic>> fsCitizens = [];
    List<Map<String, dynamic>> fsDrivers = [];
    List<Map<String, dynamic>> fsAdmins = [];
    List<Map<String, dynamic>> rtdbUsers = [];
    List<Map<String, dynamic>> rtdbCitizens = [];
    List<Map<String, dynamic>> rtdbDrivers = [];
    List<Map<String, dynamic>> rtdbAdmins = [];

    void emitCombined() {
      if (controller.isClosed) return;
      final map = <String, Map<String, dynamic>>{};
      final all = [
        ...fsUsers, ...fsCitizens, ...fsDrivers, ...fsAdmins,
        ...rtdbUsers, ...rtdbCitizens, ...rtdbDrivers, ...rtdbAdmins
      ];
      for (final item in all) {
        final uid = item['uid'] as String?;
        if (uid == null || uid.isEmpty) continue;
        // Merge data if already exists (preferring latest/most complete)
        if (map.containsKey(uid)) {
          map[uid] = {...map[uid]!, ...item};
        } else {
          map[uid] = item;
        }
      }
      controller.add(map);
    }

    final usersSub = _usersCollection.snapshots().listen((snapshot) {
      fsUsers = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['uid'] = data['uid'] ?? doc.id;
        return data;
      }).toList();
      emitCombined();
    }, onError: (_) {
      fsUsers = [];
      emitCombined();
    });

    final citizensSub = _citizensCollection.snapshots().listen((snapshot) {
      fsCitizens = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['uid'] = data['uid'] ?? doc.id;
        data['role'] = data['role'] ?? 'citizen';
        return data;
      }).toList();
      emitCombined();
    }, onError: (_) {
      fsCitizens = [];
      emitCombined();
    });

    final driversSub = _driversCollection.snapshots().listen((snapshot) {
      fsDrivers = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['uid'] = data['uid'] ?? doc.id;
        data['role'] = data['role'] ?? 'driver';
        return data;
      }).toList();
      emitCombined();
    }, onError: (_) {
      fsDrivers = [];
      emitCombined();
    });

    final adminsSub = _adminsCollection.snapshots().listen((snapshot) {
      fsAdmins = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['uid'] = data['uid'] ?? doc.id;
        data['role'] = data['role'] ?? 'admin';
        return data;
      }).toList();
      emitCombined();
    }, onError: (_) {
      fsAdmins = [];
      emitCombined();
    });

    final rtdbCitizensSub = getCitizensFromRTDB().listen((rows) {
      rtdbCitizens = rows;
      emitCombined();
    }, onError: (_) {});
    final rtdbDriversSub = getDriversFromRTDB().listen((rows) {
      rtdbDrivers = rows;
      emitCombined();
    }, onError: (_) {});
    final rtdbAdminsSub = getAdminsFromRTDB().listen((rows) {
      rtdbAdmins = rows;
      emitCombined();
    }, onError: (_) {});
    final rtdbUsersSub = getAllUsersFromRTDB().listen((rows) {
      rtdbUsers = rows;
      emitCombined();
    }, onError: (_) {});

    controller.onCancel = () async {
      await usersSub.cancel();
      await citizensSub.cancel();
      await driversSub.cancel();
      await adminsSub.cancel();
      await rtdbCitizensSub.cancel();
      await rtdbDriversSub.cancel();
      await rtdbAdminsSub.cancel();
      await rtdbUsersSub.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  /// Get User Role
  Future<String?> getUserRole(String uid) async {
    print('ðŸ” Checking role for UID: $uid');

    try {
      final firestoreRole = await _getUserRoleFromFirestoreOnly(uid);
      if (firestoreRole != null) {
        print('âœ… Found user role in Firestore: $firestoreRole');
        return firestoreRole;
      }
    } on FirebaseException catch (e) {
      // Fall back to RTDB when Firestore permissions are not yet aligned.
      if (e.code == 'permission-denied') {
        print('âš ï¸ Firestore permission denied while checking role. Falling back to RTDB.');
      } else {
        rethrow;
      }
    }

    final rtdbUser = await getUserFromRTDB(uid);
    if (rtdbUser != null) {
      final rtdbRole = (rtdbUser['role'] ?? '').toString().toLowerCase();
      if (rtdbRole == 'citizen' || rtdbRole == 'driver' || rtdbRole == 'admin') {
        print('âœ… Found user role in RTDB: $rtdbRole');
        return rtdbRole;
      }
    }

    print('âŒ User not found in any collection');
    return null;
  }

  /// Get all users by role
  Stream<List<UserModel>> getUsersByRole(String role) {
    Query query;
    if (role == 'citizen') {
      query = _citizensCollection;
    } else if (role == 'driver') {
      query = _driversCollection;
    } else if (role == 'admin') {
      query = _adminsCollection;
    } else {
      query = _usersCollection.where('role', isEqualTo: role);
    }
    
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        if (role == 'citizen') return CitizenModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        if (role == 'driver') return DriverModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// Delete User
  Future<void> deleteUser(String uid) async {
    final deactivationData = {
      'isActive': false,
      'updatedAt': Timestamp.now(),
      'deactivatedAt': Timestamp.now(),
    };
    final deactivationRtdbData = {
      'isActive': false,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'deactivatedAt': DateTime.now().millisecondsSinceEpoch,
    };

    final citizenDoc = await _citizensCollection.doc(uid).get();
    if (citizenDoc.exists) {
      await _citizensCollection.doc(uid).set(deactivationData, SetOptions(merge: true));
      await _rtdb.child('citizens').child(uid).update(deactivationRtdbData);
      return;
    }

    final driverDoc = await _driversCollection.doc(uid).get();
    if (driverDoc.exists) {
      await _driversCollection.doc(uid).set(deactivationData, SetOptions(merge: true));
      await _rtdb.child('drivers').child(uid).update(deactivationRtdbData);
      return;
    }

    final adminDoc = await _adminsCollection.doc(uid).get();
    if (adminDoc.exists) {
      await _adminsCollection.doc(uid).set(deactivationData, SetOptions(merge: true));
      await _rtdb.child('admins').child(uid).update(deactivationRtdbData);
      return;
    }

    await _usersCollection.doc(uid).set(deactivationData, SetOptions(merge: true));
    await _rtdb.child('users').child(uid).update(deactivationRtdbData);
  }

  /// Sync all users (Citizens, Drivers, Admins) to Realtime Database
  Future<void> syncUsersToRTDB() async {
    try {
      print('ðŸ”„ Starting sync of users to RTDB...');
      
      // 1. Sync Citizens
      final citizensSnapshot = await _citizensCollection.get();
      for (var doc in citizensSnapshot.docs) {
        await _rtdb.child('citizens').child(doc.id).set(doc.data());
      }
      print('âœ… Synced ${citizensSnapshot.docs.length} citizens');

      // 2. Sync Drivers
      final driversSnapshot = await _driversCollection.get();
      for (var doc in driversSnapshot.docs) {
        await _rtdb.child('drivers').child(doc.id).set(doc.data());
      }
      print('âœ… Synced ${driversSnapshot.docs.length} drivers');

      // 3. Sync Admins
      final adminsSnapshot = await _adminsCollection.get();
      for (var doc in adminsSnapshot.docs) {
        await _rtdb.child('admins').child(doc.id).set(doc.data());
      }
      print('âœ… Synced ${adminsSnapshot.docs.length} admins');
      
      print('âœ… User sync completed successfully');
    } catch (e) {
      print('âŒ Error syncing users to RTDB: $e');
      rethrow;
    }
  }

  /// Ensure user exists in Firestore (Sync from RTDB if missing)
  /// This repairs "User not found" errors when data exists in RTDB but not Firestore
  Future<bool> ensureUserExistsInFirestore(String uid) async {
    try {
      print('🛠️ Checking if user $uid needs restoration from RTDB...');
      
      // 1. Check specific collections first (most important for security rules)
      bool isAdmin = (await _adminsCollection.doc(uid).get()).exists;
      bool isDriver = (await _driversCollection.doc(uid).get()).exists;
      bool isCitizen = (await _citizensCollection.doc(uid).get()).exists;

      // 2. If already in a role-specific collection, we might be fine, 
      // but let's check if they also exist in 'users' or if they are misplaced.
      if (isAdmin || isDriver || isCitizen) {
        print('✅ User exists in role-specific collection (Admin: $isAdmin, Driver: $isDriver, Citizen: $isCitizen)');
        return true; 
      }

      print('⚠️ User missing in role-specific collections. Attempting recovery...');

      // 3. Try checking RTDB or legacy 'users' collection for the role
      String? foundRole;
      Map<String, dynamic>? userData;

      // Check legacy Firestore 'users'
      final legacyDoc = await _usersCollection.doc(uid).get();
      if (legacyDoc.exists) {
        userData = Map<String, dynamic>.from(legacyDoc.data() as Map);
        foundRole = userData['role'];
        print('📂 Found user in legacy Firestore collection: $foundRole');
      }

      // If not found or needed, check RTDB
      if (foundRole == null) {
        final adminSnap = await _rtdb.child('admins').child(uid).get();
        if (adminSnap.exists) {
          userData = _recursiveConvert(adminSnap.value) as Map<String, dynamic>;
          foundRole = 'admin';
        } else {
          final driverSnap = await _rtdb.child('drivers').child(uid).get();
          if (driverSnap.exists) {
            userData = _recursiveConvert(driverSnap.value) as Map<String, dynamic>;
            foundRole = 'driver';
          } else {
            final citizenSnap = await _rtdb.child('citizens').child(uid).get();
            if (citizenSnap.exists) {
              userData = _recursiveConvert(citizenSnap.value) as Map<String, dynamic>;
              foundRole = 'citizen';
            } else {
              final userSnap = await _rtdb.child('users').child(uid).get();
              if (userSnap.exists) {
                userData = _recursiveConvert(userSnap.value) as Map<String, dynamic>;
                foundRole = userData['role'];
              }
            }
          }
        }
      }

      if (userData != null && foundRole != null) {
        print('🚀 Restoring user to role-specific collection: $foundRole');
        
        // Fix Timestamps
        if (userData['createdAt'] is int) {
          userData['createdAt'] = Timestamp.fromMillisecondsSinceEpoch(userData['createdAt']);
        }
        if (userData['lastLogin'] is int) {
          userData['lastLogin'] = Timestamp.fromMillisecondsSinceEpoch(userData['lastLogin']);
        }

        // Save to correct collection
        if (foundRole == 'admin') {
          await _adminsCollection.doc(uid).set(userData);
        } else if (foundRole == 'driver') {
          await _driversCollection.doc(uid).set(userData);
        } else {
          await _citizensCollection.doc(uid).set(userData);
        }
        
        print('✅ User data successfully migrated/restored to Firestore!');
        return true;
      }
      
      print('❌ User data not found anywhere. User may need to sign up again.');
      return false;
      
    } catch (e) {
      print('❌ Error in ensureUserExistsInFirestore: $e');
      return false;
    }
  }

  /// Create Driver with Firebase Authentication
  /// This method creates a Firebase Auth account and saves driver data to Firestore and RTDB
  Future<UserCredential> createDriverWithAuth({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String vehicleNumber,
    required bool isActive,
  }) async {
    try {
      print('ðŸ”µ Creating driver auth account for: $email');
      
      // Import FirebaseAuth
      final FirebaseAuth auth = FirebaseAuth.instance;
      
      // Create Firebase Auth account
      final UserCredential userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      print('âœ… Auth account created with UID: ${userCredential.user!.uid}');
      
      // Create DriverModel with the Firebase Auth UID
      final newDriver = DriverModel(
        uid: userCredential.user!.uid,
        name: name,
        email: email,
        phone: phone,
        vehicleNumber: vehicleNumber,
        createdAt: DateTime.now(),
        isActive: isActive,
      );
      
      // Save to Firestore and RTDB using existing createUser method
      await createUser(newDriver);
      
      print('âœ… Driver data saved successfully');
      
      return userCredential;
    } catch (e) {
      print('âŒ Error creating driver with auth: $e');
      rethrow;
    }
  }


  // ========== PICKUP REQUEST OPERATIONS ==========

  /// Create Pickup Request
  Future<String> createPickupRequest(PickupRequestModel request) async {
    try {
      print('📦 Creating pickup request for user: ${request.citizenId}');
      
      // Generate a human-readable ID
      final pickupId = await _nextPrefixedId(counterKey: 'pickupRequest', prefix: 'PICK');
      
      final requestMap = request.toMap();
      requestMap['citizenId'] = request.citizenId;
      requestMap['userId'] = request.citizenId;
      requestMap['uid'] = request.citizenId;
      requestMap['pickupId'] = pickupId;
      requestMap['customId'] = pickupId;
      
      String? docId;
      Object? firestoreError;
      
      try {
        // First attempt Firestore
        final docRef = await _pickupRequestsCollection.add(requestMap).timeout(const Duration(seconds: 10));
        docId = docRef.id;
        print('✅ Pickup request created in Firestore: $docId');
      } catch (e) {
        firestoreError = e;
        print('⚠️ Firestore pickup add failed: $e. Proceeding to RTDB.');
        docId = 'req_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      // Prepare RTDB map with ID and numeric timestamps
      final rtdbMap = Map<String, dynamic>.from(requestMap);
      rtdbMap['id'] = docId;
      
      void convertToEpoch(String key) {
        if (rtdbMap[key] is Timestamp) {
          rtdbMap[key] = (rtdbMap[key] as Timestamp).millisecondsSinceEpoch;
        } else if (rtdbMap[key] is DateTime) {
          rtdbMap[key] = (rtdbMap[key] as DateTime).millisecondsSinceEpoch;
        }
      }
      
      convertToEpoch('requestedDate');
      convertToEpoch('scheduledDate');
      convertToEpoch('completedDate');
      convertToEpoch('createdAt');

      bool wroteRtdb = false;
      Object? lastRtdbError;
      
      // Sync to BOTH RTDB nodes for compatibility
      try {
        await _rtdb.child('pickupRequests').child(docId!).set(rtdbMap).timeout(const Duration(seconds: 10));
        wroteRtdb = true;
      } catch (e) {
        lastRtdbError = e;
        print('⚠️ RTDB pickupRequests write failed: $e');
      }
      
      try {
        await _rtdb.child('pickup_requests').child(docId!).set(rtdbMap).timeout(const Duration(seconds: 10));
        wroteRtdb = true;
      } catch (e) {
        if (!wroteRtdb) lastRtdbError = e;
        print('⚠️ RTDB pickup_requests write failed: $e');
      }

      if (!wroteRtdb && firestoreError != null) {
        throw Exception(
          'Pickup request not saved. (Firestore: $firestoreError, RTDB: $lastRtdbError)',
        );
      }

      return docId!;
    } catch (e) {
      print('❌ Error creating pickup request: $e');
      rethrow;
    }
  }

  /// Update Pickup Request
  Future<void> updatePickupRequest(String id, Map<String, dynamic> data) async {
    await _pickupRequestsCollection.doc(id).update(data);
    await _rtdb.child('pickupRequests').child(id).update(data);
  }

  /// Get Pickup Request by ID
  Future<PickupRequestModel?> getPickupRequest(String id) async {
    final doc = await _pickupRequestsCollection.doc(id).get();
    if (doc.exists) {
      return PickupRequestModel.fromMap(
          doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  /// Restore ALL Citizens from RTDB to Firestore (Batch Repair)
  /// Useful when Admin Panel is empty but data exists in RTDB
  Future<int> restoreAllCitizensFromRTDB() async {
    try {
      print('ðŸ”§ Starting batch restore of citizens from RTDB...');
      int restoredCount = 0;
      
      // Get all citizens from RTDB
      final snapshot = await _rtdb.child('citizens').get();
      
      if (snapshot.exists && snapshot.value != null) {
        final Map<dynamic, dynamic> citizens = snapshot.value as Map<dynamic, dynamic>;
        print('ðŸ“¥ Found ${citizens.length} citizens in RTDB');
        
        for (var entry in (snapshot.value as Map).entries) {
           String uid = entry.key.toString();
           Map<String, dynamic> data = _recursiveConvert(entry.value) as Map<String, dynamic>;
           
           // Check if exists in Firestore
           final docSnapshot = await _citizensCollection.doc(uid).get();
           if (!docSnapshot.exists) {
             // Fix Timestamps
             if (data['createdAt'] is int) {
                data['createdAt'] = Timestamp.fromMillisecondsSinceEpoch(data['createdAt']);
             }
             if (data['lastLogin'] is int) {
                data['lastLogin'] = Timestamp.fromMillisecondsSinceEpoch(data['lastLogin']);
             }
             
             // Write to Firestore
             await _citizensCollection.doc(uid).set(data);
             restoredCount++;
             print('   âœ… Restored citizen: $uid');
           }
        }
      }
      
      print('âœ… Batch restore completed. Restored: $restoredCount citizens');
      return restoredCount;
    } catch (e) {
      print('âŒ Error in batch restore: $e');
      rethrow;
    }
  }

  /// Restoration method for Drivers as well
  Future<int> restoreAllDriversFromRTDB() async {
    try {
      int restoredCount = 0;
      final snapshot = await _rtdb.child('drivers').get();
      
      if (snapshot.exists && snapshot.value != null) {
        for (var entry in (snapshot.value as Map).entries) {
           String uid = entry.key.toString();
           Map<String, dynamic> data = _recursiveConvert(entry.value) as Map<String, dynamic>;
           
           if (!(await _driversCollection.doc(uid).get()).exists) {
             if (data['createdAt'] is int) data['createdAt'] = Timestamp.fromMillisecondsSinceEpoch(data['createdAt']);
             await _driversCollection.doc(uid).set(data);
             restoredCount++;
           }
        }
      }
      return restoredCount;
    } catch (e) {
      print('âŒ Error restoring drivers: $e');
      rethrow;
    }
  }

  /// Get Pickup Request by ID
  Stream<List<PickupRequestModel>> getPickupRequestsStream({
    String? citizenId,
    String? driverId,
    String? status,
  }) {
    final controller = StreamController<List<PickupRequestModel>>();
    List<PickupRequestModel> firestoreItems = [];
    List<PickupRequestModel> firestoreLegacyItems = [];
    List<PickupRequestModel> rtdbItems = [];
    List<PickupRequestModel> rtdbLegacyItems = [];

    bool matches(PickupRequestModel item) {
      if (citizenId != null && item.citizenId != citizenId) return false;
      if (driverId != null && item.driverId != driverId) return false;
      if (status != null && item.status != status) return false;
      return true;
    }

    void emitCombined() {
      if (controller.isClosed) return;
      final merged = <String, PickupRequestModel>{};
      for (final item in [
        ...firestoreItems,
        ...firestoreLegacyItems,
        ...rtdbItems,
        ...rtdbLegacyItems,
      ]) {
        final key = item.id ?? '${item.citizenId}_${item.requestedDate.millisecondsSinceEpoch}';
        if (matches(item)) merged[key] = item;
      }
      final rows = merged.values.toList()
        ..sort((a, b) => b.requestedDate.compareTo(a.requestedDate));
      controller.add(rows);
    }

    Query query = _pickupRequestsCollection;
    if (citizenId != null) query = query.where('citizenId', isEqualTo: citizenId);
    if (driverId != null) query = query.where('driverId', isEqualTo: driverId);
    if (status != null) query = query.where('status', isEqualTo: status);

    final fsSub = query.snapshots().listen((snapshot) {
      final parsed = <PickupRequestModel>[];
      for (final doc in snapshot.docs) {
        try {
          parsed.add(PickupRequestModel.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ));
        } catch (e) {
          print('Error parsing Firestore pickup: $e');
        }
      }
      firestoreItems = parsed;
      emitCombined();
    }, onError: (err) {
      print('⚠️ Firestore pickup error: $err');
      firestoreItems = [];
      emitCombined();
    });

    Query legacyQuery = _db.collection('pickup_requests');
    if (citizenId != null) legacyQuery = legacyQuery.where('citizenId', isEqualTo: citizenId);
    if (driverId != null) legacyQuery = legacyQuery.where('driverId', isEqualTo: driverId);
    if (status != null) legacyQuery = legacyQuery.where('status', isEqualTo: status);

    final fsLegacySub = legacyQuery.snapshots().listen((snapshot) {
      final parsed = <PickupRequestModel>[];
      for (final doc in snapshot.docs) {
        try {
          parsed.add(PickupRequestModel.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ));
        } catch (_) {}
      }
      firestoreLegacyItems = parsed;
      emitCombined();
    }, onError: (_) {
      firestoreLegacyItems = [];
      emitCombined();
    });

    final rtdbSub = _rtdb.child('pickupRequests').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is! Map) {
        rtdbItems = [];
        emitCombined();
        return;
      }
      final parsed = <PickupRequestModel>[];
      if (value is Map) {
        final raw = _recursiveConvert(value) as Map<String, dynamic>;
        raw.forEach((key, v) {
          if (v is! Map) return;
          try {
            parsed.add(
              PickupRequestModel.fromMap(
                Map<String, dynamic>.from(v),
                key,
              ),
            );
          } catch (_) {}
        });
      }
      rtdbItems = parsed;
      emitCombined();
    }, onError: (_) {
      rtdbItems = [];
      emitCombined();
    });

    final rtdbLegacySub = _rtdb.child('pickup_requests').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is! Map) {
        rtdbLegacyItems = [];
        emitCombined();
        return;
      }
      final parsed = <PickupRequestModel>[];
      if (value is Map) {
        final raw = _recursiveConvert(value) as Map<String, dynamic>;
        raw.forEach((key, v) {
          if (v is! Map) return;
          try {
            parsed.add(
              PickupRequestModel.fromMap(
                Map<String, dynamic>.from(v),
                key,
              ),
            );
          } catch (e) {
            print('Error parsing legacy RTDB pickup: $e');
          }
        });
      }
      rtdbLegacyItems = parsed;
      emitCombined();
    }, onError: (err) {
      print('⚠️ RTDB legacy pickup error: $err');
      // Only emit error if no other data is available or for critical failures
      if (firestoreItems.isEmpty && rtdbItems.isEmpty) {
         controller.addError(err);
      }
    });

    controller.onCancel = () async {
      await fsSub.cancel();
      await fsLegacySub.cancel();
      await rtdbSub.cancel();
      await rtdbLegacySub.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  /// Assign Driver to Pickup Request
  Future<void> assignDriverToPickup(String pickupId, String driverId) async {
    print('🚚 Assigning pickup $pickupId to driver $driverId');
    
    // 1. Fetch current data to get citizenId
    String? citizenId;
    String? wasteType;
    
    try {
      final doc = await _pickupRequestsCollection.doc(pickupId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        citizenId = data['citizenId']?.toString();
        wasteType = data['wasteType']?.toString();
      }
    } catch (_) {}

    if (citizenId == null) {
      try {
        final snap = await _rtdb.child('pickupRequests').child(pickupId).get();
        if (snap.exists && snap.value != null) {
          final raw = _recursiveConvert(snap.value);
          if (raw is Map) {
            final data = Map<String, dynamic>.from(raw);
            citizenId = data['citizenId']?.toString();
            wasteType = data['wasteType']?.toString();
          }
        }
      } catch (e) {
        print('⚠️ RTDB pickup fetch error: $e');
      }
    }

    final updateData = {
      'driverId': driverId,
      'status': 'assigned',
      'assignedAt': Timestamp.now(),
    };

    // 2. Update Firestore
    try {
      await _pickupRequestsCollection.doc(pickupId).set(updateData, SetOptions(merge: true));
    } catch (e) {
      print('⚠️ Firestore pickup assign update failed: $e');
    }

    // 3. Update RTDB
    final rtdbUpdate = {
      'driverId': driverId,
      'status': 'assigned',
      'assignedAt': DateTime.now().millisecondsSinceEpoch,
    };
    Object? rtdbError;
    bool wroteRtdb = false;
    try {
      await _rtdb.child('pickupRequests').child(pickupId).update(rtdbUpdate);
      wroteRtdb = true;
    } catch (e) {
      rtdbError = e;
    }
    try {
      await _rtdb.child('pickup_requests').child(pickupId).update(rtdbUpdate);
      wroteRtdb = true;
    } catch (e) {
      rtdbError ??= e;
    }
    if (!wroteRtdb) {
      throw Exception('Assign failed (RTDB update denied): $rtdbError');
    }

    // 4. Create Task for Driver
    try {
      await createTask(
        TaskModel(
          requestId: pickupId,
          driverId: driverId,
          assignedDate: DateTime.now(),
          status: 'assigned',
          notes: 'Pickup request: ${wasteType ?? "General"}',
        ),
      );
    } catch (_) {}

    // 5. Notify Driver
    try {
      await createNotification(
        NotificationModel(
          userId: driverId,
          title: 'New Pickup Assigned',
          message: 'You have been assigned a new pickup request: ${wasteType ?? "General"}',
          type: 'pickup_assigned',
          relatedEntityId: pickupId,
          relatedEntityType: 'pickup',
          createdAt: DateTime.now(),
        ),
      );
    } catch (_) {}

    // 6. Notify Citizen
    if (citizenId != null && citizenId.isNotEmpty) {
      try {
        await createNotification(
          NotificationModel(
            userId: citizenId,
            title: 'Pickup Assigned',
            message: 'A driver has been assigned to your pickup request.',
            type: 'pickup_assigned_citizen',
            relatedEntityId: pickupId,
            relatedEntityType: 'pickup',
            createdAt: DateTime.now(),
          ),
        );
      } catch (_) {}
    }
  }

  /// Update Pickup Status
  Future<void> updatePickupStatus(String id, String status) async {
    String previousStatus = '';
    String? pickupDriverId;

    try {
      final existing = await _pickupRequestsCollection.doc(id).get();
      if (existing.exists) {
        final map = Map<String, dynamic>.from(existing.data() as Map<String, dynamic>);
        previousStatus = (map['status'] ?? '').toString();
        pickupDriverId = map['driverId']?.toString();
      }
    } catch (_) {}

    if (previousStatus.isEmpty || (pickupDriverId ?? '').isEmpty) {
      try {
        final existing = await _rtdb.child('pickupRequests').child(id).get();
        if (existing.exists && existing.value is Map) {
          final map = Map<String, dynamic>.from(existing.value as Map);
          previousStatus = previousStatus.isEmpty ? (map['status'] ?? '').toString() : previousStatus;
          pickupDriverId = ((pickupDriverId ?? '').isEmpty)
              ? map['driverId']?.toString()
              : pickupDriverId;
        }
      } catch (_) {}
    }

    final updateData = <String, dynamic>{'status': status};
    
    if (status == 'completed') {
      updateData['completedDate'] = Timestamp.now();
    }

    try {
      await _pickupRequestsCollection.doc(id).update(updateData);
    } catch (e) {
      print('⚠️ Firestore pickup status update failed: $e');
    }
    
    // Sync to RTDB
    if (updateData['completedDate'] is Timestamp) {
       updateData['completedDate'] = (updateData['completedDate'] as Timestamp).millisecondsSinceEpoch;
    }
    try {
      await _rtdb.child('pickupRequests').child(id).update(updateData);
    } catch (e) {
      print('⚠️ RTDB pickup status update failed: $e');
    }

    if (status == 'completed') {
      await _awardPointsForCompletedPickup(id);
      if (previousStatus != 'completed') {
        await _notifyPickupCompleted(id, fallbackDriverId: pickupDriverId);
      }
    }
  }

  Future<void> _notifyPickupCompleted(String pickupId, {String? fallbackDriverId}) async {
    String driverId = fallbackDriverId?.toString() ?? '';
    String wasteType = 'Pickup';
    String locationText = 'the assigned location';

    try {
      final fsDoc = await _pickupRequestsCollection.doc(pickupId).get();
      if (fsDoc.exists) {
        final data = Map<String, dynamic>.from(fsDoc.data() as Map<String, dynamic>);
        driverId = (data['driverId'] ?? driverId).toString();
        wasteType = (data['wasteType'] ?? wasteType).toString();
        final location = data['location'];
        if (location is Map && location['address'] != null) {
          locationText = location['address'].toString();
        } else if (data['locationAddress'] != null) {
          locationText = data['locationAddress'].toString();
        }
      }
    } catch (_) {}

    if (driverId.isEmpty || locationText == 'the assigned location') {
      try {
        final rtdbDoc = await _rtdb.child('pickupRequests').child(pickupId).get();
        if (rtdbDoc.exists && rtdbDoc.value is Map) {
          final data = Map<String, dynamic>.from(rtdbDoc.value as Map);
          driverId = driverId.isEmpty ? (data['driverId'] ?? '').toString() : driverId;
          wasteType = (data['wasteType'] ?? wasteType).toString();
          final location = data['location'];
          if (location is Map && location['address'] != null) {
            locationText = location['address'].toString();
          } else if (data['locationAddress'] != null) {
            locationText = data['locationAddress'].toString();
          }
        }
      } catch (_) {}
    }

    final adminUids = await _getAdminUidsForNotification();

    final recipients = <String>{...adminUids};
    if (driverId.isNotEmpty) recipients.add(driverId);
    if (recipients.isEmpty) return;

    for (final uid in recipients) {
      try {
        final isDriver = uid == driverId;
        await createNotification(
          NotificationModel(
            userId: uid,
            title: isDriver ? 'Pickup Completed' : 'Pickup Finished',
            message: isDriver
                ? 'You marked $wasteType pickup as completed at $locationText.'
                : 'A driver completed $wasteType pickup at $locationText.',
            type: 'pickup_completed',
            relatedEntityId: pickupId,
            relatedEntityType: 'pickup_request',
            createdAt: DateTime.now(),
          ),
        );
      } catch (_) {}
    }
  }

  Future<Set<String>> _getAdminUidsForNotification() async {
    final adminUids = <String>{};

    try {
      final snap = await _adminsCollection.get();
      for (final doc in snap.docs) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        final uid = (data['uid'] ?? doc.id).toString();
        if (uid.isNotEmpty) adminUids.add(uid);
      }
    } catch (_) {}

    if (adminUids.isNotEmpty) return adminUids;

    try {
      final snap = await _rtdb.child('admins').get();
      if (snap.exists && snap.value is Map) {
        final map = Map<String, dynamic>.from(snap.value as Map);
        map.forEach((key, value) {
          if (value is Map) {
            final data = Map<String, dynamic>.from(value);
            final uid = (data['uid'] ?? key).toString();
            if (uid.isNotEmpty) adminUids.add(uid);
          }
        });
      }
    } catch (_) {}

    return adminUids;
  }

  Future<void> _awardPointsForCompletedPickup(String pickupId) async {
    String citizenUid = '';
    bool alreadyAwarded = false;

    try {
      final fsDoc = await _pickupRequestsCollection.doc(pickupId).get();
      if (fsDoc.exists) {
        final data = Map<String, dynamic>.from(fsDoc.data() as Map<String, dynamic>);
        citizenUid = (data['citizenId'] ?? data['userId'] ?? data['uid'] ?? '').toString();
        alreadyAwarded = data['pointsAwarded'] == true;
      }
    } catch (_) {}

    if (citizenUid.isEmpty || alreadyAwarded) {
      try {
        final rtdbSnap = await _rtdb.child('pickupRequests').child(pickupId).get();
        if (rtdbSnap.exists && rtdbSnap.value is Map) {
          final data = Map<String, dynamic>.from(rtdbSnap.value as Map);
          citizenUid = (data['citizenId'] ?? data['userId'] ?? data['uid'] ?? '').toString();
          alreadyAwarded = alreadyAwarded || data['pointsAwarded'] == true;
        }
      } catch (_) {}
    }

    if (citizenUid.isEmpty || alreadyAwarded) return;

    final awardedMeta = <String, dynamic>{
      'pointsAwarded': true,
      'pointsAwardedAt': DateTime.now().millisecondsSinceEpoch,
      'awardedPoints': _pointsPerCompletedPickup,
    };

    try {
      final target = await _findUserCollectionAndDocId(citizenUid);
      if (target != null) {
        await _db.runTransaction((tx) async {
          final snap = await tx.get(target.$1.doc(target.$2));
          final current = snap.exists
              ? (((snap.data() as Map<String, dynamic>)['rewardPoints'] ?? 0) as num).toInt()
              : 0;
          tx.set(
            target.$1.doc(target.$2),
            {'rewardPoints': current + _pointsPerCompletedPickup},
            SetOptions(merge: true),
          );
        });
      }
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    } catch (_) {}

    try {
      final rtdbUser = await getUserFromRTDB(citizenUid);
      final current = ((rtdbUser?['rewardPoints'] ?? 0) as num).toInt();
      await _updateUserInRtdbFallback(
        citizenUid,
        {'rewardPoints': current + _pointsPerCompletedPickup},
      );
    } catch (_) {}

    try {
      await _pickupRequestsCollection.doc(pickupId).set({
        'pointsAwarded': true,
        'pointsAwardedAt': Timestamp.now(),
        'awardedPoints': _pointsPerCompletedPickup,
      }, SetOptions(merge: true));
    } catch (_) {}

    try {
      await _rtdb.child('pickupRequests').child(pickupId).update(awardedMeta);
    } catch (_) {}
  }

  /// Delete Pickup Request
  Future<void> deletePickupRequest(String id) async {
    await _pickupRequestsCollection.doc(id).delete();
    await _rtdb.child('pickupRequests').child(id).remove();
  }

  // ========== SCHEDULE OPERATIONS ==========

  /// Create Schedule
  Future<String> createSchedule(ScheduleModel schedule) async {
    try {
      print('ðŸ“… Creating schedule');
      final firestoreMap = Map<String, dynamic>.from(schedule.toMap());
      final scheduleMap = Map<String, dynamic>.from(schedule.toMap());
      final scheduleId =
          await _nextPrefixedId(counterKey: 'schedule', prefix: 'sche');
      firestoreMap['scheduleId'] = scheduleId;
      firestoreMap['customId'] = scheduleId;
      scheduleMap['scheduleId'] = scheduleId;
      scheduleMap['customId'] = scheduleId;
      if (scheduleMap['createdAt'] is Timestamp) {
        scheduleMap['createdAt'] =
            (scheduleMap['createdAt'] as Timestamp).millisecondsSinceEpoch;
      }
      if (scheduleMap['lastUpdated'] is Timestamp) {
        scheduleMap['lastUpdated'] =
            (scheduleMap['lastUpdated'] as Timestamp).millisecondsSinceEpoch;
      }
      String id = scheduleId;
      try {
        final docRef = await _schedulesCollection.add(firestoreMap);
        id = docRef.id;
      } catch (_) {}
      await _rtdb.child('schedules').child(id).set(scheduleMap);
      print('âœ… Schedule created: $id');
      return id;
    } catch (e) {
      print('âŒ Error creating schedule: $e');
      rethrow;
    }
  }

  /// Update Schedule
  Future<void> updateSchedule(String id, Map<String, dynamic> data) async {
    data['lastUpdated'] = Timestamp.now();
    await _schedulesCollection.doc(id).update(data);
    
    // RTDB Sync
    Map<String, dynamic> rtdbData = Map.from(data);
    if(rtdbData['lastUpdated'] is Timestamp) {
        rtdbData['lastUpdated'] = (rtdbData['lastUpdated'] as Timestamp).millisecondsSinceEpoch;
    }
    await _rtdb.child('schedules').child(id).update(rtdbData);
  }

  /// Get Schedule by ID
  Future<ScheduleModel?> getSchedule(String id) async {
    final doc = await _schedulesCollection.doc(id).get();
    if (doc.exists) {
      return ScheduleModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  /// Get Schedules Stream (Common + Personal)
  /// Merges two streams:
  /// 1. Common schedules (isCommon == true)
  /// 2. Personal schedules (citizenId == userId)
  Stream<List<ScheduleModel>> getSchedulesStream({
    required String userId, // Now required for filtering
    String? area,
    bool? isActive,
  }) {
    final controller = StreamController<List<ScheduleModel>>();
    List<ScheduleModel> commonSchedules = [];
    List<ScheduleModel> personalSchedules = [];
    List<ScheduleModel> rtdbSchedules = [];
    final allowedCitizenIds = <String>{userId};

    void emitCombined() {
      if (controller.isClosed) return;

      final combined = [...commonSchedules, ...personalSchedules, ...rtdbSchedules];
      final dedupedById = <String, ScheduleModel>{};
      for (final item in combined) {
        final key = item.id ??
            '${item.area}_${item.collectionTime}_${item.daysOfWeek.join(',')}';
        dedupedById[key] = item;
      }

      final filtered = dedupedById.values.where((s) {
        if (isActive != null && s.isActive != isActive) return false;
        if (area != null && s.area != area && s.isCommon) return false;
        if (!s.isCommon) {
          final cid = (s.citizenId ?? '').trim();
          if (cid.isEmpty || !allowedCitizenIds.contains(cid)) return false;
        }
        return true;
      }).toList();

      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(filtered);
    }

    () async {
      try {
        final fireUser = await getUser(userId);
        if (fireUser != null) {
          allowedCitizenIds.add(fireUser.uid);
        }
        final rtdbUser = await getUserFromRTDB(userId);
        if (rtdbUser != null) {
          for (final k in ['uid', 'userId', 'citizenId', 'customId']) {
            final v = (rtdbUser[k] ?? '').toString().trim();
            if (v.isNotEmpty) allowedCitizenIds.add(v);
          }
        }
        emitCombined();
      } catch (_) {
        // Ignore id enrichment failures and continue with UID-only filtering.
      }
    }();

    // 1. Common Schedules Stream
    final Query commonQuery = _schedulesCollection
        .where('isCommon', isEqualTo: true);
        // .orderBy('createdAt', descending: true); // Requires index with isCommon

    final StreamSubscription commonSub = commonQuery.snapshots().listen(
      (snapshot) {
        commonSchedules = snapshot.docs.map((doc) {
          return ScheduleModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
        emitCombined();
      },
      onError: (e) => print('âŒ Error in common schedules stream: $e'),
    );

    // 2. Personal Schedules Stream (query all personal, then filter by allowed ids)
    final Query personalQuery = _schedulesCollection
        .where('isCommon', isEqualTo: false);

    final StreamSubscription personalSub = personalQuery.snapshots().listen(
      (snapshot) {
        personalSchedules = snapshot.docs.map((doc) {
          return ScheduleModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
        emitCombined();
      },
      onError: (e) => print('âŒ Error in personal schedules stream: $e'),
    );

    // 3. RTDB fallback schedules
    final StreamSubscription rtdbSub = _rtdb.child('schedules').onValue.listen(
      (event) {
        final value = event.snapshot.value;
        if (value is! Map) {
          rtdbSchedules = [];
          emitCombined();
          return;
        }
        final parsed = <ScheduleModel>[];
        if (value is Map) {
          final raw = _recursiveConvert(value) as Map<String, dynamic>;
          raw.forEach((key, v) {
            if (v is! Map) return;
            try {
              parsed.add(
                ScheduleModel.fromMap(Map<String, dynamic>.from(v), key),
              );
            } catch (_) {}
          });
        }
        rtdbSchedules = parsed;
        emitCombined();
      },
      onError: (_) {
        rtdbSchedules = [];
        emitCombined();
      },
    );

    controller.onCancel = () async {
      await commonSub.cancel();
      await personalSub.cancel();
      await rtdbSub.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  /// Get ALL Schedules Stream (Admin Use)
  Stream<List<ScheduleModel>> getAllSchedulesStream() {
    final controller = StreamController<List<ScheduleModel>>();
    List<ScheduleModel> fsItems = [];
    List<ScheduleModel> rtdbItems = [];

    void emitCombined() {
      if (controller.isClosed) return;
      final merged = <String, ScheduleModel>{};
      for (final s in [...fsItems, ...rtdbItems]) {
        final key = s.id ?? '${s.area}_${s.collectionTime}_${s.daysOfWeek.join(',')}';
        merged[key] = s;
      }
      final rows = merged.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(rows);
    }

    final fsSub = _schedulesCollection.snapshots().listen((snapshot) {
      fsItems = snapshot.docs
          .map((doc) => ScheduleModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      emitCombined();
    }, onError: (_) {
      fsItems = [];
      emitCombined();
    });

    final rtdbSub = _rtdb.child('schedules').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is! Map) {
        rtdbItems = [];
        emitCombined();
        return;
      }
      final parsed = <ScheduleModel>[];
      final raw = Map<dynamic, dynamic>.from(value);
      raw.forEach((key, v) {
        if (v is! Map) return;
        try {
          parsed.add(
            ScheduleModel.fromMap(Map<String, dynamic>.from(v), key.toString()),
          );
        } catch (_) {}
      });
      rtdbItems = parsed;
      emitCombined();
    }, onError: (_) {
      rtdbItems = [];
      emitCombined();
    });

    controller.onCancel = () async {
      await fsSub.cancel();
      await rtdbSub.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  /// Delete Schedule
  Future<void> deleteSchedule(String id) async {
    // 1) Try direct delete by document/key id first.
    try {
      await _schedulesCollection.doc(id).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    } catch (_) {}

    try {
      await _rtdb.child('schedules').child(id).remove();
    } catch (_) {}

    // 2) Also delete by custom schedule id field (scheduleId/customId), since
    // some records are keyed by Firestore doc id while UI references scheduleId.
    try {
      final byScheduleId =
          await _schedulesCollection.where('scheduleId', isEqualTo: id).get();
      for (final doc in byScheduleId.docs) {
        await doc.reference.delete();
      }
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    } catch (_) {}

    try {
      final byCustomId =
          await _schedulesCollection.where('customId', isEqualTo: id).get();
      for (final doc in byCustomId.docs) {
        await doc.reference.delete();
      }
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    } catch (_) {}

    try {
      final snap = await _rtdb.child('schedules').get();
      if (snap.exists && snap.value is Map) {
        final raw = Map<dynamic, dynamic>.from(snap.value as Map);
        for (final entry in raw.entries) {
          if (entry.value is! Map) continue;
          final row = Map<dynamic, dynamic>.from(entry.value as Map);
          final scheduleId = (row['scheduleId'] ?? '').toString();
          final customId = (row['customId'] ?? '').toString();
          if (entry.key.toString() == id || scheduleId == id || customId == id) {
            await _rtdb.child('schedules').child(entry.key.toString()).remove();
          }
        }
      }
    } catch (_) {}
  }

  // ========== ROUTE OPERATIONS ==========

  /// Create Route
  Future<String> createRoute(RouteModel route) async {
    final docRef = await _routesCollection.add(route.toMap());
    await _rtdb.child('routes').child(docRef.id).set(route.toMap());
    return docRef.id;
  }

  /// Update Route
  Future<void> updateRoute(String id, Map<String, dynamic> data) async {
    await _routesCollection.doc(id).update(data);
    await _rtdb.child('routes').child(id).update(data);
  }

  /// Get Route by ID
  Future<RouteModel?> getRoute(String id) async {
    final doc = await _routesCollection.doc(id).get();
    if (doc.exists) {
      return RouteModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  /// Get Routes Stream
  Stream<List<RouteModel>> getRoutesStream({String? driverId, String? status}) {
    Query query = _routesCollection;

    if (driverId != null) {
      query = query.where('driverId', isEqualTo: driverId);
    }
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return RouteModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// Delete Route
  Future<void> deleteRoute(String id) async {
    await _routesCollection.doc(id).delete();
    await _rtdb.child('routes').child(id).remove();
  }

  // ========== WASTE TYPE OPERATIONS ==========

  /// Create Waste Type
  Future<String> createWasteType(WasteTypeModel wasteType) async {
    final wasteTypeMap = Map<String, dynamic>.from(wasteType.toMap());
    final wasteTypeId =
        await _nextPrefixedId(counterKey: 'waste_type', prefix: 'waty');
    wasteTypeMap['wasteTypeId'] = wasteTypeId;
    wasteTypeMap['customId'] = wasteTypeId;
    final docRef = await _wasteTypesCollection.add(wasteTypeMap);
    await _rtdb.child('wasteTypes').child(docRef.id).set(wasteTypeMap);
    return docRef.id;
  }

  /// Update Waste Type
  Future<void> updateWasteType(String id, Map<String, dynamic> data) async {
    await _wasteTypesCollection.doc(id).update(data);
    await _rtdb.child('wasteTypes').child(id).update(data);
  }

  /// Get All Waste Types
  Stream<List<WasteTypeModel>> getWasteTypesStream() {
    return _wasteTypesCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return WasteTypeModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// Delete Waste Type
  Future<void> deleteWasteType(String id) async {
    await _wasteTypesCollection.doc(id).delete();
    await _rtdb.child('wasteTypes').child(id).remove();
  }

  // ========== VEHICLE OPERATIONS ==========

  Future<String> createVehicle(VehicleModel vehicle) async {
    final docRef = await _vehiclesCollection.add(vehicle.toMap());
    return docRef.id;
  }

  Future<void> updateVehicle(String id, Map<String, dynamic> data) async {
    await _vehiclesCollection.doc(id).update(data);
  }

  Future<VehicleModel?> getVehicle(String id) async {
    final doc = await _vehiclesCollection.doc(id).get();
    if (doc.exists) {
      return VehicleModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  Stream<List<VehicleModel>> getVehiclesStream() {
    return _vehiclesCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return VehicleModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Future<void> deleteVehicle(String id) async {
    await _vehiclesCollection.doc(id).delete();
  }

  Future<void> assignVehicleToDriver(String vehicleId, String driverId) async {
    final batch = _db.batch();
    
    // Update Vehicle
    final vehicleRef = _vehiclesCollection.doc(vehicleId);
    batch.update(vehicleRef, {'assignedDriverId': driverId});

    // Update Driver (User)
    final driverRef = _usersCollection.doc(driverId);
    batch.update(driverRef, {'vehicleId': vehicleId});

    await batch.commit();
  }

  // ========== TASK OPERATIONS ==========

  Future<String> createTask(TaskModel task) async {
    final taskMap = task.toMap();
    String docId = _rtdb.child('tasks').push().key ?? 'task_${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      final docRef = await _tasksCollection.add(taskMap);
      docId = docRef.id;
    } catch (e) {
      print('⚠️ Task Firestore sync failed: $e');
    }

    await _rtdb.child('tasks').child(docId).set(taskMap);
    return docId;
  }

  Future<void> updateTask(String id, Map<String, dynamic> data) async {
    print('🔄 Updating task $id with $data');
    
    // 1. Update Firestore
    try {
      await _tasksCollection.doc(id).update(data);
    } catch (e) {
      print('⚠️ Firestore task update failed: $e');
    }

    // 2. Update RTDB
    try {
      final rtdbData = Map<String, dynamic>.from(data);
      if (rtdbData['completionDate'] is DateTime) {
        rtdbData['completionDate'] = (rtdbData['completionDate'] as DateTime).millisecondsSinceEpoch;
      } else if (rtdbData['assignedDate'] is DateTime) {
        rtdbData['assignedDate'] = (rtdbData['assignedDate'] as DateTime).millisecondsSinceEpoch;
      }
      await _rtdb.child('tasks').child(id).update(rtdbData);
    } catch (e) {
      print('⚠️ RTDB task update failed: $e');
    }

    // 3. Chain to Pickup Status if completed
    if (data['status']?.toString() == 'completed') {
      String requestId = data['requestId']?.toString() ?? '';
      if (requestId.isEmpty) {
        final task = await getTask(id);
        requestId = task?.requestId ?? '';
      }
      
      if (requestId.isNotEmpty) {
        print('✅ Completing associated pickup $requestId');
        await updatePickupStatus(requestId, 'completed');
      }
    }
  }

  Future<TaskModel?> getTask(String id) async {
    try {
      final doc = await _tasksCollection.doc(id).get();
      if (doc.exists) {
        return TaskModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
    } catch (_) {}

    try {
      final snap = await _rtdb.child('tasks').child(id).get();
      if (snap.exists && snap.value != null) {
        final data = _recursiveConvert(snap.value);
        if (data is Map) {
          return TaskModel.fromMap(Map<String, dynamic>.from(data), id);
        }
      }
    } catch (_) {}
    return null;
  }

  Stream<List<TaskModel>> getTasksStream({String? driverId, String? status}) {
    final controller = StreamController<List<TaskModel>>();
    List<TaskModel> firestoreItems = [];
    List<TaskModel> rtdbItems = [];

    void emitCombined() {
      if (controller.isClosed) return;
      final merged = <String, TaskModel>{};
      
      for (final item in [...firestoreItems, ...rtdbItems]) {
        final key = item.id ?? '${item.driverId}_${item.requestId}';
        // Filtering logic inside stream if needed, usually better to query but for multi-db we filter here
        bool matches = true;
        if (driverId != null && item.driverId != driverId) matches = false;
        if (status != null && item.status.toLowerCase().trim() != status.toLowerCase().trim()) matches = false;
        
        if (matches) {
          // If already exists, prefer Firestore item if it's more complete, or just keep first
          merged[key] = item;
        }
      }
      
      final output = merged.values.toList()
        ..sort((a, b) => b.assignedDate.compareTo(a.assignedDate));
      controller.add(output);
    }

    Query query = _tasksCollection;
    if (driverId != null) query = query.where('driverId', isEqualTo: driverId);
    if (status != null) query = query.where('status', isEqualTo: status);

    final fsSub = query.snapshots().listen((snapshot) {
      firestoreItems = snapshot.docs.map((doc) {
        return TaskModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      emitCombined();
    }, onError: (err) {
      print('⚠️ Firestore tasks error: $err');
      firestoreItems = [];
      emitCombined();
    });

    final rtdbSub = _rtdb.child('tasks').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is! Map) {
        rtdbItems = [];
      } else {
        final parsed = <TaskModel>[];
        final raw = _recursiveConvert(value) as Map<String, dynamic>;
        raw.forEach((key, v) {
          if (v is! Map) return;
          try {
            parsed.add(TaskModel.fromMap(Map<String, dynamic>.from(v), key));
          } catch (e) {
            print('Error parsing RTDB task: $e');
          }
        });
        rtdbItems = parsed;
      }
      emitCombined();
    }, onError: (err) {
      print('⚠️ RTDB tasks error: $err');
      rtdbItems = [];
      emitCombined();
    });

    controller.onCancel = () {
      fsSub.cancel();
      rtdbSub.cancel();
    };

    return controller.stream;
  }

  // ========== NOTIFICATION OPERATIONS ==========

  /// Create Notification
  Future<String> createNotification(NotificationModel notification) async {
    final notificationMap = Map<String, dynamic>.from(notification.toMap());
    
    // Use uid strictly, avoid relying on 'userId' field if it was removed
    String targetUid = notification.userId;
    if (notificationMap.containsKey('userId')) {
       targetUid = notificationMap['userId'].toString();
    } else if (notificationMap.containsKey('uid')) {
       targetUid = notificationMap['uid'].toString();
    }
    
    // Ensure both fields are set for backward compatibility
    notificationMap['userId'] = targetUid;
    notificationMap['uid'] = targetUid; // Critical for new queries

    if (notificationMap['createdAt'] is Timestamp) {
      notificationMap['createdAt'] =
          (notificationMap['createdAt'] as Timestamp).millisecondsSinceEpoch;
    }
    if (notificationMap['readAt'] is Timestamp) {
      notificationMap['readAt'] =
          (notificationMap['readAt'] as Timestamp).millisecondsSinceEpoch;
    }
    final notificationId =
        await _nextPrefixedId(counterKey: 'notification', prefix: 'notifi');
    notificationMap['notificationId'] = notificationId;
    notificationMap['customId'] = notificationId;
    final firestoreMap = Map<String, dynamic>.from(notification.toMap());
    firestoreMap['notificationId'] = notificationId;
    firestoreMap['customId'] = notificationId;
    
    firestoreMap['userId'] = targetUid;
    firestoreMap['uid'] = targetUid;
    
    String docId = _rtdb.child('notifications').push().key ??
        'notif_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final docRef = await _notificationsCollection.add(firestoreMap);
      docId = docRef.id;
    } catch (e) {
      print('⚠️ Notification Firestore sync failed: $e');
    }

    await _rtdb.child('notifications').child(docId).set(notificationMap);
    return docId;
  }

  /// Mark Notification as Read
  Future<void> markNotificationAsRead(String id) async {
    await _notificationsCollection.doc(id).update({
      'isRead': true,
      'readAt': Timestamp.now(),
    });
    
    await _rtdb.child('notifications').child(id).update({
      'isRead': true,
      'readAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Get Notifications for User
  Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    final controller = StreamController<List<NotificationModel>>();
    List<NotificationModel> fsByUserId = [];
    List<NotificationModel> fsByUid = [];
    List<NotificationModel> rtdbItems = [];

    void emitCombined() {
      if (controller.isClosed) return;
      final map = <String, NotificationModel>{};
      for (final n in [...fsByUserId, ...fsByUid, ...rtdbItems]) {
        final key = n.id ?? '${n.userId}_${n.title}_${n.createdAt.millisecondsSinceEpoch}';
        map[key] = n;
      }
      final combined = map.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(combined);
    }

    final fsSubUserId = _notificationsCollection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      fsByUserId = snapshot.docs
          .map((doc) =>
              NotificationModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      emitCombined();
    }, onError: (_) {
      fsByUserId = [];
      emitCombined();
    });

    final fsSubUid = _notificationsCollection
        .where('uid', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      fsByUid = snapshot.docs
          .map((doc) =>
              NotificationModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      emitCombined();
    }, onError: (_) {
      fsByUid = [];
      emitCombined();
    });

    final rtdbSub = _rtdb.child('notifications').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is! Map) {
        rtdbItems = [];
        emitCombined();
        return;
      }

      final parsed = <NotificationModel>[];
      if (value is Map) {
        final raw = _recursiveConvert(value) as Map<String, dynamic>;
        raw.forEach((key, v) {
          if (v is! Map) return;
          final data = Map<String, dynamic>.from(v);
          final targetId = (data['userId'] ?? data['uid'] ?? '').toString();
          if (targetId != userId) return;
          parsed.add(NotificationModel.fromMap(data, key));
        });
      }
      rtdbItems = parsed;
      emitCombined();
    });

    controller.onCancel = () async {
      await fsSubUserId.cancel();
      await fsSubUid.cancel();
      await rtdbSub.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  /// Get Unread Notification Count
  Stream<int> getUnreadNotificationCount(String userId) {
    return getNotificationsStream(userId)
        .map((items) => items.where((n) => !n.isRead).length);
  }

  /// Delete Notification
  Future<void> deleteNotification(String id) async {
    await _notificationsCollection.doc(id).delete();
    await _rtdb.child('notifications').child(id).remove();
  }

  // ========== REPORT OPERATIONS ==========



  /// Upload Image to Firebase Storage
  /// Accepts XFile for cross-platform compatibility (Web/Mobile/Desktop)
  Future<String> uploadImage(XFile file, String path) async {
    try {
      final ref = _storage.ref().child(path);
      // Use putData for cross-platform compatibility (works on Web, Mobile, Desktop)
      // File API (dart:io) requires conditional imports which is complex to set up here.
      final bytes = await file.readAsBytes().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Reading image timed out'),
      );
      final uploadTask = ref.putData(bytes);

      final snapshot = await uploadTask.timeout(
        const Duration(seconds: 25),
        onTimeout: () => throw Exception('Uploading image timed out'),
      );
      return await snapshot.ref.getDownloadURL().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Fetching image URL timed out'),
      );
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    }
  }

  /// Create Report
  Future<String> createReport(ReportModel report) async {
    try {
      print('📝 Creating report by user: ${report.reporterId}');
      
      final reportId = await _nextPrefixedId(counterKey: 'report', prefix: 'REP');
      
      final baseMap = report.toMap();
      baseMap['reportId'] = reportId;
      baseMap['customId'] = reportId;
      baseMap['reporterId'] = (baseMap['reporterId'] ?? report.reporterId).toString();
      baseMap['uid'] = baseMap['reporterId'];
      
      String? docId;
      Object? firestoreError;
      
      try {
        final docRef = await _reportsCollection
            .add(baseMap)
            .timeout(const Duration(seconds: 10));
        docId = docRef.id;
        print('✅ Report created in Firestore: $docId');
      } catch (e) {
        firestoreError = e;
        print('⚠️ Firestore report add failed: $e. Proceeding to RTDB.');
        docId = reportId;
      }

      // Sync to RTDB
      final rtdbMap = Map<String, dynamic>.from(baseMap);
      rtdbMap['id'] = docId;
      
      void convertToEpoch(String key) {
        if (rtdbMap[key] is Timestamp) {
          rtdbMap[key] = (rtdbMap[key] as Timestamp).millisecondsSinceEpoch;
        } else if (rtdbMap[key] is DateTime) {
          rtdbMap[key] = (rtdbMap[key] as DateTime).millisecondsSinceEpoch;
        }
      }
      
      convertToEpoch('createdAt');
      convertToEpoch('resolvedAt');

      bool wroteRtdb = false;
      Object? lastRtdbError;
      
      try {
        await _rtdb.child('reports').child(docId!).set(rtdbMap).timeout(const Duration(seconds: 10));
        wroteRtdb = true;
      } catch (e) {
        lastRtdbError = e;
        print('⚠️ RTDB reports write failed: $e');
      }
      
      try {
        await _rtdb.child('issues').child(docId!).set(rtdbMap).timeout(const Duration(seconds: 10));
        wroteRtdb = true;
      } catch (e) {
        if (!wroteRtdb) lastRtdbError = e;
        print('⚠️ RTDB issues write failed: $e');
      }

      if (!wroteRtdb && firestoreError != null) {
        throw Exception(
          'Report not saved. (Firestore: $firestoreError, RTDB: $lastRtdbError)',
        );
      }

      return docId!;
    } catch (e) {
      print('❌ Error creating report: $e');
      rethrow;
    }
  }
  /// Update Report
  Future<void> updateReport(String id, Map<String, dynamic> data) async {
    await _reportsCollection.doc(id).update(data);

    final rtdbData = Map<String, dynamic>.from(data);
    if (rtdbData['resolvedAt'] is Timestamp) {
      rtdbData['resolvedAt'] =
          (rtdbData['resolvedAt'] as Timestamp).millisecondsSinceEpoch;
    }
    await _rtdb.child('reports').child(id).update(rtdbData);
  }

  /// Get Report by ID
  Future<ReportModel?> getReport(String id) async {
    final doc = await _reportsCollection.doc(id).get();
    if (doc.exists) {
      return ReportModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  /// Get Reports Stream
    Stream<List<ReportModel>> getReportsStream({
    String? reporterId,
    String? status,
    String? type,
  }) {
    final controller = StreamController<List<ReportModel>>();
    List<ReportModel> fsItems = [];
    List<ReportModel> fsLegacyItems = [];
    List<ReportModel> rtdbItems = [];
    List<ReportModel> rtdbLegacyItems = [];

    bool matches(ReportModel report) {
      if (reporterId != null && report.reporterId != reporterId) return false;
      if (status != null && report.status != status) return false;
      if (type != null && report.type != type) return false;
      return true;
    }

    void emitCombined() {
      if (controller.isClosed) return;
      final merged = <String, ReportModel>{};
      for (final item in [...fsItems, ...fsLegacyItems, ...rtdbItems, ...rtdbLegacyItems]) {
        final key = item.id ??
            '${item.reporterId}_${item.title}_${item.createdAt.millisecondsSinceEpoch}';
        if (matches(item)) merged[key] = item;
      }
      final output = merged.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(output);
    }

    Query fsQuery = _reportsCollection;
    if (status != null) fsQuery = fsQuery.where('status', isEqualTo: status);
    if (type != null) fsQuery = fsQuery.where('type', isEqualTo: type);
    if (reporterId != null) {
      fsQuery = fsQuery.where('reporterId', isEqualTo: reporterId);
    }

    final fsSub = fsQuery.snapshots().listen((snapshot) {
      final parsed = <ReportModel>[];
      for (final doc in snapshot.docs) {
        try {
          parsed.add(
            ReportModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          );
        } catch (e) {
          print('Error parsing Firestore report: $e');
        }
      }
      fsItems = parsed;
      emitCombined();
    }, onError: (err) {
      print('⚠️ Firestore reports error: $err');
      if (err.toString().contains('permission-denied')) {
        print('💡 Permission denied for Firestore reports. Using RTDB fallback.');
        fsItems = [];
        emitCombined();
      }
    });

    Query fsLegacyQuery = _db.collection('issues');
    if (status != null) fsLegacyQuery = fsLegacyQuery.where('status', isEqualTo: status);
    if (type != null) fsLegacyQuery = fsLegacyQuery.where('type', isEqualTo: type);
    if (reporterId != null) {
      fsLegacyQuery = fsLegacyQuery.where('reporterId', isEqualTo: reporterId);
    }

    final fsLegacySub = fsLegacyQuery.snapshots().listen((snapshot) {
      final parsed = <ReportModel>[];
      for (final doc in snapshot.docs) {
        try {
          parsed.add(
            ReportModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          );
        } catch (e) {
          print('Error parsing Firestore legacy report: $e');
        }
      }
      fsLegacyItems = parsed;
      emitCombined();
    }, onError: (err) {
      print('⚠️ Firestore legacy issues error: $err');
      fsLegacyItems = [];
      emitCombined();
    });

    final rtdbSub = _rtdb.child('reports').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is! Map) {
        rtdbItems = [];
        emitCombined();
        return;
      }
      final parsed = <ReportModel>[];
      if (value is Map) {
        final raw = _recursiveConvert(value) as Map<String, dynamic>;
        raw.forEach((key, v) {
          if (v is! Map) return;
          try {
            parsed.add(
              ReportModel.fromMap(Map<String, dynamic>.from(v), key),
            );
          } catch (e) {
            print('Error parsing RTDB report: $e');
          }
        });
      }
      rtdbItems = parsed;
      emitCombined();
    }, onError: (err) {
      print('⚠️ RTDB reports error: $err');
      rtdbItems = [];
      emitCombined();
    });

    final rtdbLegacySub = _rtdb.child('issues').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is! Map) {
        rtdbLegacyItems = [];
        emitCombined();
        return;
      }
      final parsed = <ReportModel>[];
      if (value is Map) {
        final raw = _recursiveConvert(value) as Map<String, dynamic>;
        raw.forEach((key, v) {
          if (v is! Map) return;
          try {
            parsed.add(
              ReportModel.fromMap(Map<String, dynamic>.from(v), key),
            );
          } catch (_) {}
        });
      }
      rtdbLegacyItems = parsed;
      emitCombined();
    }, onError: (_) {
      rtdbLegacyItems = [];
      emitCombined();
    });

    controller.onCancel = () async {
      await fsSub.cancel();
      await fsLegacySub.cancel();
      await rtdbSub.cancel();
      await rtdbLegacySub.cancel();
      await controller.close();
    };

    return controller.stream;
  }
  /// Resolve Report
  Future<void> resolveReport(String id, String resolutionNotes) async {
    await _reportsCollection.doc(id).update({
      'status': 'resolved',
      'resolvedAt': Timestamp.now(),
      'resolutionNotes': resolutionNotes,
    });
    
    await _rtdb.child('reports').child(id).update({
      'status': 'resolved',
      'resolvedAt': DateTime.now().millisecondsSinceEpoch,
      'resolutionNotes': resolutionNotes,
    });
  }

  /// Assign report to a driver and optionally move it to in_progress.
  Future<void> assignDriverToReport({
    required String reportId,
    required String driverId,
  }) async {
    Map<String, dynamic>? reportData;
    try {
      final reportDoc = await _reportsCollection.doc(reportId).get();
      if (reportDoc.exists) {
        reportData = Map<String, dynamic>.from(reportDoc.data() as Map<String, dynamic>);
      }
    } catch (_) {}
    if (reportData == null) {
      try {
        final snap = await _rtdb.child('reports').child(reportId).get();
        if (snap.exists && snap.value != null) {
          final raw = _recursiveConvert(snap.value);
          if (raw is Map) reportData = Map<String, dynamic>.from(raw);
        }
      } catch (_) {}
    }
    if (reportData == null) {
      try {
        final snap = await _rtdb.child('issues').child(reportId).get();
        if (snap.exists && snap.value != null) {
          final raw = _recursiveConvert(snap.value);
          if (raw is Map) reportData = Map<String, dynamic>.from(raw);
        }
      } catch (_) {}
    }
    if (reportData == null) {
      throw Exception('Report not found');
    }

    final reporterId = (reportData['reporterId'] ?? reportData['uid'] ?? '').toString();
    final reportTitle = (reportData['title'] ?? 'Issue').toString();

    try {
    await _reportsCollection.doc(reportId).update({
      'assignedTo': driverId,
      'status': 'in_progress',
      'lastUpdated': Timestamp.now(),
    });
  } catch (e) {
    print('⚠️ Firestore report assign failed: $e');
  }

    Object? rtdbError;
    bool wroteRtdb = false;
    try {
      await _rtdb.child('reports').child(reportId).update({
        'assignedTo': driverId,
        'status': 'in_progress',
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      });
      wroteRtdb = true;
    } catch (e) {
      rtdbError = e;
    }
    try {
      await _rtdb.child('issues').child(reportId).update({
        'assignedTo': driverId,
        'status': 'in_progress',
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      });
      wroteRtdb = true;
    } catch (e) {
      rtdbError ??= e;
    }
    if (!wroteRtdb) {
      throw Exception('Assign failed (RTDB update denied): $rtdbError');
    }

    try {
      await createTask(
        TaskModel(
          requestId: reportId,
          driverId: driverId,
          assignedDate: DateTime.now(),
          status: 'assigned',
          notes: 'Assigned issue: $reportTitle',
        ),
      );
    } catch (_) {}

    try {
      await createNotification(
        NotificationModel(
          userId: driverId,
          title: 'New Task Assigned',
          message: 'You have been assigned issue: $reportTitle',
          type: 'issue_assigned',
          relatedEntityId: reportId,
          relatedEntityType: 'report',
          createdAt: DateTime.now(),
        ),
      );
    } catch (_) {}

    if (reporterId.isNotEmpty) {
      try {
        await createNotification(
          NotificationModel(
            userId: reporterId,
            title: 'Issue In Progress',
            message: 'Your report "$reportTitle" has been assigned to a driver.',
            type: 'issue_progress',
            relatedEntityId: reportId,
            relatedEntityType: 'report',
            createdAt: DateTime.now(),
          ),
        );
      } catch (_) {}
    }
  }

  /// Update report status with optional resolution note.
  Future<void> updateReportStatus({
    required String reportId,
    required String status,
    String? resolutionNotes,
  }) async {
    final firestoreData = <String, dynamic>{
      'status': status,
      'lastUpdated': Timestamp.now(),
    };

    final rtdbData = <String, dynamic>{
      'status': status,
      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
    };

    if (resolutionNotes != null && resolutionNotes.trim().isNotEmpty) {
      firestoreData['resolutionNotes'] = resolutionNotes.trim();
      rtdbData['resolutionNotes'] = resolutionNotes.trim();
    }

    if (status == 'resolved' || status == 'closed') {
      firestoreData['resolvedAt'] = Timestamp.now();
      rtdbData['resolvedAt'] = DateTime.now().millisecondsSinceEpoch;
    }

    try {
    await _reportsCollection.doc(reportId).update(firestoreData);
  } catch (e) {
    print('⚠️ Firestore report status update failed: $e');
  }
  
  try {
    await _rtdb.child('reports').child(reportId).update(rtdbData);
  } catch (e) {
    print('⚠️ RTDB report status update failed: $e');
  }
  }

  /// Delete Report
  Future<void> deleteReport(String id) async {
    await _reportsCollection.doc(id).delete();
    await _rtdb.child('reports').child(id).remove();
  }

  // ========== STATISTICS OPERATIONS ==========

  /// Save Daily Statistics
  Future<void> saveDailyStatistics(StatisticsModel stats) async {
    final dateKey = '${stats.date.year}-${stats.date.month.toString().padLeft(2, '0')}-${stats.date.day.toString().padLeft(2, '0')}';
    await _statisticsCollection.doc(dateKey).set(stats.toMap());
    await _rtdb.child('statistics').child(dateKey).set(stats.toMap());
  }

  /// Get Statistics for Date Range
  Stream<List<StatisticsModel>> getStatisticsStream({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query query = _statisticsCollection.orderBy('date', descending: true);

    if (startDate != null) {
      query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    if (endDate != null) {
      query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return StatisticsModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // ========== ADMIN ANALYTICS ==========

  /// Get Dashboard Statistics
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      // Get counts for different entities
      // Count citizens
      final citizensSnapshot = await _citizensCollection.count().get();
      final totalCitizens = citizensSnapshot.count ?? 0;
      
      // Count drivers
      final driversSnapshot = await _driversCollection.count().get();
      final totalDrivers = driversSnapshot.count ?? 0;
      
      // Count admins
      final adminsSnapshot = await _adminsCollection.count().get();
      final totalAdmins = adminsSnapshot.count ?? 0;
      
      final totalUsers = totalCitizens + totalDrivers + totalAdmins;

      final pickupsSnapshot = await _pickupRequestsCollection.get();
      final reportsSnapshot = await _reportsCollection.get();

      final totalPickups = pickupsSnapshot.docs.length;
      final pendingPickups = pickupsSnapshot.docs.where((doc) => 
        (doc.data() as Map<String, dynamic>)['status'] == 'pending'
      ).length;
      final completedPickups = pickupsSnapshot.docs.where((doc) => 
        (doc.data() as Map<String, dynamic>)['status'] == 'completed'
      ).length;

      final totalReports = reportsSnapshot.docs.length;
      final openReports = reportsSnapshot.docs.where((doc) => 
        (doc.data() as Map<String, dynamic>)['status'] == 'open'
      ).length;

      return {
        'totalUsers': totalUsers,
        'totalCitizens': totalCitizens,
        'totalDrivers': totalDrivers,
        'totalPickups': totalPickups,
        'pendingPickups': pendingPickups,
        'completedPickups': completedPickups,
        'totalReports': totalReports,
        'openReports': openReports,
      };
    } catch (e) {
      print('âŒ Error getting dashboard stats from Firestore: $e');
      try {
        final citizensSnap = await _rtdb.child('citizens').get();
        final driversSnap = await _rtdb.child('drivers').get();
        final pickupsSnap = await _rtdb.child('pickupRequests').get();
        final reportsSnap = await _rtdb.child('reports').get();

        int mapLength(DataSnapshot snap) {
          if (!snap.exists || snap.value is! Map) return 0;
          return Map<dynamic, dynamic>.from(snap.value as Map).length;
        }

        final totalCitizens = mapLength(citizensSnap);
        final totalDrivers = mapLength(driversSnap);
        final totalUsers = totalCitizens + totalDrivers;

        int countByStatus(DataSnapshot snap, String status) {
          if (!snap.exists || snap.value is! Map) return 0;
          final data = Map<dynamic, dynamic>.from(snap.value as Map);
          int count = 0;
          for (final entry in data.entries) {
            if (entry.value is! Map) continue;
            final row = Map<dynamic, dynamic>.from(entry.value as Map);
            if ((row['status'] ?? '').toString() == status) count++;
          }
          return count;
        }

        final totalPickups = mapLength(pickupsSnap);
        final pendingPickups = countByStatus(pickupsSnap, 'pending');
        final completedPickups = countByStatus(pickupsSnap, 'completed');
        final totalReports = mapLength(reportsSnap);
        final openReports = countByStatus(reportsSnap, 'open');

        return {
          'totalUsers': totalUsers,
          'totalCitizens': totalCitizens,
          'totalDrivers': totalDrivers,
          'totalPickups': totalPickups,
          'pendingPickups': pendingPickups,
          'completedPickups': completedPickups,
          'totalReports': totalReports,
          'openReports': openReports,
        };
      } catch (rtdbError) {
        print('âŒ Error getting dashboard stats from RTDB: $rtdbError');
        return {};
      }
    }
  }

  // ========== LEGACY COMPATIBILITY ==========
  // These methods maintain compatibility with existing code

  /// Legacy: Get drivers (returns raw map data)
  /// Legacy: Get drivers (returns raw map data)
  Stream<List<Map<String, dynamic>>> get driversStream {
    return _driversCollection
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Legacy: Add driver
  /// Legacy: Add driver
  Future<void> addDriver(Map<String, dynamic> driverData) async {
    final driverId = await _nextPrefixedId(counterKey: 'driver', prefix: 'dri');
    driverData['role'] = 'driver';
    driverData['driverId'] = driverId;
    driverData['customId'] = driverId;
    driverData['createdAt'] = Timestamp.now();
    await _driversCollection.add(driverData);
  }

  /// Legacy: Update driver
  Future<void> updateDriver(String id, Map<String, dynamic> data) async {
    await _driversCollection.doc(id).update(data);
  }

  /// Legacy: Delete driver
  Future<void> deleteDriver(String id) async {
    await _driversCollection.doc(id).set({
      'isActive': false,
      'updatedAt': Timestamp.now(),
      'deactivatedAt': Timestamp.now(),
    }, SetOptions(merge: true));

    await _rtdb.child('drivers').child(id).update({
      'isActive': false,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'deactivatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Legacy: Add schedule
  Future<void> addSchedule(Map<String, dynamic> scheduleData) async {
    final scheduleId = await _nextPrefixedId(counterKey: 'schedule', prefix: 'sche');
    scheduleData['scheduleId'] = scheduleId;
    scheduleData['customId'] = scheduleId;
    scheduleData['createdAt'] = Timestamp.now();
    await _schedulesCollection.add(scheduleData);
  }

  /// Legacy: Update schedule status
  Future<void> updateScheduleStatus(String id, String status) async {
    await _schedulesCollection.doc(id).update({'status': status});
  }

  /// Legacy: Report issue
  Future<void> reportIssue(Map<String, dynamic> issueData) async {
    final reportId = await _nextPrefixedId(counterKey: 'report', prefix: 'iss');
    issueData['reportId'] = reportId;
    issueData['customId'] = reportId;
    issueData['createdAt'] = Timestamp.now();
    issueData['status'] = 'open';
    await _reportsCollection.add(issueData);
  }
  // ========== LIVE LOCATION OPERATIONS ==========

  /// Update Driver Location
  Future<void> updateDriverLocation(String uid, double lat, double lng) async {
    await _driversCollection.doc(uid).update({
      'currentLocation': GeoPoint(lat, lng),
      'lastActive': Timestamp.now(),
      'isOnline': true,
    });
    
    // Update RTDB for real-time tracking (often better for frequent updates)
    await _rtdb.child('driver_locations').child(uid).set({
      'latitude': lat,
      'longitude': lng,
      'isOnline': true,
      'lastActive': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Set Driver Online Status
  Future<void> setDriverOnlineStatus(String uid, bool isOnline) async {
    await _driversCollection.doc(uid).update({
      'isOnline': isOnline,
      'lastActive': Timestamp.now(),
    });
    
    await _rtdb.child('driver_locations').child(uid).update({
      'isOnline': isOnline,
      'lastActive': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Get Active Drivers Stream
  /// Returns drivers who are online and have updated their location recently (optional filter)
  Stream<List<DriverModel>> getActiveDriversStream() {
    return _driversCollection
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return DriverModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// Get All Driver Locations Stream (Real-time from RTDB)
  Stream<Map<String, dynamic>> getDriverLocationsStream() {
    return _rtdb.child('driver_locations').onValue.map((event) {
      if (event.snapshot.value == null) return {};
      final raw = _recursiveConvert(event.snapshot.value);
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
      return {};
    });
  }

  // ========== REALTIME DATABASE USER OPERATIONS ==========
  // These methods read user data directly from Firebase Realtime Database

  /// Get ALL Citizens from Realtime Database
  Stream<List<Map<String, dynamic>>> getCitizensFromRTDB() {
    return _rtdb.child('citizens').onValue.map((event) {
      final List<Map<String, dynamic>> citizens = [];
      if (event.snapshot.value != null) {
        final rawData = _recursiveConvert(event.snapshot.value) as Map<String, dynamic>;
        rawData.forEach((key, value) {
          if (value is! Map) return;
          final citizen = Map<String, dynamic>.from(value);
          citizen['uid'] = key;
          citizens.add(citizen);
        });
      }
      print('ðŸ“± RTDB Citizens fetched: ${citizens.length}');
      return citizens;
    });
  }

  Stream<List<Map<String, dynamic>>> getDriversFromRTDB() {
    return _rtdb.child('drivers').onValue.map((event) {
      final List<Map<String, dynamic>> drivers = [];
      if (event.snapshot.value != null) {
        final rawData = _recursiveConvert(event.snapshot.value) as Map<String, dynamic>;
        rawData.forEach((key, value) {
          if (value is! Map) return;
          final driver = Map<String, dynamic>.from(value);
          driver['uid'] = key;
          drivers.add(driver);
        });
      }
      print('ðŸ“± RTDB Drivers fetched: ${drivers.length}');
      return drivers;
    });
  }

  /// Get ALL Admins from Realtime Database
  Stream<List<Map<String, dynamic>>> getAdminsFromRTDB() {
    return _rtdb.child('admins').onValue.map((event) {
      final List<Map<String, dynamic>> admins = [];
      if (event.snapshot.value != null) {
        final rawData = _recursiveConvert(event.snapshot.value) as Map<String, dynamic>;
        rawData.forEach((key, value) {
          if (value is! Map) return;
          final admin = Map<String, dynamic>.from(value);
          admin['uid'] = key;
          admins.add(admin);
        });
      }
      print('ðŸ“± RTDB Admins fetched: ${admins.length}');
      return admins;
    });
  }

  /// Get ALL Users from Realtime Database (combined)
  Stream<List<Map<String, dynamic>>> getAllUsersFromRTDB() {
    return _rtdb.child('users').onValue.map((event) {
      final List<Map<String, dynamic>> users = [];
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        data.forEach((key, value) {
          final user = Map<String, dynamic>.from(value as Map);
          user['uid'] = key;
          users.add(user);
        });
      }
      print('ðŸ“± RTDB Users fetched: ${users.length}');
      return users;
    });
  }

  /// Get a single user from RTDB by UID (checks all collections)
  Future<Map<String, dynamic>?> getUserFromRTDB(String uid) async {
    // Check citizens
    final citizenSnapshot = await _rtdb.child('citizens').child(uid).get();
    if (citizenSnapshot.exists) {
      final data = Map<String, dynamic>.from(citizenSnapshot.value as Map);
      data['uid'] = uid;
      return data;
    }

    // Check drivers
    final driverSnapshot = await _rtdb.child('drivers').child(uid).get();
    if (driverSnapshot.exists) {
      final data = Map<String, dynamic>.from(driverSnapshot.value as Map);
      data['uid'] = uid;
      return data;
    }

    // Check admins
    final adminSnapshot = await _rtdb.child('admins').child(uid).get();
    if (adminSnapshot.exists) {
      final data = Map<String, dynamic>.from(adminSnapshot.value as Map);
      data['uid'] = uid;
      return data;
    }

    // Check legacy users
    final userSnapshot = await _rtdb.child('users').child(uid).get();
    if (userSnapshot.exists) {
      final data = Map<String, dynamic>.from(userSnapshot.value as Map);
      data['uid'] = uid;
      return data;
    }

    return null;
  }

  /// Change user role (move user between collections in RTDB)
  Future<void> changeUserRole(String uid, String newRole) async {
    try {
      print('ðŸ”„ Changing user role to: $newRole for UID: $uid');
      
      // Get the current user data from any collection
      Map<String, dynamic>? userData = await getUserFromRTDB(uid);
      
      if (userData == null) {
        throw Exception('User not found in database');
      }
      
      String oldRole = userData['role'] ?? 'citizen';
      
      // Update role in the data
      userData['role'] = newRole;
      userData['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
      
      // Remove from old collection
      if (oldRole == 'citizen') {
        await _rtdb.child('citizens').child(uid).remove();
        await _citizensCollection.doc(uid).delete();
      } else if (oldRole == 'driver') {
        await _rtdb.child('drivers').child(uid).remove();
        await _driversCollection.doc(uid).delete();
      } else if (oldRole == 'admin') {
        await _rtdb.child('admins').child(uid).remove();
        await _adminsCollection.doc(uid).delete();
      } else {
        await _rtdb.child('users').child(uid).remove();
        await _usersCollection.doc(uid).delete();
      }
      
      // Add to new collection
      if (newRole == 'citizen') {
        await _rtdb.child('citizens').child(uid).set(userData);
        await _citizensCollection.doc(uid).set(userData);
      } else if (newRole == 'driver') {
        await _rtdb.child('drivers').child(uid).set(userData);
        await _driversCollection.doc(uid).set(userData);
      } else if (newRole == 'admin') {
        await _rtdb.child('admins').child(uid).set(userData);
        await _adminsCollection.doc(uid).set(userData);
      } else {
        await _rtdb.child('users').child(uid).set(userData);
        await _usersCollection.doc(uid).set(userData);
      }
      
      print('âœ… User role changed successfully to $newRole');
    } catch (e) {
      print('âŒ Error changing user role: $e');
      rethrow;
    }
  }

}

