import '../../data/models/message_model.dart';

class ConversationState {
  final String? conversationId;
  final List<MessageModel> messages;
  final bool isLoading;
  final bool isLoadingOlder;
  final bool hasMoreMessages;
  final bool isSending;
  final String? sendError;

  const ConversationState({
    this.conversationId,
    this.messages = const [],
    this.isLoading = false,
    this.isLoadingOlder = false,
    this.hasMoreMessages = false,
    this.isSending = false,
    this.sendError,
  });

  ConversationState copyWith({
    String? conversationId,
    List<MessageModel>? messages,
    bool? isLoading,
    bool? isLoadingOlder,
    bool? hasMoreMessages,
    bool? isSending,
    String? sendError,
    bool clearSendError = false,
  }) {
    return ConversationState(
      conversationId: conversationId ?? this.conversationId,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      isSending: isSending ?? this.isSending,
      sendError: clearSendError ? null : (sendError ?? this.sendError),
    );
  }
}
