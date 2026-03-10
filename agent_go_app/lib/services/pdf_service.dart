import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/pdf_upload_model.dart';

/// Handles PDF file picking, uploading to storage, and tracking.
class PdfService {
  final SupabaseClient _client;
  final List<String> _targetUserIds;

  PdfService(this._client, {List<String>? targetUserIds})
      : _targetUserIds = targetUserIds ?? [_client.auth.currentUser!.id];

  String get _userId => _client.auth.currentUser!.id;

  /// Pick a PDF file from device. Returns a PlatformFile with bytes or path.
  Future<PlatformFile?> pickPdfFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
        withData: true, // Load bytes into memory — more reliable on Android
      );
      if (result == null || result.files.isEmpty) return null;
      return result.files.single;
    } catch (e) {
      throw Exception('Could not pick file: $e');
    }
  }

  /// Upload a PDF and create a tracking record.
  /// Uses bytes from PlatformFile for cross-platform reliability.
  Future<PdfUploadModel> uploadPdf({
    required PlatformFile platformFile,
    required String fileName,
    String? dueMonth,
    String? targetUserId, // Added: Which agent is this for?
  }) async {
    // Determine the owner of this PDF
    final ownerId = targetUserId ?? _userId;

    // 1. Get file bytes (either from memory or from path)
    Uint8List bytes;
    if (platformFile.bytes != null) {
      bytes = platformFile.bytes!;
    } else if (platformFile.path != null) {
      bytes = await File(platformFile.path!).readAsBytes();
    } else {
      throw Exception('Cannot read file data');
    }

    // 2. Upload file to Supabase Storage
    final storagePath = '$ownerId/$fileName';
    await _client.storage.from(SupabaseConfig.pdfBucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'application/pdf',
          ),
        );

    // 3. Get the public/signed URL
    final fileUrl = _client.storage
        .from(SupabaseConfig.pdfBucket)
        .getPublicUrl(storagePath);

    // 4. Create a tracking record in pdf_uploads table
    final response = await _client.from('pdf_uploads').insert({
      'user_id': ownerId, // Use ownerId here
      'file_url': fileUrl,
      'file_name': fileName,
      'file_size': bytes.length,
      'status': 'uploaded',
      'due_month': dueMonth,
    }).select().single();

    return PdfUploadModel.fromJson(response);
  }

  /// Get all PDF uploads for the user.
  Future<List<PdfUploadModel>> getUploads() async {
    final response = await _client
        .from('pdf_uploads')
        .select()
        .inFilter('user_id', _targetUserIds)
        .order('created_at', ascending: false);

    return (response as List).map((e) => PdfUploadModel.fromJson(e)).toList();
  }

  /// Get a single upload by ID.
  Future<PdfUploadModel?> getUpload(String uploadId) async {
    final response = await _client
        .from('pdf_uploads')
        .select()
        .eq('id', uploadId)
        .eq('user_id', _userId)
        .maybeSingle();

    if (response == null) return null;
    return PdfUploadModel.fromJson(response);
  }

  /// Update upload status (for manual processing tracking).
  Future<void> updateUploadStatus(String uploadId, String status,
      {String? errorMessage}) async {
    final updates = <String, dynamic>{
      'status': status,
    };
    if (status == 'completed') {
      updates['processed_at'] = DateTime.now().toIso8601String();
    }
    if (errorMessage != null) {
      updates['error_message'] = errorMessage;
    }
    await _client
        .from('pdf_uploads')
        .update(updates)
        .eq('id', uploadId)
        .eq('user_id', _userId);
  }

  /// Delete an upload and its storage file.
  Future<void> deleteUpload(String uploadId, String fileName) async {
    // Delete from storage
    await _client.storage
        .from(SupabaseConfig.pdfBucket)
        .remove(['$_userId/$fileName']);

    // Delete tracking record
    await _client
        .from('pdf_uploads')
        .delete()
        .eq('id', uploadId)
        .eq('user_id', _userId);
  }
}
