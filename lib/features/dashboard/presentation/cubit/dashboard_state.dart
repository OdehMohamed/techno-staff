enum DashboardStatus { initial, loading, loaded, error }

class DashboardState {
  final DashboardStatus status;
  final Map<String, int> stats;
  final String? errorMessage;
  final Map<String, dynamic> extraStats;
  final List<Map<String, dynamic>> activities;

  const DashboardState({
    this.status = DashboardStatus.initial,
    this.stats = const {},
    this.errorMessage,
    this.extraStats = const {},
    this.activities = const [],
  });

  DashboardState copyWith({
    DashboardStatus? status,
    Map<String, int>? stats,
    String? errorMessage,
    bool clearError = false,
    Map<String, dynamic>? extraStats,
    List<Map<String, dynamic>>? activities,
  }) {
    return DashboardState(
      status: status ?? this.status,
      stats: stats ?? this.stats,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      extraStats: extraStats ?? this.extraStats,
      activities: activities ?? this.activities,
    );
  }
}
