import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload Profile Picture
  Future<String> uploadProfilePicture(String userId, File imageFile) async {
    try {
      final ref = _storage.ref().child('profile_pictures/$userId/profile.jpg');
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload profile picture: $e');
    }
  }

  // Upload Issue Image
  Future<String> uploadIssueImage(String issueId, File imageFile) async {
    try {
      final String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = _storage.ref().child('issue_reports/$issueId/$fileName.jpg');
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload issue image: $e');
    }
  }

  // Delete File
  Future<void> deleteFile(String imageUrl) async {
    try {
      await _storage.refFromURL(imageUrl).delete();
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }
}
