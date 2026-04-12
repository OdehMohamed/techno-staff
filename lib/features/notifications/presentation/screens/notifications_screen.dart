import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:techno_staff/features/notifications/data/models/in_app_notification_model.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../cubit/notifications_cubit.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthCubit>().state.user;
      if (user != null) {
        context.read<NotificationsCubit>().loadNotifications(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthCubit>().state.user;

    return Scaffold(
      appBar: AppBar(
        title: Text('notifications'.tr()),
        actions: [
          TextButton(
            onPressed: () async {
              final user = context.read<AuthCubit>().state.user;
              if (user == null) return;

              await context.read<NotificationsCubit>().markAllAsRead(user.id);
            },
            child: Text('mark_all_as_read'.tr()),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: BlocBuilder<NotificationsCubit, NotificationsState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.notifications.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.notifications_active_outlined,
                titleKey: 'no_notifications_found',
                subtitleKey: 'no_notifications_subtitle',
              );
            }

            final groupedNotifications = _groupNotifications(
              state.notifications,
            );

            return RefreshIndicator(
              onRefresh: () async {
                final user = context.read<AuthCubit>().state.user;
                if (user != null) {
                  context.read<NotificationsCubit>().listenToNotifications(
                    user.id,
                  );
                }
              },
              child: ListView(
                children: groupedNotifications.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppSizes.sm,
                          top: AppSizes.md,
                        ),
                        child: Text(
                          entry.key,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      ...entry.value.map((notification) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSizes.md),
                          child: _buildNotificationItem(
                            context: context,
                            notification: notification,
                            userId: user?.id,
                          ),
                        );
                      }),
                    ],
                  );
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _buildNotificationIcon(String type) {
    switch (type) {
      case 'task_assigned':
        return Icons.assignment_ind_outlined;
      case 'task_completed':
        return Icons.check_circle_outline;
      case 'task_deadline_reminder':
        return Icons.schedule_outlined;
      case 'task_overdue_reminder':
      case 'task_overdue_escalation':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  Widget _buildNotificationItem({
    required BuildContext context,
    required InAppNotificationModel notification,
    required String? userId,
  }) {
    return AppCard(
      child: InkWell(
        splashColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          if (userId == null) return;

          if (!notification.isRead) {
            await context.read<NotificationsCubit>().markAsRead(
              notification.id,
              userId,
            );
          }

          if (context.mounted && notification.taskId != null) {
            Navigator.pushNamed(
              context,
              RouteNames.taskDetails,
              arguments: notification.taskId,
            );
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _buildNotificationIcon(notification.type),
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _buildNotificationTitle(notification),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    _buildNotificationBody(notification),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (notification.createdAt != null) ...[
                    const SizedBox(height: AppSizes.sm),
                    Text(
                      DateFormat.yMMMd(
                        context.locale.languageCode,
                      ).add_jm().format(notification.createdAt!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _buildNotificationTitle(InAppNotificationModel notification) {
  switch (notification.type) {
    case 'task_assigned':
      return 'new_task_assigned'.tr();
    case 'task_completed':
      return 'task_completed_notification'.tr();
    case 'task_deadline_reminder':
      return 'task_deadline_reminder_title'.tr();
    case 'task_overdue_reminder':
      return 'task_overdue_reminder_title'.tr();
    case 'task_overdue_escalation':
      return 'task_overdue_escalation_title'.tr();
    default:
      return 'notifications'.tr();
  }
}

String _buildNotificationBody(InAppNotificationModel notification) {
  final data = notification.data ?? {};

  switch (notification.type) {
    case 'task_assigned':
      return 'task_assigned_body'.tr(
        namedArgs: {
          'name': (data['assignedByName'] ?? '').toString(),
          'task': (data['taskTitle'] ?? '').toString(),
        },
      );
    case 'task_completed':
      return 'task_completed_body'.tr(
        namedArgs: {
          'name': (data['performedByName'] ?? '').toString(),
          'task': (data['taskTitle'] ?? '').toString(),
        },
      );
    case 'task_deadline_reminder':
      return 'task_deadline_reminder_body'.tr(
        namedArgs: {'task': (data['taskTitle'] ?? '').toString()},
      );
    case 'task_overdue_reminder':
      return 'task_overdue_reminder_body'.tr(
        namedArgs: {'task': (data['taskTitle'] ?? '').toString()},
      );
    case 'task_overdue_escalation':
      return 'task_overdue_escalation_body'.tr(
        namedArgs: {
          'employee': (data['assignedToName'] ?? '').toString(),
          'task': (data['taskTitle'] ?? '').toString(),
        },
      );
    default:
      return '';
  }
}

Map<String, List<InAppNotificationModel>> _groupNotifications(
  List<InAppNotificationModel> notifications,
) {
  final Map<String, List<InAppNotificationModel>> grouped = {};

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  for (final n in notifications) {
    if (n.createdAt == null) continue;

    final createdAt = n.createdAt!;
    final notificationDate = DateTime(
      createdAt.year,
      createdAt.month,
      createdAt.day,
    );

    String key;

    if (notificationDate == today) {
      key = 'today'.tr();
    } else if (notificationDate == yesterday) {
      key = 'yesterday'.tr();
    } else {
      key = 'earlier'.tr();
    }

    grouped.putIfAbsent(key, () => []).add(n);
  }

  return grouped;
}
