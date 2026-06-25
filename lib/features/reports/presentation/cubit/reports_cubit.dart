import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';
import '../../data/repositories/reports_repository.dart';
import '../../data/services/pdf_report_service.dart';
import 'reports_state.dart';
import '../../../attendance/data/models/attendance_model.dart';
import '../../../attendance/data/models/work_schedule_model.dart';
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
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    emit(
      state.copyWith(
        status: ReportsStatus.loading,
        selectedEmployee: employee,
        selectedStartDate: startDate,
        selectedEndDate: endDate,
        clearError: true,
      ),
    );

    try {
      final tasks = await _reportsRepository.getTasksForEmployee(
        employeeId: employee.id,
        startDate: startDate,
        endDate: endDate,
      );

      emit(
        state.copyWith(
          status: ReportsStatus.loaded,
          tasks: tasks,
          selectedEmployee: employee,
          selectedStartDate: startDate,
          selectedEndDate: endDate,
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

  Future<void> exportPdf({
    required List<AttendanceModel> monthlyRecords,
    required WorkScheduleModel? schedule,
    required String locale,
  }) async {
    final employee = state.selectedEmployee;
    final startDate = state.selectedStartDate;
    final endDate = state.selectedEndDate;
    final tasks = state.tasks;

    if (employee == null || startDate == null || endDate == null) {
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
        startDate: startDate,
        endDate: endDate,
        tasks: tasks,
        monthlyRecords: monthlyRecords,
        schedule: schedule,
        locale: locale,
      );

      final startTag =
          '${startDate.year}${startDate.month.toString().padLeft(2, '0')}${startDate.day.toString().padLeft(2, '0')}';
      final endTag =
          '${endDate.year}${endDate.month.toString().padLeft(2, '0')}${endDate.day.toString().padLeft(2, '0')}';
      await Printing.sharePdf(
        bytes: await file.readAsBytes(),
        filename: 'report_${employee.name}_${startTag}_$endTag.pdf',
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
