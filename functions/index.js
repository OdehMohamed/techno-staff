const admin = require("firebase-admin");
admin.initializeApp();

const tasks = require("./lib/tasks");
const taskNotifications = require("./lib/task-notifications");
const attendance = require("./lib/attendance");
const users = require("./lib/users");
const chat = require("./lib/chat");
const notifications = require("./lib/notifications");

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
