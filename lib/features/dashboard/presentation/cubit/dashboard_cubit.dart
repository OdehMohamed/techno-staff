import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/dashboard_repository.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final DashboardRepository _dashboardRepository;

  DashboardCubit({required DashboardRepository dashboardRepository})
    : _dashboardRepository = dashboardRepository,
      super(const DashboardState());

  Future<void> loadAdminStats() async {
    emit(state.copyWith(status: DashboardStatus.loading, clearError: true));

    try {
      final stats = await _dashboardRepository.getAdminStats();

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

  Future<void> loadEmployeeStats(String userId) async {
    emit(state.copyWith(status: DashboardStatus.loading, clearError: true));

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
}
