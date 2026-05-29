import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../cubit/conversation_cubit.dart';
import '../cubit/conversation_state.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_bubble.dart';

class ConversationScreen extends StatefulWidget {
  final String conversationId;

  const ConversationScreen({super.key, required this.conversationId});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _scrollController = ScrollController();
  bool _showScrollToBottom = false;
  String? _currentUserId;
  int _prevMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthCubit>().state.user;
      if (user != null) {
        _currentUserId = user.id;
        context.read<ConversationCubit>().loadConversation(
              widget.conversationId,
              user.id,
              user.name,
            );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    // scroll-to-bottom FAB visibility
    final atBottom = _scrollController.offset < 200;
    if (!atBottom != _showScrollToBottom) {
      setState(() => _showScrollToBottom = !atBottom);
    }

    // Pagination: trigger when the user has scrolled near the top
    // (oldest messages end of the reversed list)
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 150) {
      context.read<ConversationCubit>().loadOlderMessages();
    }
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _showDeleteSheet(BuildContext ctx, String messageId) {
    showModalBottomSheet<void>(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: Text(
              'delete_message'.tr(),
              style: const TextStyle(color: Colors.red),
            ),
            onTap: () {
              Navigator.of(context).pop();
              context.read<ConversationCubit>().deleteMessage(messageId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.cancel_outlined),
            title: Text('cancel'.tr()),
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context, ConversationState state) {
    final conv = state.conversation;
    final uid = _currentUserId ?? '';
    final title = conv?.displayName(uid) ?? '';
    final isGroup = conv?.isGroup == true || conv?.isTaskThread == true;
    final memberCount = conv?.participantIds.length ?? 0;

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title.isEmpty)
            const SizedBox(
              width: 80,
              height: 14,
              child: LinearProgressIndicator(),
            )
          else
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          if (isGroup && memberCount > 0)
            Text(
              'members_count'.tr(namedArgs: {'count': memberCount.toString()}),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
        ],
      ),
    );
  }

  // ─── Message list ─────────────────────────────────────────────────────────

  Widget _buildMessageList(BuildContext context, ConversationState state) {
    if (state.isLoading && state.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.messages.isEmpty) {
      return Center(
        child: Text(
          'no_messages_yet'.tr(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    final uid = _currentUserId ?? '';
    final isGroup = state.conversation?.isGroup == true ||
        state.conversation?.isTaskThread == true;
    final messages = state.messages; // descending: index 0 = newest
    final itemCount = messages.length + (state.isLoadingOlder ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Last item in the reversed list = pagination loading indicator
        if (index == messages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final message = messages[index];
        final isOwn = message.senderId == uid;

        // Show sender name + avatar for others' messages in groups/threads.
        // Also decide whether to show avatar: only when the next message
        // (index + 1, which is older) is from a different sender or doesn't exist.
        final showSenderName = isGroup && !isOwn && !message.isSystem;
        final nextMessage =
            index + 1 < messages.length ? messages[index + 1] : null;
        final showAvatar = isGroup &&
            !isOwn &&
            !message.isSystem &&
            (nextMessage == null || nextMessage.senderId != message.senderId);

        return MessageBubble(
          message: message,
          isOwnMessage: isOwn,
          showSenderName: showSenderName,
          showAvatar: showAvatar,
          onLongPress: isOwn && !message.isDeleted
              ? () => _showDeleteSheet(context, message.id)
              : null,
        );
      },
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConversationCubit, ConversationState>(
      listenWhen: (prev, curr) =>
          // New messages arrived
          curr.messages.length != prev.messages.length ||
          // Send error changed
          (curr.sendError != null && curr.sendError != prev.sendError),
      listener: (context, state) {
        // Auto-scroll to bottom when new messages arrive and user is near bottom
        if (state.messages.length > _prevMessageCount &&
            _scrollController.hasClients &&
            _scrollController.offset < 150) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          });
        }
        _prevMessageCount = state.messages.length;

        // Send error snackbar
        if (state.sendError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('send_failed'.tr())),
          );
          context.read<ConversationCubit>().clearSendError();
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: _buildAppBar(context, state),
          body: Column(
            children: [
              // Message list
              Expanded(
                child: Stack(
                  children: [
                    _buildMessageList(context, state),

                    // Scroll-to-bottom FAB
                    if (_showScrollToBottom)
                      Positioned(
                        bottom: 8,
                        right: 12,
                        child: FloatingActionButton.small(
                          heroTag: 'scroll_to_bottom',
                          onPressed: _scrollToBottom,
                          backgroundColor:
                              Theme.of(context).colorScheme.surface,
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Input bar
              ChatInputBar(
                isSending: state.isSending,
                onSend: (text) =>
                    context.read<ConversationCubit>().sendMessage(text),
              ),
            ],
          ),
        );
      },
    );
  }
}
