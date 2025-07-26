// functions/src/notifications/alert-cloud-function.ts
// Simplified notification checker - ESLint compliant

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const messaging = admin.messaging();

// Environment configuration - your 2 key variables
const SCALE_FACTOR = parseFloat(
  process.env.NOTIFICATION_SCALE_FACTOR || "1"
);
const CHECK_FREQUENCY = 
  process.env.NOTIFICATION_CHECK_FREQUENCY_MINUTES || "360";

/**
 * Simple Cloud Function: Check Favorite Rivers
 * 
 * Checks if forecasted flows for favorite rivers cross scaled return periods
 * Sends simple notifications when thresholds are exceeded
 */
export const checkFlowNotifications = functions.pubsub
  .schedule(`every ${CHECK_FREQUENCY} minutes`)
  .timeZone("America/Denver")
  .onRun(async () => {
    console.log(
      `🌊 Starting simple notification check (scale factor: ${SCALE_FACTOR})...`
    );
    
    try {
      // Step 1: Get all users with notifications enabled
      const enabledUsers = await getEnabledUsers();
      console.log(
        `👥 Found ${enabledUsers.length} users with notifications enabled`
      );

      let totalNotificationsSent = 0;

      // Step 2: For each user, check their favorites
      for (const user of enabledUsers) {
        const notificationsSent = await checkUserFavorites(user);
        totalNotificationsSent += notificationsSent;
      }

      console.log(`📱 Total notifications sent: ${totalNotificationsSent}`);

      return { 
        success: true, 
        notificationsSent: totalNotificationsSent,
        scaleFactor: SCALE_FACTOR,
      };

    } catch (error) {
      console.error("❌ Error in simple notification check:", error);
      throw new functions.https.HttpsError(
        "internal", 
        "Notification check failed"
      );
    }
  });

/**
 * Get users who have notifications enabled
 * @return {Promise<Array<{userId: string, fcmToken: string}>>} Enabled users
 */
async function getEnabledUsers(): Promise<Array<{
  userId: string; 
  fcmToken: string;
}>> {
  const users: Array<{userId: string; fcmToken: string}> = [];

  // Get users collection and filter for those with notifications enabled
  const usersSnapshot = await db.collection("users").get();
  
  for (const userDoc of usersSnapshot.docs) {
    const userData = userDoc.data();
    
    // Check if user has notifications enabled and FCM token
    if (userData.notificationsEnabled === true && userData.fcmToken) {
      users.push({
        userId: userDoc.id,
        fcmToken: userData.fcmToken,
      });
    }
  }

  return users;
}

/**
 * Check favorites for a specific user
 * @param {Object} user - User object with userId and fcmToken
 * @return {Promise<number>} Number of notifications sent
 */
async function checkUserFavorites(user: {
  userId: string; 
  fcmToken: string;
}): Promise<number> {
  let notificationsSent = 0;

  try {
    // Get user's favorites
    const favoritesSnapshot = await db
      .collection("favorites")
      .where("userId", "==", user.userId)
      .get();

    console.log(
      `📋 User ${user.userId} has ${favoritesSnapshot.docs.length} favorites`
    );

    // Check each favorite
    for (const favoriteDoc of favoritesSnapshot.docs) {
      const favorite = favoriteDoc.data();
      const reachId = favorite.reachId;

      if (await checkReachForNotification(reachId, user)) {
        notificationsSent++;
      }
    }

  } catch (error) {
    console.error(
      `❌ Error checking favorites for user ${user.userId}:`, 
      error
    );
  }

  return notificationsSent;
}

/**
 * Check if a specific reach should trigger a notification
 * @param {string} reachId - The reach ID to check
 * @param {Object} user - User object with userId and fcmToken
 * @return {Promise<boolean>} Whether notification was sent
 */
async function checkReachForNotification(
  reachId: string, 
  user: {userId: string; fcmToken: string}
): Promise<boolean> {
  
  try {
    // Get current forecast data (short and medium range only)
    const forecastData = await getForecastData(reachId);
    if (!forecastData) {
      console.log(`⚠️ No forecast data for reach ${reachId}`);
      return false;
    }

    // Get return period data
    const returnPeriod = await getReturnPeriodData(reachId);
    if (!returnPeriod) {
      console.log(`⚠️ No return period data for reach ${reachId}`);
      return false;
    }

    // Check if forecast exceeds any scaled return period
    const exceedsThreshold = checkScaledThresholds(
      forecastData, 
      returnPeriod
    );
    
    if (exceedsThreshold.shouldNotify) {
      await sendSimpleNotification(
        user, 
        reachId, 
        exceedsThreshold, 
        forecastData.reachName
      );
      return true;
    }

  } catch (error) {
    console.error(`❌ Error checking reach ${reachId}:`, error);
  }

  return false;
}

/**
 * Get forecast data for a reach (short and medium range only)
 * @param {string} reachId - The reach ID
 * @return {Promise<Object|null>} Forecast data or null
 */
async function getForecastData(reachId: string): Promise<{
  maxFlow: number;
  reachName: string;
  forecastType: string;
} | null> {
  
  // Try to get cached forecast data
  const forecastDoc = await db.collection("forecastCache").doc(reachId).get();
  
  if (!forecastDoc.exists) {
    return null;
  }

  const data = forecastDoc.data();
  
  // Get the maximum flow from short and medium range forecasts
  let maxFlow = 0;
  let forecastType = "short_range";

  // Check short range forecast
  if (data?.shortRange?.forecasts) {
    const shortRangeMax = Math.max(
      ...data.shortRange.forecasts.map((f: any) => f.value || 0)
    );
    if (shortRangeMax > maxFlow) {
      maxFlow = shortRangeMax;
      forecastType = "short_range";
    }
  }

  // Check medium range forecast
  if (data?.mediumRange?.forecasts) {
    const mediumRangeMax = Math.max(
      ...data.mediumRange.forecasts.map((f: any) => f.value || 0)
    );
    if (mediumRangeMax > maxFlow) {
      maxFlow = mediumRangeMax;
      forecastType = "medium_range";
    }
  }

  return {
    maxFlow,
    reachName: data?.reachName || `River ${reachId}`,
    forecastType,
  };
}

/**
 * Get return period data for a reach
 * @param {string} reachId - The reach ID
 * @return {Promise<Object|null>} Return period data or null
 */
async function getReturnPeriodData(reachId: string): Promise<{
  flowValues: {[year: number]: number};
} | null> {
  
  const returnPeriodDoc = await db
    .collection("returnPeriodCache")
    .doc(reachId)
    .get();
  
  if (!returnPeriodDoc.exists) {
    return null;
  }

  const data = returnPeriodDoc.data();
  return {
    flowValues: data?.flowValues || {},
  };
}

/**
 * Check if forecast exceeds scaled return periods
 * @param {Object} forecastData - Forecast data with maxFlow
 * @param {Object} returnPeriod - Return period data with flowValues
 * @return {Object} Result indicating if notification should be sent
 */
function checkScaledThresholds(
  forecastData: {maxFlow: number},
  returnPeriod: {flowValues: {[year: number]: number}}
): {
  shouldNotify: boolean;
  exceededYear?: number;
  originalThreshold?: number;
  scaledThreshold?: number;
} {
  
  const returnPeriodYears = [5, 10, 25, 50]; // Check key return periods
  
  for (const year of returnPeriodYears) {
    const originalThreshold = returnPeriod.flowValues[year];
    
    if (originalThreshold) {
      const scaledThreshold = originalThreshold / SCALE_FACTOR;
      
      if (forecastData.maxFlow > scaledThreshold) {
        return {
          shouldNotify: true,
          exceededYear: year,
          originalThreshold,
          scaledThreshold,
        };
      }
    }
  }

  return {shouldNotify: false};
}

/**
 * Send simple notification
 * @param {Object} user - User with userId and fcmToken
 * @param {string} reachId - The reach ID
 * @param {Object} threshold - Threshold data
 * @param {string} reachName - Display name for the reach
 * @return {Promise<void>} Promise that resolves when notification is sent
 */
async function sendSimpleNotification(
  user: {userId: string; fcmToken: string},
  reachId: string,
  threshold: {exceededYear?: number; scaledThreshold?: number},
  reachName: string
): Promise<void> {
  
  try {
    const title = `Flow Alert: ${reachName}`;
    const body = `Forecast exceeds ${threshold.exceededYear}-year threshold (${Math.round(threshold.scaledThreshold || 0)} CFS)`;

    await messaging.send({
      token: user.fcmToken,
      notification: {
        title,
        body,
      },
      data: {
        reachId,
        type: "flow_alert",
        year: threshold.exceededYear?.toString() || "",
        timestamp: new Date().toISOString(),
      },
      android: {
        priority: "high",
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
      },
    });

    // Record notification history
    await db.collection("notificationHistory").add({
      userId: user.userId,
      reachId,
      title,
      body,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      scaleFactor: SCALE_FACTOR,
      exceededYear: threshold.exceededYear,
    });

    console.log(
      `📱 Notification sent to user ${user.userId} for reach ${reachId}`
    );

  } catch (error) {
    console.error("❌ Failed to send notification:", error);
  }
}