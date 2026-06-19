import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:techno_staff/core/constants/firebase_paths.dart';

import '../models/task_attachment_model.dart';

class StorageUploadResult {
  final String storagePath;
  final String url;
  final String filename;
  final String mimeType;
  final int sizeBytes;

  StorageUploadResult({
    required this.storagePath,
    required this.url,
    required this.filename,
    required this.mimeType,
    required this.sizeBytes,
  });
}

class TaskAttachmentsRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  TaskAttachmentsRepository(this._firestore, this._storage);

  // Storage upload only — no Firestore write.
  // Used during task creation where the task doc doesn't exist yet.
  // The same uuid must be used as the Firestore doc ID when committing later.
  Future<StorageUploadResult> uploadToStorage({
    required String taskId,
    required String uuid,
    required XFile file,
  }) async {
    final filename = file.name.isNotEmpty ? file.name : uuid;
    final mimeType = _resolveMimeType(file);
    final storagePath = 'tasks/$taskId/attachments/$uuid';
    final sizeBytes = await file.length();

    final ref = _storage.ref(storagePath);
    final uploadTask = ref.putFile(
      File(file.path),
      SettableMetadata(contentType: mimeType),
    );
    try {
      await uploadTask.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      uploadTask.cancel();
      rethrow;
    }
    final url = await ref.getDownloadURL();

    return StorageUploadResult(
      storagePath: storagePath,
      url: url,
      filename: filename,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
    );
  }

  // Firestore metadata write only — Storage file must already exist.
  Future<void> createAttachmentRecord({
    required String taskId,
    required TaskAttachmentModel attachment,
  }) async {
    await _firestore
        .collection(FirebasePaths.tasks)
        .doc(taskId)
        .collection(FirebasePaths.taskAttachments)
        .doc(attachment.id)
        .set(attachment.toMap());
  }

  // Combined Storage + Firestore — use when task already exists.
  Future<TaskAttachmentModel> uploadAttachment({
    required String taskId,
    required String type,
    required String uuid,
    required XFile file,
    required String uploadedBy,
    required String uploadedByName,
  }) async {
    final result = await uploadToStorage(taskId: taskId, uuid: uuid, file: file);
    final attachment = TaskAttachmentModel(
      id: uuid,
      type: type,
      uploadedBy: uploadedBy,
      uploadedByName: uploadedByName,
      uploadedAt: DateTime.now(),
      url: result.url,
      storagePath: result.storagePath,
      mimeType: result.mimeType,
      filename: result.filename,
      sizeBytes: result.sizeBytes,
    );
    await createAttachmentRecord(taskId: taskId, attachment: attachment);
    return attachment;
  }

  Stream<List<TaskAttachmentModel>> watchAttachments(String taskId) {
    return _firestore
        .collection(FirebasePaths.tasks)
        .doc(taskId)
        .collection(FirebasePaths.taskAttachments)
        .orderBy('uploadedAt')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => TaskAttachmentModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> deleteAttachment({
    required String taskId,
    required String attachmentId,
    required String storagePath,
  }) async {
    await _firestore
        .collection(FirebasePaths.tasks)
        .doc(taskId)
        .collection(FirebasePaths.taskAttachments)
        .doc(attachmentId)
        .delete();
    // Fire-and-forget — Storage orphans handled by cleanupTaskAttachments CF.
    unawaited(deleteStorageFile(storagePath));
  }

  // Fire-and-forget orphan cleanup — swallows all errors intentionally.
  Future<void> deleteStorageFile(String storagePath) async {
    try {
      await _storage.ref(storagePath).delete();
    } catch (_) {}
  }

  String _resolveMimeType(XFile file) {
    if (file.mimeType != null && file.mimeType!.isNotEmpty) {
      return file.mimeType!;
    }
    final ext = file.path.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };
  }
}
