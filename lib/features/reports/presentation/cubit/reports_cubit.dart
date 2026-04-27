import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';
import '../../data/repositories/reports_repository.dart';
import '../../data/services/pdf_report_service.dart';
import 'reports_state.dart';
import '../../../auth/domain/models/app_user.dart';

class ReportsCubit extends Cubit<ReportsState> {
  final ReportsRepository _reportsRepository;
  final PdfReportService _pdfReportService;

  ReportsCubit({
    required ReportsRepository reportsRepository,
    required PdfReportService pdfReportService,
  }) : _reportsRepository = reportsRepository,
       _pdfReportService = pdfReportService,
       super(const ReportsState());

  Future<void> loadEmployees() async {
    emit(state.copyWith(status: ReportsStatus.loading, clearError: true));

    try {
      final employees = await _reportsRepository.getEmployees();

      emit(
        state.copyWith(
          status: ReportsStatus.loaded,
          employees: employees,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ReportsStatus.error,
          errorMessage: 'failed_to_load_reports',
        ),
      );
    }
  }

  Future<void> generateReport({
    required AppUser employee,
    required DateTime month,
  }) async {
    emit(
      state.copyWith(
        status: ReportsStatus.loading,
        selectedEmployee: employee,
        selectedMonth: month,
        clearError: true,
      ),
    );

    try {
      final tasks = await _reportsRepository.getTasksForEmployeeByMonth(
        employeeId: employee.id,
        month: month,
      );

      emit(
        state.copyWith(
          status: ReportsStatus.loaded,
          tasks: tasks,
          selectedEmployee: employee,
          selectedMonth: month,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ReportsStatus.error,
          errorMessage: 'failed_to_load_reports',
        ),
      );
    }
  }

  Future<void> exportPdf() async {
    final employee = state.selectedEmployee;
    final month = state.selectedMonth;
    final tasks = state.tasks;

    if (employee == null || month == null) {
      emit(
        state.copyWith(
          status: ReportsStatus.error,
          errorMessage: 'failed_to_export_pdf',
        ),
      );
      return;
    }

    emit(state.copyWith(status: ReportsStatus.exportingPdf, clearError: true));

    try {
      final file = await _pdfReportService.generateEmployeeMonthlyReport(
        employee: employee,
        month: month,
        tasks: tasks,
      );

      await Printing.sharePdf(
        bytes: await file.readAsBytes(),
        filename:
            'report_${employee.name}_${month.year}_${month.month.toString().padLeft(2, '0')}.pdf',
      );

      emit(state.copyWith(status: ReportsStatus.pdfExported, clearError: true));

      emit(state.copyWith(status: ReportsStatus.loaded, clearError: true));
    } catch (_) {
      emit(
        state.copyWith(
          status: ReportsStatus.error,
          errorMessage: 'failed_to_export_pdf',
        ),
      );
    }
  }
}
