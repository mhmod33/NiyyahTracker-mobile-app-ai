const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

// ───────────────────────────────────────────────
// Helper: send an FCM notification to all tokens
// ───────────────────────────────────────────────
async function sendPushToAllTokens(title, body, data = {}) {
  const tokensSnapshot = await db.collection('fcm_tokens').get();
  if (tokensSnapshot.empty) {
    functions.logger.info('No FCM tokens found — skipping push');
    return;
  }

  const tokens = tokensSnapshot.docs.map((doc) => doc.data().token).filter(Boolean);

  if (tokens.length === 0) return;

  const message = {
    notification: { title, body },
    data: {
      ...data,
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
    tokens,
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    functions.logger.info(
      `FCM sent: ${response.successCount} success, ${response.failureCount} failures`,
    );

    // Clean up invalid tokens
    if (response.failureCount > 0) {
      const invalidTokens = [];
      response.responses.forEach((resp, idx) => {
        if (
          !resp.success &&
          resp.error &&
          (resp.error.code === 'messaging/invalid-registration-token' ||
            resp.error.code === 'messaging/registration-token-not-registered')
        ) {
          invalidTokens.push(tokens[idx]);
        }
      });

      if (invalidTokens.length > 0) {
        const batch = db.batch();
        for (const token of invalidTokens) {
          const docs = await db
            .collection('fcm_tokens')
            .where('token', '==', token)
            .get();
          docs.forEach((doc) => batch.delete(doc.ref));
        }
        await batch.commit();
        functions.logger.info(`Cleaned up ${invalidTokens.length} invalid tokens`);
      }
    }
  } catch (error) {
    functions.logger.error('FCM send error:', error);
  }
}

// ───────────────────────────────────────────────
// Admin Notification Trigger
// ───────────────────────────────────────────────
/** Sends a push notification to all users when admin creates a notification. */
exports.onAdminNotificationCreated = functions.firestore
  .document('admin_notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const title = data.title || 'إشعار من الإدارة';
    const body = data.body || '';
    const adminName = data.adminName || 'الإدارة';

    functions.logger.info(`Admin notification created: "${title}" by ${adminName}`);

    await sendPushToAllTokens(
      title,
      body,
      { type: 'admin_notification', notificationId: context.params.notificationId },
    );
  });

// ───────────────────────────────────────────────
// App Version Update Trigger
// ───────────────────────────────────────────────
/** Sends a push notification when the app version document is updated. */
exports.onAppVersionUpdated = functions.firestore
  .document('app_config/current_version')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const oldVersion = before?.version;
    const newVersion = after?.version;

    // Only notify if version actually changed
    if (oldVersion === newVersion || !newVersion) {
      functions.logger.info('Version unchanged — skipping notification');
      return;
    }

    const title = 'تحديث جديد لبصائر';
    const updateMessage = after?.updateMessage || `تم إصدار تحديث جديد v${newVersion}`;
    const body = updateMessage;
    const forceUpdate = after?.forceUpdate ?? false;

    functions.logger.info(`App version updated: ${oldVersion} -> ${newVersion}`);

    await sendPushToAllTokens(
      title,
      body,
      {
        type: 'version_update',
        version: newVersion,
        forceUpdate: String(forceUpdate),
      },
    );
  });
