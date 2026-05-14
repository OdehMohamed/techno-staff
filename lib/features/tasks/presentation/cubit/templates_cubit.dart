import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/task_template_model.dart';
import '../../data/repositories/templates_repository.dart';
import 'templates_state.dart';

class TemplatesCubit extends Cubit<TemplatesState> {
  final TemplatesRepository _templatesRepository;

  TemplatesCubit({required TemplatesRepository templatesRepository})
    : _templatesRepository = templatesRepository,
      super(const TemplatesState());

  Future<void> fetchAll() async {
    emit(state.copyWith(status: TemplatesStatus.loading, clearError: true));
    try {
      final templates = await _templatesRepository.getAllTemplates();
      emit(
        state.copyWith(status: TemplatesStatus.loaded, templates: templates),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: TemplatesStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> createTemplate(TaskTemplateModel template) async {
    emit(state.copyWith(status: TemplatesStatus.loading, clearError: true));
    try {
      await _templatesRepository.createTemplate(template);
      await fetchAll();
    } catch (e) {
      emit(
        state.copyWith(
          status: TemplatesStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> updateTemplate(TaskTemplateModel template) async {
    emit(state.copyWith(status: TemplatesStatus.loading, clearError: true));
    try {
      await _templatesRepository.updateTemplate(template);
      await fetchAll();
    } catch (e) {
      emit(
        state.copyWith(
          status: TemplatesStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> toggleActive(String templateId, bool isActive) async {
    emit(state.copyWith(status: TemplatesStatus.loading, clearError: true));
    try {
      await _templatesRepository.setTemplateActive(templateId, isActive);
      await fetchAll();
    } catch (e) {
      emit(
        state.copyWith(
          status: TemplatesStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> deleteTemplate(String templateId) async {
    emit(state.copyWith(status: TemplatesStatus.loading, clearError: true));
    try {
      await _templatesRepository.deleteTemplate(templateId);
      await fetchAll();
    } catch (e) {
      emit(
        state.copyWith(
          status: TemplatesStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
