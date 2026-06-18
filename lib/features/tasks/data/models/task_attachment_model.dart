import 'package:cloud_firestore/cloud_firestore.dart';

class TaskAttachmentModel {
  final String id;
  final String type; // 'brief' | 'evidence'
  final String uploadedBy;
  final String uploadedByName;
  final DateTime uploadedAt;
  final String url;
  final String storagePath;
  final String mimeType;
  final String filename;
  final int sizeBytes;

  const TaskAttachmentModel({
    required this.id,
    required this.type,
    required this.uploadedBy,
    required this.uploadedByName,
    required this.uploadedAt,
    required this.url,
    required this.storagePath,
    required this.mimeType,
    required this.filename,
    required this.sizeBytes,
  });

  bool get isImage => mimeType.startsWith('image/');

  factory TaskAttachmentModel.fromMap(String id, Map<String, dynamic> data) {
    return TaskAttachmentModel(
      id: id,
      type: data['type'] as String? ?? 'brief',
      uploadedBy: data['uploadedBy'] as String? ?? '',
      uploadedByName: data['uploadedByName'] as String? ?? '',
      uploadedAt: data['uploadedAt'] != null
          ? (data['uploadedAt'] as Timestamp).toDate()
          : DateTime.now(),
      url: data['url'] as String? ?? '',
      storagePath: data['storagePath'] as String? ?? '',
      mimeType: data['mimeType'] as String? ?? 'image/jpeg',
      filename: data['filename'] as String? ?? '',
      sizeBytes: data['sizeBytes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'uploadedBy': uploadedBy,
      'uploadedByName': uploadedByName,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'url': url,
      'storagePath': storagePath,
      'mimeType': mimeType,
      'filename': filename,
      'sizeBytes': sizeBytes,
    };
  }
}
