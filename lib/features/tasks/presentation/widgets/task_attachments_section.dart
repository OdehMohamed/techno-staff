import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/section_header.dart';
import '../cubit/task_attachments_cubit.dart';
import '../cubit/task_attachments_state.dart';
import 'attachment_tile.dart';

class TaskAttachmentsSection extends StatelessWidget {
  final String taskId;
  final String type; // 'brief' | 'evidence'
  final bool canUpload;
  final String uploadedBy;
  final String uploadedByName;

  /// True when the viewer is an admin or the task creator — they may delete
  /// any attachment on this task regardless of who uploaded it.
  final bool canDeleteAny;

  const TaskAttachmentsSection({
    super.key,
    required this.taskId,
    required this.type,
    required this.canUpload,
    required this.uploadedBy,
    required this.uploadedByName,
    this.canDeleteAny = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaskAttachmentsCubit, TaskAttachmentsState>(
      builder: (context, state) {
        final attachments = type == 'brief'
            ? state.briefAttachments
            : state.evidenceAttachments;

        final titleKey =
            type == 'brief' ? 'task_materials' : 'completion_evidence';
        final subtitleKey = type == 'brief'
            ? 'task_materials_subtitle'
            : 'completion_evidence_subtitle';
        final emptyKey = type == 'brief'
            ? 'no_task_materials'
            : 'no_completion_evidence';

        // Hide empty read-only sections entirely.
        if (attachments.isEmpty &&
            !canUpload &&
            !canDeleteAny &&
            state.status == TaskAttachmentsStatus.loaded) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: titleKey.tr(),
              subtitle: subtitleKey.tr(),
            ),
            if (state.status == TaskAttachmentsStatus.loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSizes.md),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (attachments.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.sm),
                child: Text(
                  emptyKey.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.sm),
                child: Wrap(
                  spacing: AppSizes.sm,
                  runSpacing: AppSizes.sm,
                  children: attachments.map((a) {
                    final canDelete =
                        canDeleteAny || a.uploadedBy == uploadedBy;
                    return AttachmentTile(
                      attachment: a,
                      taskId: taskId,
                      canDelete: canDelete,
                    );
                  }).toList(),
                ),
              ),
            if (state.isUploading || state.isDeleting)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSizes.sm),
                child: LinearProgressIndicator(),
              ),
            if (canUpload && !state.isUploading && !state.isDeleting)
              OutlinedButton.icon(
                onPressed: () => _pickPhoto(context),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text('add_photo'.tr()),
              ),
          ],
        );
      },
    );
  }

  Future<void> _pickPhoto(BuildContext context) async {
    final source = await _showSourcePicker(context);
    if (source == null) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    if (file == null) return;
    if (!context.mounted) return;

    await context.read<TaskAttachmentsCubit>().addAttachment(
          taskId: taskId,
          type: type,
          file: file,
          uploadedBy: uploadedBy,
          uploadedByName: uploadedByName,
        );
  }

  Future<ImageSource?> _showSourcePicker(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text('photo_source_camera'.tr()),
              onTap: () => Navigator.pop(sheetCtx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('photo_source_gallery'.tr()),
              onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}
