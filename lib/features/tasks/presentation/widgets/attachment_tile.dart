import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/task_attachment_model.dart';
import '../cubit/task_attachments_cubit.dart';

class AttachmentTile extends StatelessWidget {
  final TaskAttachmentModel attachment;
  final String taskId;
  final bool canDelete;

  const AttachmentTile({
    super.key,
    required this.attachment,
    required this.taskId,
    this.canDelete = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openViewer(context),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 80,
              height: 80,
              child: attachment.isImage
                  ? Image.network(
                      attachment.url,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : const ColoredBox(
                              color: Color(0x1A000000),
                              child: Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0x1A000000),
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    )
                  : const ColoredBox(
                      color: Color(0x1A000000),
                      child: Icon(Icons.insert_drive_file_outlined, size: 32),
                    ),
            ),
          ),
          if (canDelete)
            Positioned(
              top: 2,
              right: 2,
              child: _DeleteButton(taskId: taskId, attachment: attachment),
            ),
        ],
      ),
    );
  }

  void _openViewer(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(dialogCtx),
              child: InteractiveViewer(
                child: Center(
                  child: Image.network(
                    attachment.url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(dialogCtx),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  final String taskId;
  final TaskAttachmentModel attachment;

  const _DeleteButton({required this.taskId, required this.attachment});

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    return GestureDetector(
      onTap: () => _confirmDelete(context),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: errorColor,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, color: Colors.white, size: 14),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<TaskAttachmentsCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('delete_attachment'.tr()),
        content: Text('delete_attachment_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogCtx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await cubit.deleteAttachment(
      taskId: taskId,
      attachmentId: attachment.id,
      storagePath: attachment.storagePath,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('attachment_deleted'.tr())),
      );
    }
  }
}
