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

  /// Creates a DM conversation (or returns an existing one) without emitting
  /// state. The caller is responsible for navigating to the conversation.
  Future<String> getOrCreateDm(
    String uid1,
    String uid2,
    String name1,
    String name2,
  ) => _repository.getOrCreateDm(uid1, uid2, name1, name2);

  /// Creates a new group conversation with a system message.
  /// Returns the new conversation ID without emitting state.
  Future<String> createGroup({
    required String name,
    required String creatorUid,
    required String creatorName,
    required List<String> memberUids,
    required Map<String, String> memberNames,
  }) => _repository.createGroup(
    name: name,
    creatorUid: creatorUid,
    creatorName: creatorName,
    memberUids: memberUids,
    memberNames: memberNames,
  );

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
