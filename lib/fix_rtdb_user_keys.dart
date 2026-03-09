import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';

import 'firebase_options.dart';

/// One-time migration:
/// Ensures RTDB user nodes use Firebase Auth UID as the key.
///
/// Nodes handled:
/// - /citizens
/// - /drivers
/// - /admins
/// - /users (legacy)
///
/// For each record, UID is resolved using:
/// 1) data['uid']
/// 2) current key if it already looks like UID
/// 3) Firestore lookup by role-id/customId/email
///
/// Old records are backed up under:
/// /_migrations/rtdb_user_key_fix/{timestamp}/{node}/{oldKey}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final db = FirebaseDatabase.instance.ref();
  final fs = FirebaseFirestore.instance;
  final stamp = DateTime.now().millisecondsSinceEpoch.toString();

  print('========================================');
  print('RTDB USER KEY FIX START');
  print('Timestamp: $stamp');
  print('========================================');

  final migratedCitizens = await _migrateNode(
    db: db,
    fs: fs,
    node: 'citizens',
    role: 'citizen',
    roleIdField: 'citizenId',
    stamp: stamp,
  );

  final migratedDrivers = await _migrateNode(
    db: db,
    fs: fs,
    node: 'drivers',
    role: 'driver',
    roleIdField: 'driverId',
    stamp: stamp,
  );

  final migratedAdmins = await _migrateNode(
    db: db,
    fs: fs,
    node: 'admins',
    role: 'admin',
    roleIdField: 'adminId',
    stamp: stamp,
  );

  final migratedUsers = await _migrateNode(
    db: db,
    fs: fs,
    node: 'users',
    role: null,
    roleIdField: null,
    stamp: stamp,
  );

  print('========================================');
  print('RTDB USER KEY FIX COMPLETE');
  print('Migrated citizens: $migratedCitizens');
  print('Migrated drivers : $migratedDrivers');
  print('Migrated admins  : $migratedAdmins');
  print('Migrated users   : $migratedUsers');
  print('========================================');
}

Future<int> _migrateNode({
  required DatabaseReference db,
  required FirebaseFirestore fs,
  required String node,
  required String? role,
  required String? roleIdField,
  required String stamp,
}) async {
  final ref = db.child(node);
  final snap = await ref.get();
  if (!snap.exists || snap.value == null) {
    print('[$node] No data.');
    return 0;
  }

  final raw = Map<dynamic, dynamic>.from(snap.value as Map);
  var migrated = 0;

  print('[$node] Found ${raw.length} records.');

  for (final entry in raw.entries) {
    final oldKey = entry.key.toString();
    final data = Map<String, dynamic>.from(entry.value as Map);
    final resolvedUid = await _resolveUid(
      fs: fs,
      node: node,
      role: role,
      roleIdField: roleIdField,
      oldKey: oldKey,
      data: data,
    );

    if (resolvedUid == null || resolvedUid.isEmpty) {
      print('[$node] Skip $oldKey (UID not resolved).');
      continue;
    }

    data['uid'] = resolvedUid;
    if (role != null) data['role'] = role;

    if (resolvedUid == oldKey) {
      // Already correct key; only normalize uid/role fields.
      await ref.child(oldKey).update(data);
      continue;
    }

    final targetRef = ref.child(resolvedUid);
    final targetSnap = await targetRef.get();
    if (targetSnap.exists && targetSnap.value != null) {
      final existing = Map<String, dynamic>.from(targetSnap.value as Map);
      existing.addAll(data); // Prefer migrated values for freshness.
      await targetRef.set(existing);
    } else {
      await targetRef.set(data);
    }

    await db
        .child('_migrations')
        .child('rtdb_user_key_fix')
        .child(stamp)
        .child(node)
        .child(oldKey)
        .set(data);

    await ref.child(oldKey).remove();
    migrated++;
    print('[$node] Moved $oldKey -> $resolvedUid');
  }

  return migrated;
}

Future<String?> _resolveUid({
  required FirebaseFirestore fs,
  required String node,
  required String? role,
  required String? roleIdField,
  required String oldKey,
  required Map<String, dynamic> data,
}) async {
  final fromDataUid = (data['uid'] ?? '').toString().trim();
  if (_looksLikeUid(fromDataUid)) return fromDataUid;

  if (_looksLikeUid(oldKey)) return oldKey;

  final email = (data['email'] ?? '').toString().trim();

  String? uid;
  if (role != null) {
    uid = await _findUidInRoleCollection(
      fs: fs,
      role: role,
      email: email,
      roleIdField: roleIdField,
      oldKey: oldKey,
      data: data,
    );
    if (uid != null) return uid;
  }

  uid = await _findUidAcrossUserCollections(
    fs: fs,
    email: email,
    oldKey: oldKey,
  );
  if (uid != null) return uid;

  // Last chance: for legacy /users role hint.
  final roleHint = (data['role'] ?? '').toString().toLowerCase();
  if (node == 'users' &&
      (roleHint == 'citizen' || roleHint == 'driver' || roleHint == 'admin')) {
    uid = await _findUidInRoleCollection(
      fs: fs,
      role: roleHint,
      email: email,
      roleIdField: roleHint == 'citizen'
          ? 'citizenId'
          : roleHint == 'driver'
              ? 'driverId'
              : 'adminId',
      oldKey: oldKey,
      data: data,
    );
    if (uid != null) return uid;
  }

  return null;
}

Future<String?> _findUidInRoleCollection({
  required FirebaseFirestore fs,
  required String role,
  required String email,
  required String? roleIdField,
  required String oldKey,
  required Map<String, dynamic> data,
}) async {
  final col = fs.collection('${role}s');

  if (roleIdField != null) {
    final idValue = (data[roleIdField] ?? oldKey).toString().trim();
    if (idValue.isNotEmpty) {
      final byRoleId = await col.where(roleIdField, isEqualTo: idValue).limit(1).get();
      if (byRoleId.docs.isNotEmpty) return byRoleId.docs.first.id;
    }
  }

  final customId = (data['customId'] ?? oldKey).toString().trim();
  if (customId.isNotEmpty) {
    final byCustomId = await col.where('customId', isEqualTo: customId).limit(1).get();
    if (byCustomId.docs.isNotEmpty) return byCustomId.docs.first.id;
  }

  if (email.isNotEmpty) {
    final byEmail = await col.where('email', isEqualTo: email).limit(1).get();
    if (byEmail.docs.isNotEmpty) return byEmail.docs.first.id;
  }

  return null;
}

Future<String?> _findUidAcrossUserCollections({
  required FirebaseFirestore fs,
  required String email,
  required String oldKey,
}) async {
  for (final col in ['citizens', 'drivers', 'admins', 'users']) {
    if (email.isNotEmpty) {
      final byEmail =
          await fs.collection(col).where('email', isEqualTo: email).limit(1).get();
      if (byEmail.docs.isNotEmpty) return byEmail.docs.first.id;
    }

    final byCustomId =
        await fs.collection(col).where('customId', isEqualTo: oldKey).limit(1).get();
    if (byCustomId.docs.isNotEmpty) return byCustomId.docs.first.id;
  }
  return null;
}

bool _looksLikeUid(String value) {
  if (value.isEmpty) return false;
  if (value.startsWith('ad') || value.startsWith('dri') || value.startsWith('citi')) {
    return false;
  }
  return value.length >= 20;
}

