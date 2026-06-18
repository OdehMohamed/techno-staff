import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/task_attachments_repository.dart';
import 'task_attachments_state.dart';

class TaskAttachmentsCubit extends Cubit<TaskAttachmentsState> {
  final TaskAttachmentsRepository _repository;

  TaskAttachmentsCubit({required TaskAttachmentsRepository repository})
      : _repository = repository,
        super(const TaskAttachmentsState());

  Future<void> loadAttachments(String taskId) async {
    if (state.currentTaskId == taskId &&
        state.status == TaskAttachmentsStatus.loaded) {
      return;
    }

    emit(state.copyWith(
      status: TaskAttachmentsStatus.loading,
      currentTaskId: taskId,
      briefAttachments: [],
      evidenceAttachments: [],
      clearError: true,
    ));

    try {
      final all = await _repository.getAttachments(taskId);
      emit(state.copyWith(
        status: TaskAttachmentsStatus.loaded,
        briefAttachments: all.where((a) => a.type == 'brief').toList(),
        evidenceAttachments: all.where((a) => a.type == 'evidence').toList(),
      ));
    } catch (_) {
      emit(state.copyWith(status: TaskAttachmentsStatus.error));
    }
  }

  Future<void> addAttachment({
    required String taskId,
    required String type,
    required XFile file,
    required String uploadedBy,
    required String uploadedByName,
  }) async {
    if (state.isUploading) return;
    emit(state.copyWith(isUploading: true, clearError: true));

    try {
      final uuid = const Uuid().v4();
      final attachment = await _repository.uploadAttachment(
        taskId: taskId,
        type: type,
        uuid: uuid,
        file: file,
        uploadedBy: uploadedBy,
        uploadedByName: uploadedByName,
      );

      if (type == 'brief') {
        emit(state.copyWith(
          isUploading: false,
          briefAttachments: [...state.briefAttachments, attachment],
        ));
      } else {
        emit(state.copyWith(
          isUploading: false,
          evidenceAttachments: [...state.evidenceAttachments, attachment],
        ));
      }
    } catch (_) {
      emit(state.copyWith(
        isUploading: false,
        error: 'attachment_upload_failed',
      ));
    }
  }

  void clear() => emit(const TaskAttachmentsState());
}
