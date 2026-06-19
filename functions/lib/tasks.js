const {onDocumentDeleted} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const {
  ymdInJerusalem,
  jerusalemMidnightAsUTC,
  shouldGenerateOn,
  createInAppNotification,
} = require("./shared");

// ─── Recurring task instance generator ───────────────────────────────────────

exports.generateRecurringTaskInstances = onSchedule(
    {
      schedule: "0 6 * * *",
      timeZone: "Asia/Jerusalem",
    },
    async () => {
      try {
        const db = admin.firestore();
        const now = new Date();
        const todayYMD = ymdInJerusalem(now);
        const todayDueDate = jerusalemMidnightAsUTC(now);

        const snap = await db
            .collection("task_templates")
            .where("isActive", "==", true)
            .get();

        for (const templateDoc of snap.docs) {
          try {
            const template = templateDoc.data();
            if (!shouldGenerateOn(template.recurrence, now)) continue;

            // Support both legacy single-assignee and new multi-assignee templates.
            const assigneeIds =
            Array.isArray(template.assignedToIds) &&
            template.assignedToIds.length > 0 ?
              template.assignedToIds :
              template.assignedTo ?
                [template.assignedTo] :
                [];
            const assigneeNames =
            Array.isArray(template.assignedToNames) &&
            template.assignedToNames.length > 0 ?
              template.assignedToNames :
              template.assignedToName ?
                [template.assignedToName] :
                [];

            if (assigneeIds.length === 0) continue;

            for (let i = 0; i < assigneeIds.length; i++) {
              const assigneeId = assigneeIds[i];
              const assigneeName = assigneeNames[i] || "";
              // One instance per (template, assignee, date) — deterministic ID is
              // the sole idempotency gate; existence check is inside the transaction.
              const instanceId = `${templateDoc.id}_${assigneeId}_${todayYMD}`;
              const instanceRef = db.collection("tasks").doc(instanceId);

              await db.runTransaction(async (txn) => {
                const freshTemplate = await txn.get(templateDoc.ref);
                if (!freshTemplate.exists) return;
                const freshData = freshTemplate.data() || {};
                if (freshData.isActive !== true) return;

                const existingInstance = await txn.get(instanceRef);
                if (existingInstance.exists) return; // already generated

                const instance = {
                  title: freshData.title || "",
                  description: freshData.description || "",
                  assignedTo: assigneeId,
                  assignedToName: assigneeName,
                  assignedBy: freshData.assignedBy || "",
                  assignedByName: freshData.assignedByName || "",
                  priority: freshData.priority || "medium",
                  status: "pending",
                  taskType: freshData.taskType || "standard",
                  currentCount: 0,
                  dueDate: admin.firestore.Timestamp.fromDate(todayDueDate),
                  createdAt: admin.firestore.Timestamp.fromDate(now),
                  updatedAt: admin.firestore.Timestamp.fromDate(now),
                  completedAt: null,
                  templateId: templateDoc.id,
                };
                if (freshData.taskType === "counter" && freshData.targetCount) {
                  instance.targetCount = freshData.targetCount;
                }

                txn.set(instanceRef, instance);
              });
            }

            // lastGeneratedAt is metadata only — written after all assignees are
            // processed so a partial-run crash leaves it unset for the next retry.
            await templateDoc.ref.update({
              lastGeneratedAt: admin.firestore.Timestamp.fromDate(now),
              updatedAt: admin.firestore.Timestamp.fromDate(now),
            });
          } catch (templateError) {
            console.error(
                `Error processing template ${templateDoc.id}:`,
                templateError,
            );
            // Alert all admins in-app so template failures surface beyond logs.
            try {
              const adminsSnap = await db
                  .collection("users")
                  .where("role", "==", "admin")
                  .get();
              await Promise.all(
                  adminsSnap.docs.map((adminDoc) =>
                    createInAppNotification({
                      userId: adminDoc.id,
                      type: "recurring_template_error",
                      taskId: null,
                      data: {
                        templateId: templateDoc.id,
                        error: templateError.message || "Unknown error",
                      },
                    }),
                  ),
              );
            } catch (alertError) {
              console.error(
                  "Failed to send template-error admin alert:",
                  alertError,
              );
            }
          }
        }
      } catch (error) {
        console.error("Error generating recurring task instances:", error);
      }
    },
);

// ─── Attachment + Storage cleanup on task delete ──────────────────────────────

exports.cleanupTaskAttachments = onDocumentDeleted(
    "tasks/{taskId}",
    async (event) => {
      const taskId = event.params.taskId;
      const db = admin.firestore();

      // Delete Firestore sub-collection documents.
      const attachmentsRef = db
          .collection("tasks")
          .doc(taskId)
          .collection("attachments");
      const snapshots = await attachmentsRef.get();
      if (!snapshots.empty) {
        await Promise.all(snapshots.docs.map((doc) => doc.ref.delete()));
      }

      // Delete Storage folder — non-fatal if files don't exist.
      try {
        await admin
            .storage()
            .bucket()
            .deleteFiles({prefix: `tasks/${taskId}/attachments/`});
      } catch (err) {
        console.error(`Storage cleanup failed for task ${taskId}:`, err);
      }
    },
);
