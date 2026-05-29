import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/chat_repository.dart';
import 'chat_list_state.dart';

class ChatListCubit extends Cubit<ChatListState> {
  final ChatRepository _repository;
  StreamSubscription? _subscription;
  String? _currentUserId;

  ChatListCubit({required ChatRepository chatRepository})
      : _repository = chatRepository,
        super(const ChatListState());

  void startListening(String uid) {
    // Guard: already streaming for this user.
    if (_currentUserId == uid && _subscription != null) return;

    _currentUserId = uid;
    _subscription?.cancel();
    emit(const ChatListState(isLoading: true));

    _subscription = _repository.streamConversations(uid).listen(
      (conversations) {
        final totalUnread = conversations.fold<int>(
          0,
          (sum, c) => sum + c.unreadCountFor(uid),
        );
        emit(ChatListState(
          conversations: conversations,
          totalUnread: totalUnread,
          isLoading: false,
        ));
      },
      onError: (_) => emit(state.copyWith(isLoading: false)),
    );
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _currentUserId = null;
    emit(const ChatListState());
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
