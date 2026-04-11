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
      appBar: AppBar(title: Text('notifications'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: BlocBuilder<NotificationsCubit, NotificationsState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.notifications.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.notifications_none_outlined,
                titleKey: 'no_notifications_found',
              );
            }

            return ListView.separated(
              itemCount: state.notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSizes.md),
              itemBuilder: (context, index) {
                final notification = state.notifications[index];

                return AppCard(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      if (user == null) return;

                      if (!notification.isRead) {
                        await context.read<NotificationsCubit>().markAsRead(
                          notification.id,
                          user.id,
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
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
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
                                  DateFormat(
                                    'yyyy-MM-dd • HH:mm',
                                  ).format(notification.createdAt!),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
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
              },
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
