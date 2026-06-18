import '../../data/models/task_attachment_model.dart';

enum TaskAttachmentsStatus { initial, loading, loaded, error }

class TaskAttachmentsState {
  final TaskAttachmentsStatus status;
  final String? currentTaskId;
  final List<TaskAttachmentModel> briefAttachments;
  final List<TaskAttachmentModel> evidenceAttachments;
  final bool isUploading;
  final String? error;

  const TaskAttachmentsState({
    this.status = TaskAttachmentsStatus.initial,
    this.currentTaskId,
    this.briefAttachments = const [],
    this.evidenceAttachments = const [],
    this.isUploading = false,
    this.error,
  });

  TaskAttachmentsState copyWith({
    TaskAttachmentsStatus? status,
    String? currentTaskId,
    List<TaskAttachmentModel>? briefAttachments,
    List<TaskAttachmentModel>? evidenceAttachments,
    bool? isUploading,
    String? error,
    bool clearError = false,
  }) {
    return TaskAttachmentsState(
      status: status ?? this.status,
      currentTaskId: currentTaskId ?? this.currentTaskId,
      briefAttachments: briefAttachments ?? this.briefAttachments,
      evidenceAttachments: evidenceAttachments ?? this.evidenceAttachments,
      isUploading: isUploading ?? this.isUploading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
