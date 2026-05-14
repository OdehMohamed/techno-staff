import '../../data/models/task_template_model.dart';

enum TemplatesStatus { initial, loading, loaded, error }

class TemplatesState {
  final TemplatesStatus status;
  final List<TaskTemplateModel> templates;
  final String? errorMessage;

  const TemplatesState({
    this.status = TemplatesStatus.initial,
    this.templates = const [],
    this.errorMessage,
  });

  TemplatesState copyWith({
    TemplatesStatus? status,
    List<TaskTemplateModel>? templates,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TemplatesState(
      status: status ?? this.status,
      templates: templates ?? this.templates,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
