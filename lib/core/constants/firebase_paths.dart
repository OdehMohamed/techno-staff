class FirebasePaths {
  FirebasePaths._();

  // Collections
  static const String users = 'users';
  static const String tasks = 'tasks';
  static const String taskLogs = 'task_logs';
  static const String notifications = 'notifications';
  static const String attendance = 'attendance';
  static const String attendanceLogs = 'attendance_logs';
  static const String taskTemplates = 'task_templates';
  static const String fcmTokens = 'fcm_tokens';
  static const String schedules = 'schedules';
  static const String config = 'config';
  static const String appSettings = 'app_settings';
  static const String conversations = 'conversations';
  static const String messages = 'messages';
  static const String taskAttachments = 'attachments';

  // Collections subsystem (v2.0.0)
  static const String customers = 'customers';
  static const String debts = 'debts';
  static const String installmentPlans = 'installment_plans';
  static const String installments = 'installments';
  static const String payments = 'payments';
  static const String handovers = 'handovers';
  static const String visits = 'visits';
  static const String collectionLogs = 'collection_logs';
  static const String collectionSettings = 'collection_settings';
  static const String counters = 'counters';

  // Fields (اختياري بس مهم لقدام)
  static const String createdAt = 'createdAt';
  static const String assignedTo = 'assignedTo';
  static const String assignedBy = 'assignedBy';
  static const String status = 'status';
  static const String role = 'role';
  static const String languageCode = 'languageCode';
  static const String dueDate = 'dueDate';
  static const String completedAt = 'completedAt';
}
