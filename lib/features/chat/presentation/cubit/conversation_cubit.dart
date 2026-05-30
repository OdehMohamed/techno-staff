import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/message_model.dart';
import '../../data/repositories/chat_repository.dart';
import 'conversation_state.dart';

class ConversationCubit extends Cubit<ConversationState> {
  final ChatRepository _repository;
  StreamSubscription? _subscription;

  // Non-state metadata used across method calls.
  StreamSubscription? _conversationSubscription;
  String? _activeConversationId;
  String? _currentUserId;
  String? _currentUserName;

  /// The ID of the conversation currently loaded, or null when no conversation
  /// is open. Used by the FCM foreground handler in main.dart to suppress
  /// push notifications for the active conversation.
  String? get activeConversationId => _activeConversationId;

  ConversationCubit({required ChatRepository chatRepository})
      : _repository = chatRepository,
        super(const ConversationState());

  /// Loads (or reloads) a conversation. Cancels any previous streams, resets
  /// state, and immediately marks the conversation as read for [currentUserId].
  void loadConversation(
    String conversationId,
    String currentUserId,
    String currentUserName,
  ) {
    _subscription?.cancel();
    _conversationSubscription?.cancel();
    _activeConversationId = conversationId;
    _currentUserId = currentUserId;
    _currentUserName = currentUserName;

    emit(ConversationState(conversationId: conversationId, isLoading: true));

    // Mark read immediately; best-effort (error is swallowed).
    _repository.markAsRead(conversationId, currentUserId).catchError((_) {});

    // Stream the conversation document for AppBar title, participants, etc.
    // Also resets unreadCounts whenever the CF increments it while the user
    // is inside the conversation — this closes the race where markAsRead()
    // (called from _onMessagesReceived) runs before the CF's increment,
    // leaving the badge at 1 after the user exits.
    _conversationSubscription =
        _repository.streamConversation(conversationId).listen(
      (conv) {
        if (conv == null) return;
        emit(state.copyWith(conversation: conv));
        if (conv.unreadCountFor(currentUserId) > 0) {
          _repository
              .markAsRead(conversationId, currentUserId)
              .catchError((_) {});
        }
      },
      onError: (_) {},
    );

    _subscription = _repository.streamMessages(conversationId).listen(
      (streamed) => _onMessagesReceived(streamed, conversationId, currentUserId),
      onError: (_) => emit(state.copyWith(isLoading: false)),
    );
  }

  /// Merges a new stream result with any older messages already loaded via
  /// pagination. Stream always returns the newest ≤50; preserved messages
  /// are those the stream no longer covers (older than the stream window).
  void _onMessagesReceived(
    List<MessageModel> streamed,
    String conversationId,
    String uid,
  ) {
    final isInitialLoad = state.messages.isEmpty;
    final streamedIds = {for (final m in streamed) m.id};

    // Keep messages loaded via pagination that are older than the stream window.
    final preservedOlder =
        state.messages.where((m) => !streamedIds.contains(m.id)).toList();

    final merged = [...streamed, ...preservedOlder];

    emit(state.copyWith(
      messages: merged,
      isLoading: false,
      // Set hasMoreMessages only on initial load (stream size heuristic).
      // Subsequent stream emissions preserve the existing flag — pagination
      // is the only path that can set it to false.
      hasMoreMessages:
          isInitialLoad ? streamed.length >= 50 : state.hasMoreMessages,
    ));

    // Keep the user's unread count at 0 while they have the conversation open.
    _repository.markAsRead(conversationId, uid).catchError((_) {});
  }

  Future<void> sendMessage(String text) async {
    final cid = _activeConversationId;
    final uid = _currentUserId;
    final name = _currentUserName;
    if (cid == null || uid == null || name == null || text.trim().isEmpty) return;

    emit(state.copyWith(isSending: true, clearSendError: true));
    try {
      await _repository.sendMessage(
        conversationId: cid,
        senderId: uid,
        senderName: name,
        text: text.trim(),
      );
      emit(state.copyWith(isSending: false));
    } catch (_) {
      emit(state.copyWith(isSending: false, sendError: 'send_failed'));
    }
  }

  /// Loads the next page of older messages using the oldest currently-loaded
  /// message as the cursor. A separate snapshot fetch is needed because the
  /// stream pipeline discards the raw [DocumentSnapshot] objects.
  Future<void> loadOlderMessages() async {
    final cid = _activeConversationId;
    if (cid == null || state.isLoadingOlder || !state.hasMoreMessages) return;

    final oldestId =
        state.messages.isNotEmpty ? state.messages.last.id : null;
    if (oldestId == null) return;

    emit(state.copyWith(isLoadingOlder: true));
    try {
      final cursorDoc = await _repository.getMessageSnapshot(cid, oldestId);
      if (cursorDoc == null) {
        emit(state.copyWith(isLoadingOlder: false, hasMoreMessages: false));
        return;
      }
      final older = await _repository.loadOlderMessages(cid, cursorDoc);
      emit(state.copyWith(
        messages: [...state.messages, ...older],
        isLoadingOlder: false,
        hasMoreMessages: older.length >= 50,
      ));
    } catch (_) {
      emit(state.copyWith(isLoadingOlder: false));
    }
  }

  /// Soft-deletes [messageId]. The Firestore rule enforces sender-only.
  Future<void> deleteMessage(String messageId) async {
    final cid = _activeConversationId;
    final uid = _currentUserId;
    if (cid == null || uid == null) return;
    // Error is swallowed; the stream will update the message state if successful.
    await _repository
        .softDeleteMessage(cid, messageId, uid)
        .catchError((_) {});
  }

  void clearSendError() => emit(state.copyWith(clearSendError: true));

  /// Called when the ConversationScreen is disposed to cancel streams and
  /// reset active conversation tracking. Without this, the global cubit
  /// keeps the message stream alive after the user navigates away, causing
  /// markAsRead() to fire on new messages (which resets the unread badge to
  /// zero) and the FCM suppression to stay active for the wrong conversation.
  void clearActiveConversation() {
    _subscription?.cancel();
    _subscription = null;
    _conversationSubscription?.cancel();
    _conversationSubscription = null;
    _activeConversationId = null;
    _currentUserId = null;
    _currentUserName = null;
    if (!isClosed) emit(const ConversationState());
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    _conversationSubscription?.cancel();
    return super.close();
  }
}
