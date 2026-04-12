enum DashboardStatus { initial, loading, loaded, error }

enum DashboardFilter { today, week, month }

class DashboardState {
  final DashboardStatus status;
  final Map<String, int> stats;
  final String? errorMessage;
  final Map<String, dynamic> extraStats;
  final List<Map<String, dynamic>> activities;
  final DashboardFilter filter;
  final List<Map<String, dynamic>> trends;

  const DashboardState({
    this.status = DashboardStatus.initial,
    this.stats = const {},
    this.errorMessage,
    this.extraStats = const {},
    this.activities = const [],
    this.filter = DashboardFilter.today,
    this.trends = const [],
  });

  DashboardState copyWith({
    DashboardStatus? status,
    Map<String, int>? stats,
    String? errorMessage,
    bool clearError = false,
    Map<String, dynamic>? extraStats,
    List<Map<String, dynamic>>? activities,
    DashboardFilter? filter,
    List<Map<String, dynamic>>? trends,
  }) {
    return DashboardState(
      status: status ?? this.status,
      stats: stats ?? this.stats,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      extraStats: extraStats ?? this.extraStats,
      activities: activities ?? this.activities,
      filter: filter ?? this.filter,
      trends: trends ?? this.trends,
    );
  }
}
