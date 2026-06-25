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
    String? writeRestriction,
  }) => _repository.createGroup(
    name: name,
    creatorUid: creatorUid,
    creatorName: creatorName,
    memberUids: memberUids,
    memberNames: memberNames,
    writeRestriction: writeRestriction,
  );

  /// Opens an existing task-linked conversation or creates a new one.
  /// [initiatorUid]/[initiatorName] must be the currently signed-in user —
  /// used as [createdBy] so the Firestore create rule is satisfied regardless
  /// of whether the initiator is the task creator or the assignee.
  Future<String> getOrCreateTaskThread({
    required String taskId,
    required String taskTitle,
    required String initiatorUid,
    required String initiatorName,
    required String creatorUid,
    required String creatorName,
    required String assigneeUid,
    required String assigneeName,
  }) => _repository.getOrCreateTaskThread(
    taskId: taskId,
    taskTitle: taskTitle,
    initiatorUid: initiatorUid,
    initiatorName: initiatorName,
    creatorUid: creatorUid,
    creatorName: creatorName,
    assigneeUid: assigneeUid,
    assigneeName: assigneeName,
  );

  Future<void> addGroupMember({
    required String conversationId,
    required String actorUid,
    required String actorName,
    required String newMemberUid,
    required String newMemberName,
  }) => _repository.addGroupMember(
    conversationId: conversationId,
    actorUid: actorUid,
    actorName: actorName,
    newMemberUid: newMemberUid,
    newMemberName: newMemberName,
  );

  Future<void> removeGroupMember({
    required String conversationId,
    required String actorUid,
    required String actorName,
    required String memberUid,
    required String memberName,
  }) => _repository.removeGroupMember(
    conversationId: conversationId,
    actorUid: actorUid,
    actorName: actorName,
    memberUid: memberUid,
    memberName: memberName,
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
