import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../../../features/employees/presentation/cubit/employees_cubit.dart';
import '../../../../features/employees/presentation/cubit/employees_state.dart';
import '../../../../shared/widgets/user_avatar_widget.dart';
import '../cubit/chat_list_cubit.dart';

class NewConversationSheet extends StatefulWidget {
  const NewConversationSheet({super.key});

  @override
  State<NewConversationSheet> createState() => _NewConversationSheetState();
}

class _NewConversationSheetState extends State<NewConversationSheet> {
  /// UID of the employee currently being loaded (prevents double-tap).
  String? _loadingUid;

  @override
  void initState() {
    super.initState();
    // Ensure the employee list is populated regardless of role.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<EmployeesCubit>().fetchEmployees(silent: true);
      }
    });
  }

  Future<void> _startDm(String targetUid, String targetName) async {
    if (_loadingUid != null) return;
    setState(() => _loadingUid = targetUid);

    final authUser = context.read<AuthCubit>().state.user;
    if (authUser == null) {
      setState(() => _loadingUid = null);
      return;
    }

    try {
      final convId = await context.read<ChatListCubit>().getOrCreateDm(
            authUser.id,
            targetUid,
            authUser.name,
            targetName,
          );
      if (!mounted) return;
      Navigator.of(context).pop(convId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingUid = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('send_failed'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = context.read<AuthCubit>().state.user?.id ?? '';

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.md, 4, AppSizes.md, AppSizes.sm),
            child: Text(
              'new_conversation'.tr(),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),

          const Divider(height: 1),

          // Create group option
          ListTile(
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Icon(
                Icons.group_add_outlined,
                size: 20,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            title: Text('create_group'.tr()),
            subtitle: Text(
              'create_group_hint'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed(RouteNames.newGroup);
            },
          ),

          const Divider(height: 1),

          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.md, AppSizes.sm, AppSizes.md, 4),
            child: Text(
              'direct_message'.tr(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Direct message entry point
          BlocBuilder<EmployeesCubit, EmployeesState>(
            builder: (context, empState) {
              final others = empState.employees
                  .where((e) => e.id != currentUserId && e.isActive)
                  .toList();

              if (empState.status == EmployeesStatus.loading && others.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (others.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'no_users_available'.tr(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }

              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: others.length,
                  itemBuilder: (_, i) {
                    final employee = others[i];
                    final isLoading = _loadingUid == employee.id;

                    return ListTile(
                      leading: UserAvatarWidget(
                        name: employee.name,
                        uid: employee.id,
                        radius: 20,
                      ),
                      title: Text(employee.name),
                      subtitle: Text(
                        employee.role == 'admin'
                            ? 'admin'.tr()
                            : 'employee'.tr(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      enabled: _loadingUid == null,
                      onTap: () => _startDm(employee.id, employee.name),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
