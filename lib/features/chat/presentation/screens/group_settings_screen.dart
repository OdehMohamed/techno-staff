import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../employees/presentation/cubit/employees_cubit.dart';
import '../../../employees/presentation/cubit/employees_state.dart';
import '../cubit/chat_list_cubit.dart';
import '../cubit/conversation_cubit.dart';
import '../cubit/conversation_state.dart';

class GroupSettingsScreen extends StatefulWidget {
  const GroupSettingsScreen({super.key});

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  bool _isUpdating = false;

  Future<void> _addMember(String uid, String name) async {
    final auth = context.read<AuthCubit>().state.user;
    if (auth == null) return;
    final conv = context.read<ConversationCubit>().state.conversation;
    if (conv == null) return;

    setState(() => _isUpdating = true);
    try {
      await context.read<ChatListCubit>().addGroupMember(
        conversationId: conv.id,
        actorUid: auth.id,
        actorName: auth.name,
        newMemberUid: uid,
        newMemberName: name,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('member_add_failed'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _removeMember(String uid, String name) async {
    final auth = context.read<AuthCubit>().state.user;
    if (auth == null) return;
    final conv = context.read<ConversationCubit>().state.conversation;
    if (conv == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('remove_member'.tr()),
        content: Text(
          'remove_from_group_confirm'.tr(namedArgs: {'name': name}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isUpdating = true);
    try {
      await context.read<ChatListCubit>().removeGroupMember(
        conversationId: conv.id,
        actorUid: auth.id,
        actorName: auth.name,
        memberUid: uid,
        memberName: name,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('member_remove_failed'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showAddMembersSheet(List<String> existingIds) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BlocProvider.value(
        value: context.read<EmployeesCubit>(),
        child: _AddMembersSheet(
          existingParticipantIds: existingIds,
          onAdd: (uid, name) async {
            Navigator.pop(context);
            await _addMember(uid, name);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('group_settings'.tr())),
      body: BlocBuilder<ConversationCubit, ConversationState>(
        builder: (context, convState) {
          final conv = convState.conversation;
          if (conv == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final auth = context.read<AuthCubit>().state.user;
          final currentUid = auth?.id ?? '';
          final isAdmin = auth?.role == 'admin';
          final canManage = isAdmin || conv.createdBy == currentUid;

          final members = conv.participantIds
              .map((uid) => (uid: uid, name: conv.participantNames[uid] ?? uid))
              .toList();

          return Stack(
            children: [
              ListView.separated(
                padding:
                    const EdgeInsets.symmetric(vertical: AppSizes.sm),
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemCount: members.length + (canManage ? 1 : 0),
                itemBuilder: (context, index) {
                  if (canManage && index == 0) {
                    return ListTile(
                      leading: const Icon(Icons.person_add_outlined),
                      title: Text('add_members'.tr()),
                      onTap: _isUpdating
                          ? null
                          : () => _showAddMembersSheet(conv.participantIds),
                    );
                  }

                  final memberIndex = canManage ? index - 1 : index;
                  final member = members[memberIndex];
                  final isSelf = member.uid == currentUid;

                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        member.name.isNotEmpty
                            ? member.name[0].toUpperCase()
                            : '?',
                      ),
                    ),
                    title: Text(member.name),
                    trailing: canManage && !isSelf
                        ? IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.red,
                            ),
                            tooltip: 'remove_member'.tr(),
                            onPressed: _isUpdating
                                ? null
                                : () => _removeMember(member.uid, member.name),
                          )
                        : null,
                  );
                },
              ),
              if (_isUpdating)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x44000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Add members sheet ─────────────────────────────────────────────────────────

class _AddMembersSheet extends StatefulWidget {
  final List<String> existingParticipantIds;
  final Future<void> Function(String uid, String name) onAdd;

  const _AddMembersSheet({
    required this.existingParticipantIds,
    required this.onAdd,
  });

  @override
  State<_AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends State<_AddMembersSheet> {
  @override
  void initState() {
    super.initState();
    context.read<EmployeesCubit>().fetchEmployees(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: AppSizes.sm),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'add_members'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Expanded(
              child: BlocBuilder<EmployeesCubit, EmployeesState>(
                builder: (context, state) {
                  final candidates = state.employees
                      .where((u) =>
                          u.isActive &&
                          !widget.existingParticipantIds.contains(u.id))
                      .toList();

                  if (candidates.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSizes.md),
                        child: Text(
                          'no_users_to_add'.tr(),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: candidates.length,
                    itemBuilder: (context, index) {
                      final user = candidates[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : '?',
                          ),
                        ),
                        title: Text(user.name),
                        onTap: () => widget.onAdd(user.id, user.name),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
