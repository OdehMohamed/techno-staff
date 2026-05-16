import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/section_header.dart';
import '../cubit/attendance_cubit.dart';
import '../cubit/attendance_state.dart';
import '../widgets/attendance_check_button.dart';
import '../widgets/attendance_record_card.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final Connectivity _connectivity = Connectivity();
  final LocalAuthentication _localAuthentication = LocalAuthentication();

  StreamSubscription<dynamic>? _connectivitySubscription;
  bool _isOnline = true;
  String? _lastAction;

  @override
  void initState() {
    super.initState();
    _setupConnectivity();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthCubit>().state.user;
      if (user == null) {
        return;
      }

      final attendanceCubit = context.read<AttendanceCubit>();
      attendanceCubit.startListeningToday(user.id);
      attendanceCubit.loadHistory(user.id);
    });
  }

  Future<void> _setupConnectivity() async {
    final current = await _connectivity.checkConnectivity();
    if (!mounted) {
      return;
    }

    setState(() {
      _isOnline = _hasConnection(current);
    });

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      status,
    ) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isOnline = _hasConnection(status);
      });
    });
  }

  bool _hasConnection(dynamic status) {
    if (status is List<ConnectivityResult>) {
      return !status.contains(ConnectivityResult.none);
    }
    if (status is ConnectivityResult) {
      return status != ConnectivityResult.none;
    }
    return true;
  }

  Future<void> _handleAttendanceAction({required bool isCheckIn}) async {
    if (!_isOnline) {
      _showSnackBar('no_internet_for_attendance');
      return;
    }

    try {
      final isDeviceSupported = await _localAuthentication.isDeviceSupported();
      final canCheckBiometrics = await _localAuthentication.canCheckBiometrics;
      if (!isDeviceSupported || !canCheckBiometrics) {
        _showSnackBar('biometric_not_available');
        return;
      }

      final didAuthenticate = await _localAuthentication.authenticate(
        localizedReason: isCheckIn
            ? 'biometric_reason_check_in'.tr()
            : 'biometric_reason_check_out'.tr(),
      );

      if (!didAuthenticate) {
        _showSnackBar('biometric_not_available');
        return;
      }
    } on PlatformException {
      _showSnackBar('biometric_not_available');
      return;
    }

    _lastAction = isCheckIn ? 'check_in' : 'check_out';

    if (!mounted) {
      return;
    }

    final cubit = context.read<AttendanceCubit>();
    if (isCheckIn) {
      await cubit.checkIn();
    } else {
      await cubit.checkOut();
    }
  }

  void _showSnackBar(String key) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(key.tr())));
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text('my_attendance'.tr())),
        body: const SizedBox.shrink(),
      );
    }

    return BlocConsumer<AttendanceCubit, AttendanceState>(
      listener: (context, state) {
        if (state.actionStatus == AttendanceActionStatus.success) {
          final key = _lastAction == 'check_out'
              ? 'check_out_success'
              : 'check_in_success';
          _showSnackBar(key);
          context.read<AttendanceCubit>().clearActionFeedback();
        }

        if (state.actionStatus == AttendanceActionStatus.error &&
            state.actionError != null) {
          _showSnackBar(state.actionError!);
          context.read<AttendanceCubit>().clearActionFeedback();
        }
      },
      builder: (context, state) {
        final nowLabel = DateFormat.yMMMMd(
          context.locale.languageCode,
        ).format(DateTime.now());

        return Scaffold(
          appBar: AppBar(title: Text('my_attendance'.tr())),
          drawer: const AppDrawer(),
          body: RefreshIndicator(
            onRefresh: () =>
                context.read<AttendanceCubit>().loadHistory(user.id),
            child: ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                SectionHeader(
                  title: 'today_attendance'.tr(),
                  subtitle: nowLabel,
                ),
                AttendanceCheckButton(
                  todayRecord: state.todayRecord,
                  isOnline: _isOnline,
                  isSubmitting:
                      state.actionStatus == AttendanceActionStatus.submitting,
                  onCheckIn: () => _handleAttendanceAction(isCheckIn: true),
                  onCheckOut: () => _handleAttendanceAction(isCheckIn: false),
                ),
                const SizedBox(height: AppSizes.lg),
                SectionHeader(title: 'attendance_history'.tr()),
                if (state.historyStatus == AttendanceLoadStatus.loading &&
                    state.history.isEmpty)
                  const Center(child: CircularProgressIndicator())
                else if (state.historyStatus == AttendanceLoadStatus.error)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSizes.sm),
                    child: Text((state.historyError ?? 'network_error').tr()),
                  )
                else if (state.history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSizes.sm),
                    child: Text('no_attendance_records'.tr()),
                  )
                else
                  ...state.history.map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.sm),
                      child: AttendanceRecordCard(record: record),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
