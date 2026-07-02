import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../data/models/debt_model.dart';
import '../../data/models/handover_model.dart';
import '../cubit/customers_state.dart';
import '../cubit/handover_cubit.dart';
import '../cubit/handover_state.dart';

class HandoverListScreen extends StatefulWidget {
  const HandoverListScreen({super.key});

  @override
  State<HandoverListScreen> createState() => _HandoverListScreenState();
}

class _HandoverListScreenState extends State<HandoverListScreen> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<AuthCubit>().state.user;
    if (user == null) return;
    if (user.role == 'admin') {
      await context.read<HandoverCubit>().loadAllHandovers();
    } else {
      await context.read<HandoverCubit>().loadCollectorHandovers(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('handovers'.tr())),
      body: BlocBuilder<HandoverCubit, HandoverState>(
        builder: (context, state) {
          if (state.status == CollectionsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == CollectionsStatus.error) {
            return RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  EmptyStateWidget(
                    icon: Icons.error_outline,
                    titleKey: state.error ?? 'unknown_error',
                  ),
                ],
              ),
            );
          }
          if (state.handovers.isEmpty) {
            return RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  EmptyStateWidget(
                    icon: Icons.swap_horiz_outlined,
                    titleKey: 'no_handovers_found',
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSizes.md),
              itemCount: state.handovers.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSizes.sm),
              itemBuilder: (context, index) {
                final h = state.handovers[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pushNamed(
                    context,
                    RouteNames.handoverVerification,
                    arguments: h,
                  ).then((_) => _load()),
                  child: AppCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                h.collectorName,
                                style:
                                    Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DebtModel.formatAmountIls(h.claimedAmount),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('dd/MM/yyyy')
                                    .format(h.initiatedAt),
                                style:
                                    Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        _HandoverStatusBadge(handover: h),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _HandoverStatusBadge extends StatelessWidget {
  final HandoverModel handover;

  const _HandoverStatusBadge({required this.handover});

  @override
  Widget build(BuildContext context) {
    Color color;
    String key;

    if (handover.isPending) {
      color = Theme.of(context).colorScheme.primary;
      key = 'handover_status_pending';
    } else if (handover.isVerified) {
      color = Colors.teal;
      key = 'handover_status_verified';
    } else {
      color = Colors.orange;
      key = 'handover_discrepancy';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        key.tr(),
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
