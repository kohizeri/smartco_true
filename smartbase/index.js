const {setGlobalOptions} = require("firebase-functions");
const {onValueUpdated} = require("firebase-functions/v2/database");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

admin.initializeApp();
setGlobalOptions({maxInstances: 10});

// Notification cooldown period (in milliseconds)
const NOTIFICATION_COOLDOWN_MS = 2 * 60 * 1000; // 2 minutes

/**
 * Check if a notification should be sent (debouncing)
 * @param {string} uid
 * @param {string} petId
 * @param {string} alertType
 * @return {Promise<boolean>}
 */
async function shouldSendNotification(uid, petId, alertType) {
  try {
    const lastAlertRef = admin
        .database()
        .ref(`/users/${uid}/pets/${petId}/last_alerts/${alertType}`);
    const lastAlertSnap = await lastAlertRef.once("value");
    const lastAlertTime = lastAlertSnap.val();

    const now = Date.now();

    if (!lastAlertTime || now - lastAlertTime >= NOTIFICATION_COOLDOWN_MS) {
      await lastAlertRef.set(now);
      return true;
    }

    logger.info(
        `Notification for ${alertType} skipped (cooldown). ` +
        `Last alert: ${new Date(lastAlertTime).toISOString()}`,
    );
    return false;
  } catch (error) {
    logger.error("Error checking notification cooldown:", error);
    return true;
  }
}

/**
 * Reset alert cooldown when value returns to normal
 * @param {string} uid
 * @param {string} petId
 * @param {string} alertType
 */
async function resetAlertCooldown(uid, petId, alertType) {
  try {
    const lastAlertRef = admin
        .database()
        .ref(`/users/${uid}/pets/${petId}/last_alerts/${alertType}`);
    await lastAlertRef.remove();
    logger.info(`Alert cooldown reset for ${alertType}`);
  } catch (error) {
    logger.error("Error resetting alert cooldown:", error);
  }
}

/**
 * Send push notification to user
 * @param {string} uid
 * @param {string} title
 * @param {string} body
 * @param {string|null} type
 * @param {string|null} petId
 */
async function sendPushNotification(uid, title, body, type = null,
    petId = null) {
  try {
    const timestamp = Date.now();
    const notifData = {
      title,
      message: body,
      timestamp,
      type: type || "alert",
      petId: petId || null,
      source: "server",
    };

    await admin.database().ref(`/users/${uid}/notifications`)
        .push().set(notifData);

    logger.info(
        `Notification saved for ${uid}: ${title} - ${body}`,
    );

    const tokenSnap = await admin.database()
        .ref(`/users/${uid}/deviceToken`)
        .once("value");
    const token = tokenSnap.val();

    if (!token) {
      logger.warn(`No device token found for user ${uid}`);
      return;
    }

    const payload = {notification: {title, body}};
    await admin.messaging().sendToDevice(token, payload);

    logger.info(`Push notification sent to ${uid}: ${title} - ${body}`);
  } catch (error) {
    logger.error("Error sending push notification:", error);
  }
}

/**
 * Check threshold for bpm or temperature alerts
 * @param {string} uid
 * @param {string} petId
 * @param {string} type
 * @param {number} value
 */
async function checkThreshold(uid, petId, type, value) {
  try {
    const settingsSnap = await admin
        .database()
        .ref(`/users/${uid}/pets/${petId}/notification_settings`)
        .once("value");
    const settings = settingsSnap.val();
    if (!settings) return;

    let alert = false;
    let message = "";
    let notifType = null;

    if (type === "bpm" && settings.heartRateAlert) {
      if (value > settings.maxHeartRate) {
        alert = true;
        notifType = "hr_high";
        message = `Heart rate too high: ${value} bpm ` +
                  `(max ${settings.maxHeartRate})`;
      } else if (value < settings.minHeartRate) {
        alert = true;
        notifType = "hr_low";
        message = `Heart rate too low: ${value} bpm ` +
                  `(min ${settings.minHeartRate})`;
      } else {
        await resetAlertCooldown(uid, petId, "hr_high");
        await resetAlertCooldown(uid, petId, "hr_low");
      }
    }

    if (type === "temperature" && settings.tempAlert) {
      if (value > settings.maxTemp) {
        alert = true;
        notifType = "temp_high";
        message = `Temperature too high: ${value}°C ` +
                  `(max ${settings.maxTemp}°C)`;
      } else if (value < settings.minTemp) {
        alert = true;
        notifType = "temp_low";
        message = `Temperature too low: ${value}°C ` +
                  `(min ${settings.minTemp}°C)`;
      } else {
        await resetAlertCooldown(uid, petId, "temp_high");
        await resetAlertCooldown(uid, petId, "temp_low");
      }
    }

    if (alert) {
      const shouldSend = await shouldSendNotification(uid, petId, notifType);
      if (shouldSend) {
        await sendPushNotification(
            uid,
            `SmartCollar Alert: ${type}`,
            message,
            notifType,
            petId,
        );
      }
    }
  } catch (error) {
    logger.error("Error checking threshold:", error);
  }
}

/**
 * Calculate distance between two GPS points in meters
 * @param {number} lat1
 * @param {number} lon1
 * @param {number} lat2
 * @param {number} lon2
 * @return {number}
 */
function haversineDistance(lat1, lon1, lat2, lon2) {
  const toRad = (x) => (x * Math.PI) / 180;
  const R = 6371000; // meters
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * Check geofence for pet location
 * @param {string} uid
 * @param {string} petId
 * @param {number} latitude
 * @param {number} longitude
 */
async function checkGeofence(uid, petId, latitude, longitude) {
  try {
    const geoSnap = await admin.database()
        .ref(`/users/${uid}/pets/${petId}/geofence`)
        .once("value");
    const geofence = geoSnap.val();
    if (!geofence) return;

    const distance = haversineDistance(
        latitude,
        longitude,
        geofence.latitude,
        geofence.longitude,
    );

    if (distance > geofence.radius) {
      const shouldSend = await shouldSendNotification(uid, petId, "geofence");
      if (shouldSend) {
        await sendPushNotification(
            uid,
            "SmartCollar Alert: Geofence",
            `Your pet has left the safe zone! Distance:' +
            '${Math.round(distance)}m`,
            "geofence",
            petId,
        );
      }
    } else {
      await resetAlertCooldown(uid, petId, "geofence");
    }
  } catch (error) {
    logger.error("Error checking geofence:", error);
  }
}

// Realtime Database triggers
exports.bpmChanged = onValueUpdated(
    "/users/{uid}/pets/{petId}/collar_data/bpm",
    async (event) => {
      const after = event.data.current;
      await checkThreshold(event.params.uid, event.params.petId, "bpm", after);
    },
);

exports.tempChanged = onValueUpdated(
    "/users/{uid}/pets/{petId}/collar_data/temperature",
    async (event) => {
      const after = event.data.current;
      await checkThreshold(
          event.params.uid,
          event.params.petId,
          "temperature",
          after);
    },
);

exports.locationChanged = onValueUpdated(
    "/users/{uid}/pets/{petId}/collar_data/location",
    async (event) => {
      const after = event.data.current;
      if (!after || !after.latitude || !after.longitude) return;
      await checkGeofence(
          event.params.uid,
          event.params.petId,
          after.latitude,
          after.longitude,
      );
    },
);

