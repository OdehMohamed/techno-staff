import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:linkify/linkify.dart' show PhoneNumberLinkifier;
import 'package:url_launcher/url_launcher.dart';
import 'package:techno_staff/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:techno_staff/features/chat/presentation/cubit/chat_list_cubit.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/priority_badge.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../cubit/task_attachments_cubit.dart';
import '../cubit/task_attachments_state.dart';
import '../cubit/task_logs_cubit.dart';
import '../cubit/task_logs_state.dart';
import '../cubit/tasks_cubit.dart';
import '../cubit/tasks_state.dart';
import '../../data/models/task_model.dart';
import '../widgets/countdown_chip.dart';
import '../widgets/countdown_clock_provider.dart';
import '../widgets/task_attachments_section.dart';

class TaskDetailsScreen extends StatefulWidget {
  final TaskModel task;

  const TaskDetailsScreen({super.key, required this.task});

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  bool _openingThread = false;
  late final TaskAttachmentsCubit _attachmentsCubit;
  StreamSubscription<TaskAttachmentsState>? _attachmentsSub;
  String? _lastSeenAttachmentError;

  @override
  void initState() {
    super.initState();
    _attachmentsCubit = context.read<TaskAttachmentsCubit>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TaskLogsCubit>().fetchTaskLogs(widget.task.id);
      _attachmentsCubit.loadAttachments(widget.task.id);
      _attachmentsSub = _attachmentsCubit.stream.listen((state) {
        if (state.error != null &&
            state.error != _lastSeenAttachmentError &&
            mounted) {
          _lastSeenAttachmentError = state.error;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!.tr())),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _attachmentsSub?.cancel();
    _attachmentsCubit.clear();
    super.dispose();
  }

  Future<void> _openTaskThread(TaskModel task) async {
    if (_openingThread) return;
    final auth = context.read<AuthCubit>().state.user;
    if (auth == null) return;
    final chatCubit = context.read<ChatListCubit>();
    setState(() => _openingThread = true);
    try {
      final convId = await chatCubit.getOrCreateTaskThread(
        taskId: task.id,
        taskTitle: task.title,
        initiatorUid: auth.id,
        initiatorName: auth.name,
        creatorUid: task.assignedBy,
        creatorName: task.assignedByName,
        assigneeUid: task.assignedTo,
        assigneeName: task.assignedToName,
      );
      if (!mounted) return;
      await Navigator.pushNamed(context, RouteNames.conversation,
          arguments: convId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('task_discussion_error'.tr())),
      );
    } finally {
      if (mounted) setState(() => _openingThread = false);
    }
  }

  TaskModel _findTask(TasksState state) {
    for (final list in [
      state.tasks,
      state.tasksAssignedToMe,
      state.tasksCreatedByMe,
    ]) {
      for (final candidate in list) {
        if (candidate.id == widget.task.id) return candidate;
      }
    }
    return widget.task;
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to TasksCubit so increment / edit emissions update this
    // screen in place. Falls back to the constructor argument when the task
    // isn't in any of the cubit's lists (e.g. first frame before any fetch).
    final task = context.select<TasksCubit, TaskModel>(
      (cubit) => _findTask(cubit.state),
    );
    final currentUser = context.read<AuthCubit>().state.user;

    final canEditOrDelete =
        currentUser != null &&
        (currentUser.role == 'admin' || task.assignedBy == currentUser.id);

    final canDiscuss = currentUser != null &&
        (currentUser.id == task.assignedBy ||
            currentUser.id == task.assignedTo);

    final canUploadEvidence = currentUser != null &&
        (currentUser.role == 'admin' || task.assignedTo == currentUser.id);

    return Scaffold(
      appBar: AppBar(
        title: Text('task_details'.tr()),
        actions: [
          if (canDiscuss)
            _openingThread
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.chat_bubble_outline),
                    tooltip: 'task_discussion'.tr(),
                    onPressed: () => _openTaskThread(task),
                  ),
          if (canEditOrDelete)
            IconButton(
              onPressed: () async {
                final result = await Navigator.pushNamed(
                  context,
                  RouteNames.editTask,
                  arguments: task,
                );

                if (context.mounted && result == true) {
                  Navigator.pop(context, true);
                }
              },
              icon: const Icon(Icons.edit_outlined),
            ),
          if (canEditOrDelete)
            IconButton(
              onPressed: () async {
                final shouldDelete = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) {
                    return AlertDialog(
                      title: Text('delete_task_confirm_title'.tr()),
                      content: Text(
                        'delete_task_confirm_message'.tr(args: [task.title]),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(dialogContext, false);
                          },
                          child: Text('cancel'.tr()),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(
                              dialogContext,
                            ).colorScheme.error,
                          ),
                          onPressed: () {
                            Navigator.pop(dialogContext, true);
                          },
                          child: Text('delete'.tr()),
                        ),
                      ],
                    );
                  },
                );

                if (!context.mounted) return;
                if (shouldDelete != true) return;

                try {
                  await context.read<TasksCubit>().deleteTask(
                    taskId: task.id,
                    isAdmin: currentUser.role == 'admin',
                    currentUserId: currentUser.id,
                  );

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('task_deleted'.tr())));
                  Navigator.pop(context, true);
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('failed_to_delete_task'.tr())),
                  );
                }
              },
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: CountdownClockProvider(
        dueDates: [task.dueDate],
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: AppSizes.sm),
                          SelectableLinkify(
                            text: task.description,
                            style: Theme.of(context).textTheme.bodyLarge,
                            // No linkStyle override — flutter_linkify's default
                            // (blueAccent + underline) is already correct.
                            // Overriding color with colorScheme.primary was
                            // making links visually indistinguishable from text.
                            linkifiers: const [
                              UrlLinkifier(),
                              EmailLinkifier(),
                              PhoneNumberLinkifier(),
                            ],
                            contextMenuBuilder: (context, editableTextState) =>
                                AdaptiveTextSelectionToolbar.editableText(
                              editableTextState: editableTextState,
                            ),
                            onOpen: (link) async {
                              final uri = Uri.parse(link.url);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                          ),
                          const SizedBox(height: AppSizes.lg),
                          Wrap(
                            spacing: AppSizes.sm,
                            runSpacing: AppSizes.sm,
                            children: [
                              StatusBadge(status: task.status),
                              PriorityBadge(priority: task.priority),
                              if (task.isCounter) const _CounterTypeBadge(),
                            ],
                          ),
                          if (task.isCounter) ...[
                            const SizedBox(height: AppSizes.lg),
                            Text(
                              'progress'.tr(),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSizes.sm),
                            _CounterProgressRow(
                              task: task,
                              onIncrement:
                                  (currentUser != null &&
                                      task.assignedTo == currentUser.id &&
                                      task.currentCount <
                                          (task.targetCount ?? 0))
                                  ? () {
                                      context
                                          .read<TasksCubit>()
                                          .incrementTaskCounter(
                                            taskId: task.id,
                                            isAdmin:
                                                currentUser.role == 'admin',
                                            currentUserId: currentUser.id,
                                            currentUserName: currentUser.name,
                                          );
                                    }
                                  : null,
                            ),
                            const SizedBox(height: AppSizes.lg),
                          ],
                          const SizedBox(height: AppSizes.xl),
                          _DetailsRow(
                            label: 'assigned_to'.tr(),
                            value: task.assignedToName,
                          ),
                          const SizedBox(height: AppSizes.sm),
                          _DetailsRow(
                            label: 'assigned_by'.tr(),
                            value: task.assignedByName,
                          ),
                          const SizedBox(height: AppSizes.sm),
                          Wrap(
                            spacing: AppSizes.sm,
                            runSpacing: AppSizes.sm,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '${'due_date'.tr()}: ${task.hasDueTime ? DateFormat.yMMMd(context.locale.languageCode).add_Hm().format(task.dueDate) : DateFormat.yMMMd(context.locale.languageCode).format(task.dueDate)}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              CountdownChip(
                                dueDate: task.dueDate,
                                hasDueTime: task.hasDueTime,
                                isCompleted: task.status == 'completed',
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSizes.sm),
                          _DetailsRow(
                            label: 'created_at'.tr(),
                            value: DateFormat(
                              'dd MMM yyyy • HH:mm',
                            ).format(task.createdAt),
                          ),
                          if (task.updatedAt != null) ...[
                            const SizedBox(height: AppSizes.sm),
                            _DetailsRow(
                              label: 'updated_at'.tr(),
                              value: DateFormat(
                                'dd MMM yyyy • HH:mm',
                              ).format(task.updatedAt!),
                            ),
                          ],
                          if (task.completedAt != null) ...[
                            const SizedBox(height: AppSizes.sm),
                            _DetailsRow(
                              label: 'completed_at'.tr(),
                              value: DateFormat(
                                'dd MMM yyyy • HH:mm',
                              ).format(task.completedAt!),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSizes.xl),
                    TaskAttachmentsSection(
                      taskId: task.id,
                      type: 'brief',
                      canUpload: canEditOrDelete,
                      canDeleteAny: canEditOrDelete,
                      uploadedBy: currentUser?.id ?? '',
                      uploadedByName: currentUser?.name ?? '',
                    ),
                    const SizedBox(height: AppSizes.xl),
                    TaskAttachmentsSection(
                      taskId: task.id,
                      type: 'evidence',
                      canUpload: canUploadEvidence,
                      canDeleteAny: canEditOrDelete,
                      uploadedBy: currentUser?.id ?? '',
                      uploadedByName: currentUser?.name ?? '',
                    ),
                    const SizedBox(height: AppSizes.xl),
                    SectionHeader(
                      title: 'activity_log'.tr(),
                      subtitle: 'activity_log_subtitle'.tr(),
                    ),
                    BlocBuilder<TaskLogsCubit, TaskLogsState>(
                      builder: (context, state) {
                        if (state.status == TaskLogsStatus.loading) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(AppSizes.lg),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        if (state.status == TaskLogsStatus.error) {
                          return const EmptyStateWidget(
                            icon: Icons.history_toggle_off,
                            titleKey: 'failed_to_load_task_logs',
                          );
                        }

                        if (state.logs.isEmpty) {
                          return const EmptyStateWidget(
                            icon: Icons.history,
                            titleKey: 'no_activity_logs_found',
                          );
                        }

                        return Column(
                          children: state.logs.map((log) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSizes.md,
                              ),
                              child: AppCard(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(_logActionIcon(log.action)),
                                    ),
                                    const SizedBox(width: AppSizes.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _buildLogTitle(log.action).tr(),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: AppSizes.xs),
                                          Text(
                                            _buildLogDescription(
                                              performedByName:
                                                  log.performedByName,
                                              previousStatus:
                                                  log.previousStatus,
                                              newStatus: log.newStatus,
                                            ),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                          ),
                                          if (log.performedAt != null) ...[
                                            const SizedBox(height: AppSizes.xs),
                                            Text(
                                              DateFormat(
                                                'dd MMM yyyy • HH:mm',
                                              ).format(log.performedAt!),
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _buildLogTitle(String action) {
    switch (action) {
      case 'created':
        return 'task_created';
      case 'status_changed':
        return 'task_status_changed';
      default:
        return 'task_updated';
    }
  }

  String _buildLogDescription({
    required String performedByName,
    String? previousStatus,
    String? newStatus,
  }) {
    if (previousStatus != null && newStatus != null) {
      return '$performedByName • ${previousStatus.tr()} → ${newStatus.tr()}';
    }

    return performedByName;
  }

  IconData _logActionIcon(String action) {
    switch (action) {
      case 'created':
        return Icons.add_circle_outline;
      case 'status_changed':
        return Icons.swap_horiz;
      case 'overdue_escalation':
        return Icons.warning_amber_outlined;
      default:
        return Icons.history;
    }
  }
}

class _DetailsRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailsRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        Text('$label:', style: Theme.of(context).textTheme.titleMedium),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

class _CounterTypeBadge extends StatelessWidget {
  const _CounterTypeBadge();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.numbers, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            'task_type_counter'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CounterProgressRow extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onIncrement;

  const _CounterProgressRow({required this.task, required this.onIncrement});

  @override
  Widget build(BuildContext context) {
    final target = task.targetCount ?? 0;
    final current = task.currentCount.clamp(0, target);
    final ratio = target == 0 ? 0.0 : current / target;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${'progress'.tr()}: $current / $target',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton.filledTonal(
              onPressed: onIncrement,
              tooltip: 'increment'.tr(),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(value: ratio, minHeight: 8),
        ),
      ],
    );
  }
}
