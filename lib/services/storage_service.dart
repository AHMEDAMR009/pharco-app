import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/supabase_client.dart';

class StorageService {
  final SupabaseClient _client;
  StorageService([SupabaseClient? client]) : _client = client ?? supabase;

  static const _receiptsBucket = 'receipts';
  static const _avatarsBucket = 'avatars';

  /// Uploads a receipt photo and returns its storage object path
  /// (stored on RequestExtraCost.invoiceImagePath). Uses raw bytes (not
  /// dart:io's File) so this works on Web as well as Android/iOS.
  Future<String> uploadReceipt(XFile file, String employeeId) async {
    final bytes = await file.readAsBytes();
    final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
    final path = '$employeeId/${const Uuid().v4()}.$ext';
    await _client.storage.from(_receiptsBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: file.mimeType ?? 'image/jpeg'),
        );
    return path;
  }

  String publicUrl(String path) => _client.storage.from(_receiptsBucket).getPublicUrl(path);

  /// Uploads a profile picture, always at the same path for the employee
  /// (`upsert: true`) so re-uploading replaces the old photo instead of
  /// piling up orphaned files.
  Future<String> uploadAvatar(XFile file, String employeeId) async {
    final bytes = await file.readAsBytes();
    final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
    final path = '$employeeId/avatar.$ext';
    await _client.storage.from(_avatarsBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: file.mimeType ?? 'image/jpeg', upsert: true),
        );
    return path;
  }

  /// Cache-busted so the UI picks up a freshly uploaded avatar immediately
  /// instead of showing a stale cached image at the same URL.
  String avatarPublicUrl(String path) =>
      '${_client.storage.from(_avatarsBucket).getPublicUrl(path)}?t=${DateTime.now().millisecondsSinceEpoch}';
}
