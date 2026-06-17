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

class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key});

  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final Set<String> _selectedUids = {};
  bool _isCreating = false;
  bool _isBroadcast = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<EmployeesCubit>().fetchEmployees(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _selectAll(List<dynamic> others) {
    setState(() {
      for (final emp in others) {
        _selectedUids.add(emp.id as String);
      }
    });
  }

  Future<void> _create() async {
    if (_isCreating) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('no_members_selected'.tr())),
      );
      return;
    }

    setState(() => _isCreating = true);

    final authUser = context.read<AuthCubit>().state.user;
    if (authUser == null) {
      setState(() => _isCreating = false);
      return;
    }

    final empState = context.read<EmployeesCubit>().state;
    final memberNames = <String, String>{};
    for (final uid in _selectedUids) {
      final emp = empState.employees.firstWhere(
        (e) => e.id == uid,
        orElse: () => empState.employees.first,
      );
      memberNames[uid] = emp.name;
    }

    final chatCubit = context.read<ChatListCubit>();
    final isBroadcast = _isBroadcast;

    try {
      final convId = await chatCubit.createGroup(
        name: _nameController.text.trim(),
        creatorUid: authUser.id,
        creatorName: authUser.name,
        memberUids: _selectedUids.toList(),
        memberNames: memberNames,
        writeRestriction: isBroadcast ? 'admin_only' : null,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        RouteNames.conversation,
        arguments: convId,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('create_group_error'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = context.read<AuthCubit>().state.user?.id ?? '';
    final isAdmin =
        context.read<AuthCubit>().state.user?.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isBroadcast ? 'broadcast_channel'.tr() : 'create_group'.tr(),
        ),
        actions: [
          _isCreating
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSizes.md),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _create,
                  child: Text('create'.tr()),
                ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group/channel name field
            Padding(
              padding: const EdgeInsets.all(AppSizes.md),
              child: TextFormField(
                controller: _nameController,
                maxLength: 50,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'group_name_label'.tr(),
                  hintText: 'group_name_hint'.tr(),
                  border: const OutlineInputBorder(),
                  counterText: '',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'group_name_required'.tr();
                  }
                  return null;
                },
              ),
            ),

            // Broadcast toggle (admin-only)
            if (isAdmin)
              SwitchListTile(
                value: _isBroadcast,
                onChanged: (v) => setState(() => _isBroadcast = v),
                title: Text('broadcast_channel'.tr()),
                subtitle: Text('broadcast_channel_hint'.tr()),
                secondary: Icon(
                  _isBroadcast
                      ? Icons.campaign
                      : Icons.campaign_outlined,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.md,
                ),
              ),

            // Members header + select-all
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSizes.md, AppSizes.xs, AppSizes.md, AppSizes.xs),
              child: BlocBuilder<EmployeesCubit, EmployeesState>(
                builder: (context, empState) {
                  final others = empState.employees
                      .where((e) => e.id != currentUserId && e.isActive)
                      .toList();
                  return Row(
                    children: [
                      Text(
                        'add_members'.tr(),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (others.isNotEmpty)
                        TextButton(
                          onPressed: () => _selectAll(others),
                          child: Text('select_all'.tr()),
                        ),
                    ],
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // Member multi-select list
            Expanded(
              child: BlocBuilder<EmployeesCubit, EmployeesState>(
                builder: (context, empState) {
                  final others = empState.employees
                      .where((e) => e.id != currentUserId && e.isActive)
                      .toList();

                  if (empState.status == EmployeesStatus.loading &&
                      others.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (others.isEmpty) {
                    return Center(
                      child: Text(
                        'no_users_available'.tr(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: others.length,
                    itemBuilder: (_, i) {
                      final employee = others[i];
                      final selected = _selectedUids.contains(employee.id);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (_) => setState(() {
                          if (selected) {
                            _selectedUids.remove(employee.id);
                          } else {
                            _selectedUids.add(employee.id);
                          }
                        }),
                        secondary: UserAvatarWidget(
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
                        controlAffinity: ListTileControlAffinity.trailing,
                      );
                    },
                  );
                },
              ),
            ),

            // Selected count indicator
            if (_selectedUids.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md, vertical: AppSizes.sm),
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                child: Text(
                  'members_count'.tr(namedArgs: {
                    'count': _selectedUids.length.toString(),
                  }),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
