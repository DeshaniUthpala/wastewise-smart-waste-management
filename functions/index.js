/**
 * WasteWise Cloud Functions
 * - onPickupRequestCreated -> notify all admins
 * - onDriverAssignedToPickup -> notify driver + citizen
 * - onPickupStatusUpdated -> notify citizen
 * - onIssueCreated -> notify admins
 * - onIssueAssignedOrResolved -> notify citizen and/or driver
 *
 * NOTE:
 *  - These functions assume Firestore collections:
 *      users, drivers, pickupRequests, issues, notifications
 *  - FCM tokens should be stored on the user document, e.g. users/{uid}.fcmTokens: [token1, token2]
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Helper: create notification document
 */
async function createNotification({userId, title, message, type, relatedId}) {
  const payload = {
    userId,
    title,
    message,
    type,
    relatedId: relatedId || null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    read: false,
  };

  await db.collection("notifications").add(payload);
  return payload;
}

/**
 * Helper: send FCM notification to a user by userId
 * Expects `fcmTokens` array on users/{uid}
 */
async function sendFcmToUser(userId, title, body, data) {
  const userSnap = await db.collection("users").doc(userId).get();
  if (!userSnap.exists) return;

  const user = userSnap.data();
  const tokens = user.fcmTokens || [];
  if (!Array.isArray(tokens) || tokens.length === 0) return;

  const message = {
    notification: {title, body},
    data: data || {},
    tokens,
  };

  await admin.messaging().sendEachForMulticast(message);
}

/**
 * 1) onPickupRequestCreated -> notify all admins
 */
exports.onPickupRequestCreated = functions.firestore
  .document("pickupRequests/{pickupId}")
  .onCreate(async (snap, context) => {
    const pickup = snap.data();
    const pickupId = context.params.pickupId;

    // Fetch all admins from users collection
    const adminsSnap = await db.collection("users")
      .where("role", "==", "admin")
      .get();

    const title = "New Pickup Request";
    const message =
      `New pickup request from citizen ${pickup.citizenId} (${pickup.wasteType})`;

    const tasks = [];
    adminsSnap.forEach((doc) => {
      const adminId = doc.id;
      tasks.push(
        createNotification({
          userId: adminId,
          title,
          message,
          type: "pickup_created",
          relatedId: pickupId,
        }),
      );
      tasks.push(
        sendFcmToUser(adminId, title, message, {
          type: "pickup_created",
          pickupId,
        }),
      );
    });

    await Promise.all(tasks);
  });

/**
 * 2 & 3) onDriverAssignedToPickup + onPickupStatusUpdated
 * We detect changes on pickupRequests:
 *  - if driverId changed from null to value -> driver assigned
 *  - if status changed -> status updated
 */
exports.onPickupRequestUpdated = functions.firestore
  .document("pickupRequests/{pickupId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const pickupId = context.params.pickupId;

    const notifications = [];

    // 2) Driver assigned
    const driverAssignedNow = !before.driverId && after.driverId;
    if (driverAssignedNow) {
      const driverId = after.driverId;
      const citizenId = after.citizenId;

      const titleDriver = "New Pickup Assigned";
      const msgDriver =
        `You have been assigned a pickup (${after.wasteType}, ` +
        `${after.urgency || "normal"}).`;

      notifications.push(
        createNotification({
          userId: driverId,
          title: titleDriver,
          message: msgDriver,
          type: "driver_assigned",
          relatedId: pickupId,
        }),
      );
      notifications.push(
        sendFcmToUser(driverId, titleDriver, msgDriver, {
          type: "driver_assigned",
          pickupId,
        }),
      );

      const titleCitizen = "Driver Assigned";
      const msgCitizen = "A driver has been assigned to your pickup request.";

      notifications.push(
        createNotification({
          userId: citizenId,
          title: titleCitizen,
          message: msgCitizen,
          type: "driver_assigned",
          relatedId: pickupId,
        }),
      );
      notifications.push(
        sendFcmToUser(citizenId, titleCitizen, msgCitizen, {
          type: "driver_assigned",
          pickupId,
        }),
      );
    }

    // 3) Pickup status updated (notify citizen)
    if (before.status !== after.status) {
      const citizenId = after.citizenId;
      const newStatus = after.status;

      const title = "Pickup Status Updated";
      const message =
        `Your pickup request status changed from ` +
        `${before.status} to ${newStatus}.`;

      notifications.push(
        createNotification({
          userId: citizenId,
          title,
          message,
          type: "pickup_status_updated",
          relatedId: pickupId,
        }),
      );
      notifications.push(
        sendFcmToUser(citizenId, title, message, {
          type: "pickup_status_updated",
          pickupId,
          oldStatus: String(before.status),
          newStatus: String(newStatus),
        }),
      );
    }

    await Promise.all(notifications);
  });

/**
 * 4) onIssueCreated -> notify admins
 */
exports.onIssueCreated = functions.firestore
  .document("issues/{issueId}")
  .onCreate(async (snap, context) => {
    const issue = snap.data();
    const issueId = context.params.issueId;

    const adminsSnap = await db.collection("users")
      .where("role", "==", "admin")
      .get();

    const title = "New Issue Reported";
    const message =
      `${issue.type || "Issue"} reported by ${issue.reporterId}`;

    const tasks = [];
    adminsSnap.forEach((doc) => {
      const adminId = doc.id;
      tasks.push(
        createNotification({
          userId: adminId,
          title,
          message,
          type: "issue_created",
          relatedId: issueId,
        }),
      );
      tasks.push(
        sendFcmToUser(adminId, title, message, {
          type: "issue_created",
          issueId,
        }),
      );
    });

    await Promise.all(tasks);
  });

/**
 * 5) onIssueAssignedOrResolved -> notify citizen and/or driver
 */
exports.onIssueUpdated = functions.firestore
  .document("issues/{issueId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const issueId = context.params.issueId;

    const tasks = [];

    // Assigned driver changed
    if (before.assignedDriverId !== after.assignedDriverId &&
      after.assignedDriverId) {
      const driverId = after.assignedDriverId;
      const title = "Issue Assigned";
      const message = "An issue has been assigned to you for handling.";

      tasks.push(
        createNotification({
          userId: driverId,
          title,
          message,
          type: "issue_assigned",
          relatedId: issueId,
        }),
      );
      tasks.push(
        sendFcmToUser(driverId, title, message, {
          type: "issue_assigned",
          issueId,
        }),
      );
    }

    // Status changed to resolved/closed -> notify reporter
    if (before.status !== after.status &&
      (after.status === "resolved" || after.status === "closed")) {
      const reporterId = after.reporterId;
      const title = "Issue Resolved";
      const message =
        "Your reported issue has been marked as " + after.status + ".";

      tasks.push(
        createNotification({
          userId: reporterId,
          title,
          message,
          type: "issue_resolved",
          relatedId: issueId,
        }),
      );
      tasks.push(
        sendFcmToUser(reporterId, title, message, {
          type: "issue_resolved",
          issueId,
          status: String(after.status),
        }),
      );
    }

    await Promise.all(tasks);
  });

