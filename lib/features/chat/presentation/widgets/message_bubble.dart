import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/user_avatar_widget.dart';
import '../../data/models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isOwnMessage;
  final bool showSenderName; // true for group chats (other's messages)
  final bool showAvatar;     // true for group/task thread other's messages
  final GestureLongPressCallback? onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isOwnMessage,
    this.showSenderName = false,
    this.showAvatar = false,
    this.onLongPress,
  });

  // ─── System message ───────────────────────────────────────────────────────

  Widget _buildSystemMessage(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 32),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.text ?? '',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
        ),
      ),
    );
  }

  // ─── Chat bubble ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) return _buildSystemMessage(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDeleted = message.isDeleted;

    // Bubble colors — chat alignment is always LTR (own = right, other = left)
    // regardless of the app's locale direction.
    final Color bubbleColor;
    final Color textColor;
    if (isOwnMessage) {
      bubbleColor = isDeleted
          ? AppColors.accent.withValues(alpha: 0.4)
          : AppColors.accent;
      textColor = Colors.white;
    } else {
      bubbleColor = isDark
          ? AppColors.secondary
          : const Color(0xFFEEEEEF);
      textColor = Theme.of(context).colorScheme.onSurface;
    }

    final displayText = isDeleted
        ? 'message_deleted'.tr()
        : (message.text ?? '');

    final timestamp = _formatTime(message.sentAt);

    return Align(
      // Explicit non-directional alignment so Arabic locale cannot flip bubbles.
      alignment: isOwnMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left: isOwnMessage ? 64 : 8,
          right: isOwnMessage ? 8 : 64,
          top: 2,
          bottom: 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Avatar for other's messages in groups (left side)
            if (!isOwnMessage && showAvatar) ...[
              UserAvatarWidget(
                name: message.senderName,
                uid: message.senderId,
                radius: 14,
              ),
              const SizedBox(width: 6),
            ] else if (!isOwnMessage && !showAvatar)
              const SizedBox(width: 36), // reserved space to keep alignment consistent

            // Bubble
            Flexible(
              child: GestureDetector(
                onLongPress: onLongPress,
                child: Container(
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isOwnMessage ? 16 : 4),
                      bottomRight: Radius.circular(isOwnMessage ? 4 : 16),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: isOwnMessage
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sender name in group chats
                      if (showSenderName)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            message.senderName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: UserAvatarWidget.colorForUid(
                                  message.senderId),
                            ),
                          ),
                        ),

                      // Message text
                      Text(
                        displayText,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDeleted
                              ? textColor.withValues(alpha: 0.6)
                              : textColor,
                          fontStyle: isDeleted
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),

                      // Timestamp
                      const SizedBox(height: 2),
                      Text(
                        timestamp,
                        style: TextStyle(
                          fontSize: 11,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) => DateFormat.jm().format(dt);
}
