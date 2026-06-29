const admin = require("firebase-admin");
admin.initializeApp();

const tasks = require("./lib/tasks");
const taskNotifications = require("./lib/task-notifications");
const attendance = require("./lib/attendance");
const users = require("./lib/users");
const chat = require("./lib/chat");
const notifications = require("./lib/notifications");
const paymentTriggers = require("./lib/collections/payment-triggers");
const handoverTriggers = require("./lib/collections/handover-triggers");
const installmentTriggers = require("./lib/collections/installment-triggers");
const visitTriggers = require("./lib/collections/visit-triggers");
const debtTriggers = require("./lib/collections/debt-triggers");
const schedulers = require("./lib/collections/schedulers");

exports.generateRecurringTaskInstances = tasks.generateRecurringTaskInstances;
exports.cleanupTaskAttachments = tasks.cleanupTaskAttachments;

exports.sendTaskAssignedNotification = taskNotifications.sendTaskAssignedNotification;
exports.sendTaskStatusNotification = taskNotifications.sendTaskStatusNotification;
exports.sendTaskDeadlineReminders = taskNotifications.sendTaskDeadlineReminders;
exports.testTaskDeadlineReminders = taskNotifications.testTaskDeadlineReminders;
exports.sendOverdueTaskEscalations = taskNotifications.sendOverdueTaskEscalations;
exports.testOverdueTaskEscalations = taskNotifications.testOverdueTaskEscalations;

exports.recordAttendance = attendance.recordAttendance;
exports.adminCorrectAttendance = attendance.adminCorrectAttendance;
exports.adminResetAttendance = attendance.adminResetAttendance;
exports.sendDailyAbsenceMarker = attendance.sendDailyAbsenceMarker;

exports.createEmployeeUser = users.createEmployeeUser;
exports.deleteUserAccount = users.deleteUserAccount;
exports.revokeUserSessions = users.revokeUserSessions;

exports.onNewChatMessage = chat.onNewChatMessage;

exports.cleanupExpiredNotifications = notifications.cleanupExpiredNotifications;

exports.onPaymentCreated = paymentTriggers.onPaymentCreated;
exports.onPaymentCancelled = paymentTriggers.onPaymentCancelled;
exports.onHandoverCreated = handoverTriggers.onHandoverCreated;
exports.onHandoverUpdated = handoverTriggers.onHandoverUpdated;

exports.onInstallmentPlanCreated = installmentTriggers.onInstallmentPlanCreated;
exports.sendInstallmentDueReminders = installmentTriggers.sendInstallmentDueReminders;

exports.onVisitCreated = visitTriggers.onVisitCreated;
exports.onDebtStatusChanged = debtTriggers.onDebtStatusChanged;

exports.updateDebtAgingBuckets = schedulers.updateDebtAgingBuckets;
exports.checkBrokenPtps = schedulers.checkBrokenPtps;
exports.sendOverdueDebtEscalations = schedulers.sendOverdueDebtEscalations;
exports.sendStaleCashWarnings = schedulers.sendStaleCashWarnings;
exports.testUpdateDebtAgingBuckets = schedulers.testUpdateDebtAgingBuckets;
exports.testSendStaleCashWarnings = schedulers.testSendStaleCashWarnings;
exports.testCheckBrokenPtps = schedulers.testCheckBrokenPtps;
exports.testSendOverdueDebtEscalations = schedulers.testSendOverdueDebtEscalations;
