import '../../data/models/conversation_model.dart';

class ChatListState {
  final List<ConversationModel> conversations;
  final int totalUnread;
  final bool isLoading;

  const ChatListState({
    this.conversations = const [],
    this.totalUnread = 0,
    this.isLoading = false,
  });

  ChatListState copyWith({
    List<ConversationModel>? conversations,
    int? totalUnread,
    bool? isLoading,
  }) {
    return ChatListState(
      conversations: conversations ?? this.conversations,
      totalUnread: totalUnread ?? this.totalUnread,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
