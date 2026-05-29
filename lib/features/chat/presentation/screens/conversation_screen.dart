import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../cubit/conversation_cubit.dart';
import '../cubit/conversation_state.dart';

/// Conversation screen. Milestone 3 delivers the shell (AppBar + stream wiring).
/// Message list, input bar, and delete are added in Milestone 4.
class ConversationScreen extends StatefulWidget {
  final String conversationId;

  const ConversationScreen({super.key, required this.conversationId});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthCubit>().state.user;
      if (user != null) {
        context.read<ConversationCubit>().loadConversation(
              widget.conversationId,
              user.id,
              user.name,
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConversationCubit, ConversationState>(
      builder: (context, state) {
        final conv = state.conversation;
        final currentUserId =
            context.read<AuthCubit>().state.user?.id ?? '';

        final title = conv != null
            ? conv.displayName(currentUserId)
            : '';

        final subtitle = conv != null && conv.isGroup
            ? '${conv.participantIds.length} members'
            : null;

        return Scaffold(
          appBar: AppBar(
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
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
          // Milestone 4: replace with message list + input bar.
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : const SizedBox.shrink(),
        );
      },
    );
  }
}
