// Firebase Storage helper (Faz 4): uploads photos/files and returns download
// URLs, replacing the base64 data URIs we stored inline before. URLs are tiny,
// so they fix the Firestore 1 MiB/doc limit (catalog) and load faster.
//
// Rendering is unchanged — image_helpers already shows http(s) URLs via
// Image.network. Security: /catalog read=all,write=admin; /users/{uid} owner
// (see firebase/storage.rules).

import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FileStorage {
  FileStorage._();
  static final FileStorage instance = FileStorage._();

  /// Uploads a base64 data URI to [path] and returns its download URL.
  /// Returns [value] unchanged if it's empty or already an http(s) URL.
  /// On failure returns the original value so callers degrade to base64.
  Future<String> uploadDataUri(String path, String? value) async {
    if (value == null || value.isEmpty) return value ?? "";
    if (value.startsWith('http')) return value; // already a URL — no re-upload
    if (!value.startsWith('data:')) return value;
    try {
      final semi = value.indexOf(';');
      final contentType = semi > 5 ? value.substring(5, semi) : 'image/jpeg';
      final bytes = base64Decode(value.split(',').last);
      final ref = FirebaseStorage.instance.ref(path);
      await ref.putData(bytes, SettableMetadata(contentType: contentType));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('FileStorage.uploadDataUri failed: $e');
      return value; // keep base64 fallback
    }
  }

  /// Uploads raw bytes (e.g. a picked PDF) to [path]; returns the download URL
  /// or null on failure.
  Future<String?> uploadBytes(String path, Uint8List bytes, String contentType) async {
    try {
      final ref = FirebaseStorage.instance.ref(path);
      await ref.putData(bytes, SettableMetadata(contentType: contentType));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('FileStorage.uploadBytes failed: $e');
      return null;
    }
  }

  /// Best-effort delete of a previously uploaded download URL.
  Future<void> deleteUrl(String url) async {
    if (!url.startsWith('http')) return;
    try {
      await FirebaseStorage.instance.refFromURL(url).delete();
    } catch (e) {
      debugPrint('FileStorage.deleteUrl failed: $e');
    }
  }
}
