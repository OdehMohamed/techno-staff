import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../data/models/task_template_model.dart';
import '../cubit/templates_cubit.dart';
import '../cubit/templates_state.dart';

class RecurringTasksScreen extends StatefulWidget {
  const RecurringTasksScreen({super.key});

  @override
  State<RecurringTasksScreen> createState() => _RecurringTasksScreenState();
}

class _RecurringTasksScreenState extends State<RecurringTasksScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TemplatesCubit>().fetchAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthCubit>().state.user;
    if (user?.role != 'admin') {
      return Scaffold(
        appBar: AppBar(title: Text('recurring_tasks'.tr())),
        body: Center(child: Text('not_authorized'.tr())),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('recurring_tasks'.tr())),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            Navigator.pushNamed(context, RouteNames.addTemplate).then((_) {
              if (context.mounted) {
                context.read<TemplatesCubit>().fetchAll();
              }
            }),
        icon: const Icon(Icons.add),
        label: Text('add_template'.tr()),
      ),
      body: BlocBuilder<TemplatesCubit, TemplatesState>(
        builder: (context, state) {
          if (state.status == TemplatesStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == TemplatesStatus.error) {
            return Center(child: Text(state.errorMessage ?? 'error'.tr()));
          }
          if (state.templates.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.repeat,
              titleKey: 'no_templates_found',
            );
          }
          return RefreshIndicator(
            onRefresh: () => context.read<TemplatesCubit>().fetchAll(),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSizes.md),
              itemCount: state.templates.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSizes.sm),
              itemBuilder: (_, index) {
                final template = state.templates[index];
                return _TemplateListItem(
                  template: template,
                  onEdit: () {
                    Navigator.pushNamed(
                      context,
                      RouteNames.editTemplate,
                      arguments: template,
                    ).then((_) {
                      if (context.mounted) {
                        context.read<TemplatesCubit>().fetchAll();
                      }
                    });
                  },
                  onToggleActive: () {
                    context.read<TemplatesCubit>().toggleActive(
                      template.id,
                      !template.isActive,
                    );
                  },
                  onDelete: () => _confirmDelete(context, template),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, TaskTemplateModel template) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('delete_template_confirm_title'.tr()),
        content: Text(
          'delete_template_confirm_message'.tr(
            namedArgs: {'name': template.title},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<TemplatesCubit>().deleteTemplate(template.id);
            },
            child: Text(
              'delete'.tr(),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateListItem extends StatelessWidget {
  final TaskTemplateModel template;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const _TemplateListItem({
    required this.template,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  String _recurrenceSummary(BuildContext context) {
    final r = template.recurrence;
    if (r.type == 'daily') return 'recurrence_daily'.tr();
    if (r.type == 'monthly') {
      return '${'recurrence_monthly'.tr()} · ${r.dayOfMonth}';
    }
    if (r.type == 'weekly' && r.daysOfWeek != null) {
      const dayKeys = {
        1: 'weekday_mon',
        2: 'weekday_tue',
        3: 'weekday_wed',
        4: 'weekday_thu',
        5: 'weekday_fri',
        6: 'weekday_sat',
        7: 'weekday_sun',
      };
      final sorted = List<int>.from(r.daysOfWeek!)..sort();
      final labels = sorted.map((d) => (dayKeys[d] ?? '$d').tr()).join(', ');
      return '${'recurrence_weekly'.tr()} · $labels';
    }
    return r.type;
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          template.title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(template.assignedToNames.join(', ')),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text(
                    _recurrenceSummary(context),
                    style: const TextStyle(fontSize: 12),
                  ),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    template.isActive
                        ? 'template_active'.tr()
                        : 'template_paused'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      color: template.isActive ? Colors.green : Colors.orange,
                    ),
                  ),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'toggle') onToggleActive();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: Text('edit'.tr())),
            PopupMenuItem(
              value: 'toggle',
              child: Text(template.isActive ? 'pause'.tr() : 'resume'.tr()),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text(
                'delete'.tr(),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
