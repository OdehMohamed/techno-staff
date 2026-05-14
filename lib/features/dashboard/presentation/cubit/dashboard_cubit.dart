import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/dashboard_repository.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final DashboardRepository _dashboardRepository;
  List<Map<String, dynamic>> trends = [];

  DashboardCubit({required DashboardRepository dashboardRepository})
    : _dashboardRepository = dashboardRepository,
      super(const DashboardState());

  Future<void> loadAdminStats({bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(status: DashboardStatus.loading, clearError: true));
    }

    try {
      final stats = await _dashboardRepository.getAdminStats(
        filter: state.filter,
      );
      final topData = await _dashboardRepository.getTopPerformer();
      final activities = await _dashboardRepository.getRecentActivities();
      final trends = await _dashboardRepository.getTasksTrend();
      emit(
        state.copyWith(
          status: DashboardStatus.loaded,
          stats: stats,
          extraStats: topData,
          activities: activities,
          trends: trends,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: DashboardStatus.error,
          errorMessage: 'failed_to_load_dashboard',
        ),
      );
    }
  }

  Future<void> loadEmployeeStats(String userId, {bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(status: DashboardStatus.loading, clearError: true));
    }

    try {
      final stats = await _dashboardRepository.getEmployeeStats(userId);

      emit(
        state.copyWith(
          status: DashboardStatus.loaded,
          stats: stats,
          clearError: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: DashboardStatus.error,
          errorMessage: 'failed_to_load_dashboard',
        ),
      );
    }
  }

  Future<void> changeFilter(DashboardFilter filter) async {
    emit(state.copyWith(filter: filter));
    await loadAdminStats();
  }
}
