import 'package:flutter/material.dart';

import '../../data/models/task_attachment_model.dart';

class AttachmentTile extends StatelessWidget {
  final TaskAttachmentModel attachment;

  const AttachmentTile({super.key, required this.attachment});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openViewer(context),
      child: ClipRRect(
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
