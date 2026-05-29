import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/routes/route_names.dart';
import '../cubit/chat_list_cubit.dart';
import '../cubit/chat_list_state.dart';

/// AppBar action button that shows a red badge when there are unread messages.
/// Mirrors the [NotificationsBellButton] pattern exactly.
class ChatBadgeButton extends StatelessWidget {
  const ChatBadgeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatListCubit, ChatListState>(
      builder: (context, state) {
        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () =>
                  Navigator.pushNamed(context, RouteNames.chatList),
            ),
            if (state.totalUnread > 0)
              PositionedDirectional(
                top: 8,
                end: 8,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Center(
                    child: Text(
                      state.totalUnread > 99
                          ? '99+'
                          : '${state.totalUnread}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
