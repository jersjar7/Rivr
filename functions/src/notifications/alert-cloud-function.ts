// functions/src/notifications/alert-cloud-function.ts
// Simplified notification system - scaled return period alerts only

import {onSchedule} from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import {
  NOAAService,
  StreamflowData,
  StreamflowForecast,
} from "../noaa/noaa-service";

// Environment configuration
const SCALE_FACTOR = parseFloat(
  process.env.NOTIFICATION_SCALE_FACTOR || "25"
  // Default to 25 for dev
);
const CHECK_FREQUENCY =
  process.env.NOTIFICATION_CHECK_FREQUENCY_MINUTES || "1";
  // Default to 1 min

/**
 * Main Cloud Function: Check Flow Notifications
 * Checks favorite rivers for users with notifications enabled
 * Sends alerts when forecasted flows exceed scaled return periods
 */
export const checkFlowNotifications = onSchedule(
  {
    schedule: `every ${CHECK_FREQUENCY} minutes`,
    timeZone: "America/Denver",
  },
  async () => {
    console.log("🌊 Starting notification check...");
    console.log(`📊 Scale Factor: ${SCALE_FACTOR} ` +
      `(${SCALE_FACTOR === 25 ? "DEVELOPMENT" : "PRODUCTION"} mode)`);
    console.log(`⏰ Check Frequency: ${CHECK_FREQUENCY} minutes`);

    try {
      // Get all users with notifications enabled
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

      // Check each user's favorites
      for (const user of enabledUsers) {
        const userNotifications = await checkUserFavorites(user, noaaService);
        totalNotifications += userNotifications;
      }

      console.log(`📱 Total notifications sent: ${totalNotifications}`);
    } catch (error) {
      console.error("❌ Error in notification check:", error);
      throw error;
    }
  });

/**
 * Get all users who have notifications enabled and have FCM tokens
 * @return {Promise} Promise that resolves to array of enabled users
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
    console.log(`🔍 Checking favorites for user ${user.userId}`);

    // Get favorites from cached system
    const favoritesCache = await admin.firestore()
      .collection("forecastData")
      .doc("46083324")
      .get();

    const favorites: Array<Record<string, unknown>> = [];

    if (favoritesCache.exists) {
      const cacheData = favoritesCache.data();
      try {
        const apiData = JSON.parse(cacheData?.apiData || "{}");
        if (apiData.favorites && Array.isArray(apiData.favorites)) {
          const userFavorites = apiData.favorites.filter(
            (fav: Record<string, unknown>) => fav.userId === user.userId
          );
          favorites.push(...userFavorites);
        }
      } catch (parseError) {
        console.log(`⚠️ Error parsing cached favorites: ${parseError}`);
      }
    }

    // Fallback: check individual favorites collection
    if (favorites.length === 0) {
      const favoritesSnapshot = await admin.firestore()
        .collection("favorites")
        .where("userId", "==", user.userId)
        .get();

      favorites.push(...favoritesSnapshot.docs.map((doc) => doc.data()));
    }

    console.log(`📋 User ${user.userId} has ${favorites.length} favorites`);

    if (favorites.length === 0) {
      console.log(`👤 User ${user.userId} has no favorites`);
      return 0;
    }

    let notificationsSent = 0;

    // Check each favorite station
    for (const favorite of favorites) {
      // Skip if stationId is not valid
      if (!favorite.stationId ||
          (typeof favorite.stationId !== "number" &&
           typeof favorite.stationId !== "string")) {
        console.log("⚠️ Invalid stationId for favorite: " +
          `${JSON.stringify(favorite)}`);
        continue;
      }

      const stationId = favorite.stationId as number;
      const riverName = (favorite.name as string) ||
        (favorite.originalApiName as string) || "Unknown River";

      console.log(`🔍 Checking station: ${stationId} (${riverName})`);

      try {
        // Get current forecast data
        const streamflowData = await noaaService.fetchStreamflowData(
          stationId.toString(),
          true // Include forecasts
        );

        if (!streamflowData) {
          console.log(`⚠️ No data available for station ${stationId}`);
          continue;
        }

        // Check if forecast exceeds scaled return period threshold
        const shouldSendNotification = await checkForecastThreshold(
          stationId.toString(),
          streamflowData
        );

        if (shouldSendNotification) {
          const success = await sendNotification(
            user,
            stationId.toString(),
            streamflowData,
            riverName
          );

          if (success) {
            notificationsSent++;
            console.log(`✅ Notification sent for ${riverName}`);
          }
        }
      } catch (stationError) {
        console.error(`❌ Error checking station ${stationId}:`,
          stationError);
      }
    }

    return notificationsSent;
  } catch (error) {
    console.error(`❌ Error checking favorites for user ${user.userId}:`,
      error);
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
    const baseThreshold = returnPeriodData[2] ||
      returnPeriodData[5] || 1000;
    const scaledThreshold = baseThreshold / SCALE_FACTOR;

    console.log(
      `🎯 Reach ${reachId}: base threshold=${baseThreshold}, ` +
      `scaled=${scaledThreshold} (÷${SCALE_FACTOR} for ` +
      `${SCALE_FACTOR === 25 ? "DEV" : "PROD"} testing)`
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
      await admin.firestore().collection("returnPeriodCache").doc(reachId)
        .set({
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
 * @param {string} riverName - Name of the river
 * @return {Promise<boolean>} True if notification sent successfully
 */
async function sendNotification(
  user: {userId: string; fcmToken: string},
  reachId: string,
  streamflowData: StreamflowData,
  riverName: string
): Promise<boolean> {
  try {
    // Get max flow safely
    const maxFlow = streamflowData.forecast ?
      getMaxForecastFlow(streamflowData.forecast) : 0;

    const notificationBody = `${riverName} forecast is crossing ` +
      `elevated levels (${Math.round(maxFlow)} cfs)`;

    const message = {
      token: user.fcmToken,
      notification: {
        title: "🌊 High Flow Alert",
        body: notificationBody,
      },
      data: {
        type: "flow_alert",
        reachId: reachId,
        riverName: riverName,
        maxFlow: String(maxFlow),
        scaleFactor: String(SCALE_FACTOR),
        timestamp: new Date().toISOString(),
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
            alert: {
              title: "🌊 High Flow Alert",
              body: notificationBody,
            },
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    await admin.messaging().send(message);

    console.log(
      `📱 Notification sent to user ${user.userId} for reach: ` +
      `${riverName} (${Math.round(maxFlow)} cfs, scale ÷${SCALE_FACTOR})`
    );

    return true;
  } catch (error) {
    console.error(`Error sending notification for reach ${reachId}:`, error);
    return false;
  }
}

