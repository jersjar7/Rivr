// functions/src/notifications/alert-cloud-function.ts
// SUPER SIMPLE notification system - just one toggle, favorites only

import {onSchedule} from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import {
  NOAAService,
  StreamflowData,
  StreamflowForecast,
} from "../noaa/noaa-service";

// Firebase Admin is initialized in index.ts
// Note: db and messaging are accessed inside functions
// to avoid module-level initialization

// Environment configuration
const SCALE_FACTOR = parseFloat(
  process.env.NOTIFICATION_SCALE_FACTOR || "1"
);
const CHECK_FREQUENCY =
  process.env.NOTIFICATION_CHECK_FREQUENCY_MINUTES || "360";

/**
 * Main Cloud Function: Check Flow Notifications
 * Super simple: Check favorite rivers for users with notifications enabled
 */
export const checkFlowNotifications = onSchedule(
  {
    schedule: `every ${CHECK_FREQUENCY} minutes`,
    timeZone: "America/Denver",
  },
  async (_event) => {
    console.log(
      `🌊 Starting notification check (scale factor: ${SCALE_FACTOR})...`
    );

    try {
      // Step 1: Get all users with notifications enabled
      const enabledUsers = await getEnabledUsers();
      console.log(
        `👥 Found ${enabledUsers.length} users with notifications enabled`
      );

      if (enabledUsers.length === 0) {
        console.log("📱 No users with notifications enabled");
        return;
      }

      let totalNotifications = 0;
      const noaaService = new NOAAService();

      // Step 2: For each user, check their favorites
      for (const user of enabledUsers) {
        const userNotifications = await checkUserFavorites(
          user,
          noaaService
        );
        totalNotifications += userNotifications;
      }

      console.log(`📱 Total notifications sent: ${totalNotifications}`);

      // Function completes successfully - no return value needed
    } catch (error) {
      console.error("❌ Error in notification check:", error);
      throw error;
    }
  });

/**
 * Get all users who have notifications enabled and have FCM tokens
 */
async function getEnabledUsers(): Promise<Array<{
  userId: string;
  fcmToken: string;
}>> {
  try {
    const users: Array<{userId: string; fcmToken: string}> = [];

    const usersSnapshot = await admin.firestore()
      .collection("users")
      .where("notificationsEnabled", "==", true)
      .get();

    usersSnapshot.forEach((doc) => {
      const userData = doc.data();
      if (userData.fcmToken) {
        users.push({
          userId: doc.id,
          fcmToken: userData.fcmToken,
        });
      }
    });

    return users;
  } catch (error) {
    console.error("Error getting enabled users:", error);
    return [];
  }
}

/**
 * Check favorites for a specific user
 * @param {Object} user - User object with userId and fcmToken
 * @param {NOAAService} noaaService - NOAA service instance
 * @return {Promise<number>} Number of notifications sent
 */
async function checkUserFavorites(
  user: {userId: string; fcmToken: string},
  noaaService: NOAAService
): Promise<number> {
  try {
    // Get user's favorites
    const favoritesSnapshot = await admin.firestore()
      .collection("favorites")
      .where("userId", "==", user.userId)
      .get();

    console.log(
      `📋 User ${user.userId} has ${favoritesSnapshot.docs.length} favorites`
    );

    if (favoritesSnapshot.empty) {
      console.log(`👤 User ${user.userId} has no favorites`);
      return 0;
    }

    let notificationsSent = 0;

    // Check each favorite reach
    for (const favoriteDoc of favoritesSnapshot.docs) {
      const favoriteData = favoriteDoc.data();
      const reachId = favoriteData.reachId;

      console.log(`🔍 Checking reach: ${reachId}`);

      try {
        // Get current forecast data
        const streamflowData = await noaaService.fetchStreamflowData(
          reachId,
          true // Include forecast
        );

        if (!streamflowData || !streamflowData.forecast) {
          console.log(`⚠️ No forecast data for reach: ${reachId}`);
          continue;
        }

        // Check if any forecast crosses scaled return period
        const shouldNotify = await checkForecastThreshold(
          reachId,
          streamflowData
        );

        if (shouldNotify) {
          await sendNotification(user, reachId, streamflowData);
          notificationsSent++;
        }
      } catch (error) {
        console.error(`Error checking reach ${reachId}:`, error);
      }
    }

    return notificationsSent;
  } catch (error) {
    console.error(`Error checking favorites for user ${user.userId}:`, error);
    return 0;
  }
}

/**
 * Check if forecast crosses scaled return period threshold
 * @param {string} reachId - The reach identifier
 * @param {StreamflowData} streamflowData - Streamflow data with forecasts
 * @return {Promise<boolean>} True if threshold is crossed
 */
async function checkForecastThreshold(
  reachId: string,
  streamflowData: StreamflowData
): Promise<boolean> {
  try {
    // Check if we have forecast data
    if (!streamflowData.forecast || streamflowData.forecast.length === 0) {
      console.log(`⚠️ No forecast data for reach: ${reachId}`);
      return false;
    }

    // Get return period data for this reach
    const returnPeriodData = await getReturnPeriods(reachId);
    if (!returnPeriodData) {
      console.log(`⚠️ No return period data for reach: ${reachId}`);
      return false;
    }

    // Calculate scaled threshold (divide by scale factor)
    const baseThreshold = returnPeriodData[2] || returnPeriodData[5] || 1000;
    const scaledThreshold = baseThreshold / SCALE_FACTOR;

    console.log(
      `🎯 Reach ${reachId}: base threshold=${baseThreshold}, ` +
      `scaled=${scaledThreshold} (factor=${SCALE_FACTOR})`
    );

    // Get maximum flow from short and medium range forecasts only
    const maxForecastFlow = getMaxForecastFlow(streamflowData.forecast);

    console.log(
      `📊 Reach ${reachId}: max forecast=${maxForecastFlow}, ` +
      `threshold=${scaledThreshold}`
    );

    // Check if max forecast exceeds scaled threshold
    return maxForecastFlow > scaledThreshold;
  } catch (error) {
    console.error(`Error checking threshold for reach ${reachId}:`, error);
    return false;
  }
}

/**
 * Get maximum flow from short and medium range forecasts only
 * @param {StreamflowForecast[]} forecasts - Array of forecast data
 * @return {number} Maximum flow value
 */
function getMaxForecastFlow(forecasts: StreamflowForecast[]): number {
  try {
    // Handle undefined or empty forecasts
    if (!forecasts || forecasts.length === 0) {
      console.log("⚠️ No forecasts provided");
      return 0;
    }

    // Filter for short and medium range only
    const relevantForecasts = forecasts.filter((f) =>
      f.forecastType === "short_range" || f.forecastType === "medium_range"
    );

    if (relevantForecasts.length === 0) {
      console.log("⚠️ No short/medium range forecasts found");
      return 0;
    }

    // Find maximum flow value
    const maxFlow = Math.max(...relevantForecasts.map((f) => f.flow || 0));

    console.log(
      `📈 Found ${relevantForecasts.length} short/medium forecasts, ` +
      `max flow: ${maxFlow}`
    );

    return maxFlow;
  } catch (error) {
    console.error("Error getting max forecast flow:", error);
    return 0;
  }
}

/**
 * Get return period data for a reach
 * @param {string} reachId - The reach identifier
 * @return {Promise<Record<number, number> | null>} Return period data or null
 */
async function getReturnPeriods(
  reachId: string
): Promise<Record<number, number> | null> {
  try {
    // Check cache first
    const cacheDoc = await admin.firestore()
      .collection("returnPeriodCache")
      .doc(reachId)
      .get();

    if (cacheDoc.exists) {
      const cacheData = cacheDoc.data();
      if (cacheData) {
        const cacheAge = Date.now() - (cacheData.cachedAt?.toMillis() || 0);
        const maxCacheAge = 7 * 24 * 60 * 60 * 1000; // 7 days

        if (cacheAge < maxCacheAge) {
          console.log(`💾 Using cached return periods for ${reachId}`);
          // Extract just the return period values
          return {
            2: cacheData[2] || cacheData.return_period_2 || 0,
            5: cacheData[5] || cacheData.return_period_5 || 0,
            10: cacheData[10] || cacheData.return_period_10 || 0,
            25: cacheData[25] || cacheData.return_period_25 || 0,
            50: cacheData[50] || cacheData.return_period_50 || 0,
            100: cacheData[100] || cacheData.return_period_100 || 0,
          };
        }
      }
    }

    // Fetch fresh data
    console.log(`🌐 Fetching fresh return periods for ${reachId}`);
    const noaaService = new NOAAService();
    const returnPeriodData = await noaaService.fetchReturnPeriod(reachId);

    if (returnPeriodData) {
      // Cache the data
      await admin.firestore().collection("returnPeriodCache").doc(reachId).set({
        ...returnPeriodData.flowValues,
        cachedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return returnPeriodData.flowValues;
    }

    return null;
  } catch (error) {
    console.error(`Error getting return periods for ${reachId}:`, error);
    return null;
  }
}

/**
 * Send notification to user
 * @param {Object} user - User object with userId and fcmToken
 * @param {string} reachId - The reach identifier
 * @param {StreamflowData} streamflowData - Streamflow data with forecasts
 * @return {Promise<void>} Promise that resolves when notification is sent
 */
async function sendNotification(
  user: {userId: string; fcmToken: string},
  reachId: string,
  streamflowData: StreamflowData
): Promise<void> {
  try {
    // Get reach name (you might want to store this in your reaches collection)
    const reachName = await getReachName(reachId);

    // Get max flow safely
    const maxFlow = streamflowData.forecast ?
      getMaxForecastFlow(streamflowData.forecast) : 0;

    const message = {
      token: user.fcmToken,
      notification: {
        title: "🌊 High Flow Alert",
        body: `${reachName} forecast is crossing elevated levels`,
      },
      data: {
        type: "flow_alert",
        reachId: reachId,
        reachName: reachName,
        maxFlow: String(maxFlow),
        scaleFactor: String(SCALE_FACTOR),
        deepLink: `rivr://reach/${reachId}`,
      },
      android: {
        notification: {
          channelId: "flow_alerts",
          priority: "high" as const,
          color: "#FF6B6B",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    await admin.messaging().send(message);

    console.log(
      `📱 Notification sent to user ${user.userId} for reach: ${reachName}`
    );

    // Log notification to database
    await admin.firestore().collection("notificationLog").add({
      userId: user.userId,
      reachId: reachId,
      reachName: reachName,
      type: "flow_alert",
      scaleFactor: SCALE_FACTOR,
      maxFlow: maxFlow,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      sent: true,
    });
  } catch (error) {
    console.error("Error sending notification:", error);

    // Log failed notification
    await admin.firestore().collection("notificationLog").add({
      userId: user.userId,
      reachId: reachId,
      type: "flow_alert",
      scaleFactor: SCALE_FACTOR,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      sent: false,
      error: error instanceof Error ? error.message : "Unknown error",
    });
  }
}

/**
 * Get reach name (implement based on your data structure)
 * @param {string} reachId - The reach identifier
 * @return {Promise<string>} Reach name or default name
 */
async function getReachName(reachId: string): Promise<string> {
  try {
    const reachDoc = await admin
      .firestore()
      .collection("reaches")
      .doc(reachId)
      .get();
    if (reachDoc.exists) {
      return reachDoc.data()?.name || `Reach ${reachId}`;
    }
    return `Reach ${reachId}`;
  } catch (error) {
    console.error(`Error getting reach name for ${reachId}:`, error);
    return `Reach ${reachId}`;
  }
}

