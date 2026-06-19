import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/task_attachment_model.dart';
import '../../data/repositories/task_attachments_repository.dart';
import 'task_attachments_state.dart';

class TaskAttachmentsCubit extends Cubit<TaskAttachmentsState> {
  final TaskAttachmentsRepository _repository;
  StreamSubscription<List<TaskAttachmentModel>>? _watchSub;

  TaskAttachmentsCubit({required TaskAttachmentsRepository repository})
      : _repository = repository,
        super(const TaskAttachmentsState());

  Future<void> loadAttachments(String taskId) async {
    if (state.currentTaskId == taskId) return; // already watching this task

    await _watchSub?.cancel();

    emit(state.copyWith(
      status: TaskAttachmentsStatus.loading,
      currentTaskId: taskId,
      briefAttachments: [],
      evidenceAttachments: [],
      clearError: true,
    ));

    _watchSub = _repository.watchAttachments(taskId).listen(
      (all) {
        if (isClosed) return;
        emit(state.copyWith(
          status: TaskAttachmentsStatus.loaded,
          briefAttachments: all.where((a) => a.type == 'brief').toList(),
          evidenceAttachments: all.where((a) => a.type == 'evidence').toList(),
        ));
      },
      onError: (_) {
        if (isClosed) return;
        emit(state.copyWith(status: TaskAttachmentsStatus.error));
      },
    );
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
      await _repository.uploadAttachment(
        taskId: taskId,
        type: type,
        uuid: uuid,
        file: file,
        uploadedBy: uploadedBy,
        uploadedByName: uploadedByName,
      );
      // The stream delivers the new attachment automatically; no manual
      // list append needed here.
      emit(state.copyWith(isUploading: false));
    } catch (_) {
      emit(state.copyWith(
        isUploading: false,
        error: 'attachment_upload_failed',
      ));
    }
  }

  Future<void> deleteAttachment({
    required String taskId,
    required String attachmentId,
    required String storagePath,
  }) async {
    if (state.isDeleting) return;
    emit(state.copyWith(isDeleting: true, clearError: true));

    try {
      await _repository.deleteAttachment(
        taskId: taskId,
        attachmentId: attachmentId,
        storagePath: storagePath,
      );
      // The stream removes the tile automatically.
      emit(state.copyWith(isDeleting: false));
    } catch (_) {
      emit(state.copyWith(
        isDeleting: false,
        error: 'attachment_delete_failed',
      ));
    }
  }

  Future<void> clear() async {
    await _watchSub?.cancel();
    _watchSub = null;
    emit(const TaskAttachmentsState());
  }

  @override
  Future<void> close() async {
    await _watchSub?.cancel();
    return super.close();
  }
}
