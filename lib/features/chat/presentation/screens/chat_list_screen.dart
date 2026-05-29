import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../data/models/conversation_model.dart';
import '../cubit/chat_list_cubit.dart';
import '../cubit/chat_list_state.dart';
import '../widgets/conversation_tile.dart';
import '../widgets/new_conversation_sheet.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Filter ───────────────────────────────────────────────────────────────

  List<ConversationModel> _filtered(
    List<ConversationModel> all,
    String currentUserId,
  ) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all.where((c) {
      if (c.name != null && c.name!.toLowerCase().contains(q)) return true;
      return c.participantNames.values
          .any((name) => name.toLowerCase().contains(q));
    }).toList();
  }

  // ─── New conversation sheet ───────────────────────────────────────────────

  Future<void> _openNewConversationSheet() async {
    final convId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const NewConversationSheet(),
    );
    if (convId != null && mounted) {
      Navigator.pushNamed(context, RouteNames.conversation, arguments: convId);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        context.read<AuthCubit>().state.user?.id ?? '';

    return Scaffold(
      appBar: AppBar(title: Text('messages'.tr())),
      body: BlocBuilder<ChatListCubit, ChatListState>(
        builder: (context, state) {
          // ── Initial / loading ──
          if (state.isLoading && state.conversations.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final filtered = _filtered(state.conversations, currentUserId);

          // ── Empty state (no conversations at all) ──
          if (state.conversations.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.chat_bubble_outline,
              titleKey: 'no_conversations_yet',
              subtitleKey: 'start_a_conversation_hint',
            );
          }

          // ── List ──
          return Column(
            children: [
              // Search bar — shown once there is at least one conversation
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSizes.md, AppSizes.sm, AppSizes.md, 0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'search_conversations'.tr(),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.sm),

              // Conversation list or search-empty state
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'no_conversations_yet'.tr(),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          // ChatListCubit streams in real time; pull-to-refresh
                          // is a no-op but satisfies the drag gesture expectation.
                        },
                        child: ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            indent: 68,
                            endIndent: 16,
                          ),
                          itemBuilder: (_, i) {
                            final conv = filtered[i];
                            return ConversationTile(
                              conversation: conv,
                              currentUserId: currentUserId,
                              onTap: () => Navigator.pushNamed(
                                context,
                                RouteNames.conversation,
                                arguments: conv.id,
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewConversationSheet,
        tooltip: 'new_conversation'.tr(),
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }
}
