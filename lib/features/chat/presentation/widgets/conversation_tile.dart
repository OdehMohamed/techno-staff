import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/user_avatar_widget.dart';
import '../../data/models/conversation_model.dart';

class ConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  final String currentUserId;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  });

  // ─── Timestamp ────────────────────────────────────────────────────────────

  String _formatTimestamp(DateTime? dt, BuildContext context) {
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);

    if (msgDay == today) return DateFormat.jm().format(dt);
    if (msgDay == today.subtract(const Duration(days: 1))) {
      return 'yesterday'.tr();
    }
    return DateFormat('d MMM').format(dt);
  }

  // ─── Preview text ─────────────────────────────────────────────────────────

  String _previewText(BuildContext context) {
    final last = conversation.lastMessage;
    if (last == null) return '';

    // Soft-deleted messages
    if (last.text == '[deleted]') return 'message_deleted'.tr();

    // System messages are shown as-is, without a sender prefix
    // (type 'system' on ConversationLastMessage is inferred from text patterns;
    // in v1 system messages are stored as plain text)
    final isSelf = last.senderId == currentUserId;
    final prefix = isSelf
        ? '${'you'.tr()}: '
        : (conversation.isGroup ? '${last.senderName}: ' : '');

    return '$prefix${last.text}';
  }

  // ─── Avatar source ────────────────────────────────────────────────────────

  /// For DMs the avatar represents the other participant; for groups it
  /// represents the group (using the first non-self participant for color/initial).
  (String name, String uid) _avatarSource() {
    if (conversation.isDm) {
      final other = conversation.participantNames.entries
          .where((e) => e.key != currentUserId)
          .firstOrNull;
      return (other?.value ?? '?', other?.key ?? conversation.id);
    }
    // Group / task thread: use the group name initial and conversation id for color
    return (
      conversation.name ?? conversation.id,
      conversation.id,
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = conversation.unreadCountFor(currentUserId);
    final hasUnread = unread > 0;
    final displayName = conversation.displayName(currentUserId);
    final preview = _previewText(context);
    final timestamp = _formatTimestamp(conversation.lastMessageAt, context);
    final (avatarName, avatarUid) = _avatarSource();
    final isDeleted = preview == 'message_deleted'.tr();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar
            UserAvatarWidget(name: avatarName, uid: avatarUid, radius: 24),
            const SizedBox(width: 12),

            // Name + preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight:
                          hasUnread ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (preview.isNotEmpty)
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDeleted
                            ? theme.colorScheme.outline
                            : (hasUnread
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant),
                        fontStyle:
                            isDeleted ? FontStyle.italic : FontStyle.normal,
                        fontWeight: hasUnread
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Timestamp + unread badge (stacked vertically, right-aligned)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timestamp,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: hasUnread
                        ? AppColors.accent
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: hasUnread
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                if (hasUnread) ...[
                  const SizedBox(height: 4),
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Center(
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
