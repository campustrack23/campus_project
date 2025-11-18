// functions/index.js
// Cloud Functions v2 (Node 18/20/22)
const { onCall } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2/options");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

// Set your region (must match your Flutter app's NotificationService.kFunctionsRegion)
setGlobalOptions({ region: "us-central1", maxInstances: 10 });

function normSection(section) {
  if (!section) return null;
  return String(section)
    .replace(/\s+/g, "")
    .replace(/[^A-Za-z0-9_-]/g, "")
    .toUpperCase();
}

// v2 Callable: register device, subscribe to topics, store token
exports.registerDevice = onCall(async (request) => {
  const data = request.data || {};
  const userId = data.userId;
  const role = data.role;
  const section = data.section;
  const token = data.token;
  const platform = data.platform || "unknown";

  if (!userId || !role || !token) {
    throw new Error("Missing userId/role/token");
  }

  const topics = new Set();
  topics.add("all");
  topics.add(`user_${userId}`);
  topics.add(`role_${String(role).toLowerCase()}`);
  const sec = normSection(section);
  if (sec) topics.add(`section_${sec}`);

  for (const t of topics) {
    try {
      await admin.messaging().subscribeToTopic(token, t);
    } catch (e) {
      logger.error("subscribe error", { topic: t, error: String(e) });
    }
  }

  try {
    await admin
      .firestore()
      .collection("userTokens")
      .doc(userId)
      .collection("tokens")
      .doc(token)
      .set(
        {
          token,
          role: String(role).toLowerCase(),
          section: sec || null,
          platform,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
  } catch (e) {
    logger.warn("store token failed", { error: String(e) });
  }

  return { ok: true, topics: Array.from(topics) };
});

// v2 Callable: unregister device (unsubscribe from common topics and stored section)
exports.unregisterDevice = onCall(async (request) => {
  const data = request.data || {};
  const userId = data.userId;
  const token = data.token;
  if (!userId || !token) {
    throw new Error("Missing userId/token");
  }

  const common = ["all", `user_${userId}`, "role_student", "role_teacher", "role_admin"];
  for (const t of common) {
    try {
      await admin.messaging().unsubscribeFromTopic(token, t);
    } catch (e) {
      // best effort
    }
  }

  try {
    const docRef = admin.firestore().collection("userTokens").doc(userId).collection("tokens").doc(token);
    const snap = await docRef.get();
    if (snap.exists) {
      const sec = snap.data().section;
      if (sec) {
        try {
          await admin.messaging().unsubscribeFromTopic(token, `section_${sec}`);
        } catch (e) {}
      }
      await docRef.delete();
    }
  } catch (e) {
    logger.warn("cleanup token failed", { error: String(e) });
  }

  return { ok: true };
});

// v2 Callable: broadcast push when attendance is marked (to section + admins)
exports.broadcastAttendanceMarked = onCall(async (request) => {
  const data = request.data || {};
  const section = data.section;
  const subjectName = data.subjectName;
  const day = data.day;
  const timeRange = data.timeRange;
  if (!section || !subjectName || !day || !timeRange) {
    throw new Error("Missing fields");
  }
  const sec = normSection(section);
  const title = `Attendance marked: ${subjectName}`;
  const body = `${day} ${timeRange} • ${section}`;

  const msgs = [
    {
      // Students in the section
      topic: `section_${sec}`,
      notification: { title, body },
      data: { type: "attendanceMarked", section: sec, subject: subjectName, day, time: timeRange },
      webpush: { notification: { title, body } },
      android: { notification: { title, body } },
    },
    {
      // Admins
      topic: "role_admin",
      notification: { title: `Section ${section}`, body },
      data: { type: "attendanceMarkedAdmin", section: sec, subject: subjectName, day, time: timeRange },
      webpush: { notification: { title: `Section ${section}`, body } },
      android: { notification: { title: `Section ${section}`, body } },
    },
  ];

  const results = [];
  for (const m of msgs) {
    try {
      const resId = await admin.messaging().send(m);
      results.push({ ok: true, id: resId });
    } catch (e) {
      logger.error("send error", { error: String(e) });
      results.push({ ok: false, error: String(e) });
    }
  }
  return { ok: true, results };
});