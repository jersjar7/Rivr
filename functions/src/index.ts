// functions/src/index.ts - Clean version for simplified notification system

import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

// v2 HTTP & Callable triggers
import {
  onRequest,
  onCall,
  HttpsError,
  CallableRequest,
} from "firebase-functions/v2/https";

import {
  onSchedule,
  ScheduledEvent,
} from "firebase-functions/v2/scheduler";

import {NOAAService, StreamflowData} from "./noaa/noaa-service";

// ===== SIMPLIFIED NOTIFICATION SYSTEM =====
// Import the simplified notification function
import {
  checkFlowNotifications,
} from "./notifications/alert-cloud-function";

// Export the simplified notification function
export {checkFlowNotifications};

// Initialize Firebase Admin SDK
admin.initializeApp();

// ===== BASIC SETUP FUNCTIONS FOR TESTING =====

// Health check
export const healthCheck = onRequest((req, res) => {
  res.json({
    status: "healthy",
    timestamp: new Date().toISOString(),
    project: "rivr-official",
    version: "1.0.0",
  });
});

// Test database connection
export const testDatabase = onRequest(async (req, res) => {
  try {
    const db = admin.firestore();
    const testDocRef = await db.collection("test").add({
      message: "Cloud Functions connected successfully",
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    const docSnap = await testDocRef.get();
    res.json({
      status: "success",
      docId: testDocRef.id,
      data: docSnap.data(),
    });
  } catch (error) {
    logger.error("Database test failed:", error);
    res.status(500).json({
      status: "error",
      message: error instanceof Error ? error.message : "Unknown error",
    });
  }
});

// ===== DATA CACHING (Keep for forecast data) =====

// Simplified flow monitoring - just cache data, notifications handled separately
export const cacheFlowData = onSchedule({
  schedule: "every 60 minutes", // Cache data less frequently
  timeZone: "America/Denver",
}, async (event: ScheduledEvent): Promise<void> => {
  logger.info("Flow data caching triggered:", event);

  try {
    const noaaService = new NOAAService();

    // Get all monitored reaches from favorites (simplified approach)
    const monitoredReaches = await getMonitoredReachesFromFavorites();
    logger.info(`Caching data for ${monitoredReaches.length} reaches`);

    if (monitoredReaches.length === 0) {
      logger.info("No reaches to cache - no favorites found");
      return;
    }

    // Fetch and cache flow data
    const flowDataResults = await noaaService.fetchMultipleReaches(
      monitoredReaches
    );
    logger.info(
      `Successfully cached data for ${flowDataResults.length} reaches`
    );

    // Log summary for thesis metrics
    await logMonitoringSummary(flowDataResults);

    logger.info("Flow data caching completed successfully");
  } catch (error) {
    logger.error("Flow data caching error:", error);
    await recordMonitoringError(error);
  }
});

/**
 * Helper function to get reaches from all user favorites
 * @return {Promise<string[]>} Array of reach IDs
 */
async function getMonitoredReachesFromFavorites(): Promise<string[]> {
  try {
    const db = admin.firestore();
    const favoritesSnapshot = await db.collection("favorites").get();

    const reachIds = new Set<string>();
    favoritesSnapshot.docs.forEach((doc) => {
      const favorite = doc.data();
      if (favorite.reachId) {
        reachIds.add(favorite.reachId);
      }
    });

    return Array.from(reachIds);
  } catch (error) {
    logger.error("Error getting monitored reaches from favorites:", error);
    return [];
  }
}

// ===== EXISTING NOAA API INTEGRATION FUNCTIONS =====

// Get current flow data for Flutter app (compatible with existing models)
export const getCurrentFlowData = onCall(
  async (request: CallableRequest<{
    reachId: string;
    includeForecast?: boolean;
  }>): Promise<{
    success: boolean;
    data?: Record<string, unknown>; // Compatible with existing Dart models
    error?: string;
  }> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const {reachId, includeForecast = false} = request.data;

    try {
      const noaaService = new NOAAService();
      const flowData = await noaaService.fetchStreamflowData(
        reachId,
        includeForecast
      );

      if (!flowData) {
        return {success: false, error: "No data available"};
      }

      // Transform to format compatible with existing Dart models
      const compatibleData = transformToFlutterFormat(flowData);

      return {success: true, data: compatibleData};
    } catch (error) {
      logger.error(`Error fetching flow data for ${reachId}:`, error);
      throw new HttpsError("internal", "Failed to fetch flow data");
    }
  }
);

// ===== UTILITY FUNCTIONS =====

/**
 * Transform Cloud Functions data to Flutter-compatible format
 * @param {StreamflowData} flowData - The flow data to transform
 * @return {Record<string, unknown>} Transformed data compatible with Flutter
 */
function transformToFlutterFormat(
  flowData: StreamflowData
): Record<string, unknown> {
  return {
    // Compatible with existing ForecastModel structure
    reachId: flowData.reachId,
    validTime: flowData.validTime,
    flow: flowData.currentFlow,
    unit: flowData.unit,
    retrievedAt: flowData.retrievedAt.toISOString(),
    source: flowData.source,

    // Additional notification-specific data
    flowCategory: flowData.flowCategory,
    changePercent: flowData.changePercent,
    previousFlow: flowData.previousFlow,

    // Forecast data (if available)
    forecast: flowData.forecast?.map((f) => ({
      validTime: f.validTime,
      flow: f.flow,
      forecastType: f.forecastType,
      member: f.member,
    })),

    // Return period data (if available)
    returnPeriod: flowData.returnPeriod ? {
      reachId: flowData.returnPeriod.reachId,
      flowValues: flowData.returnPeriod.flowValues,
      unit: flowData.returnPeriod.unit,
      retrievedAt: flowData.returnPeriod.retrievedAt.toISOString(),
    } : undefined,
  };
}

/**
 * Log monitoring summary for thesis metrics
 * @param {StreamflowData[]} flowDataResults - Array of flow data results
 * @return {Promise<void>} Promise that resolves when logging is complete
 */
async function logMonitoringSummary(
  flowDataResults: StreamflowData[]
): Promise<void> {
  try {
    const db = admin.firestore();

    const summary = {
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      totalReaches: flowDataResults.length,
      successfulFetches: flowDataResults.length,
      flowCategories: flowDataResults.reduce((acc, data) => {
        const category = data.flowCategory || "Unknown";
        acc[category] = (acc[category] || 0) + 1;
        return acc;
      }, {} as Record<string, number>),
      significantChanges: flowDataResults.filter((data) =>
        Math.abs(data.changePercent || 0) > 20
      ).length,
      averageFlow: flowDataResults.reduce((sum, data) =>
        sum + data.currentFlow, 0
      ) / flowDataResults.length,
    };

    await db.collection("thesis_metrics")
      .doc("monitoring_summaries")
      .collection("daily")
      .add(summary);

  } catch (error) {
    logger.error("Error logging monitoring summary:", error);
  }
}

/**
 * Record monitoring errors for thesis analysis
 * @param {unknown} error - The error to record
 * @return {Promise<void>} Promise that resolves when error is recorded
 */
async function recordMonitoringError(error: unknown): Promise<void> {
  try {
    const db = admin.firestore();
    await db.collection("thesis_metrics")
      .doc("monitoring_errors")
      .collection("errors")
      .add({
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        error: error instanceof Error ? error.message : String(error),
        stack: error instanceof Error ? error.stack : undefined,
      });
  } catch (logError) {
    logger.error("Error recording monitoring error:", logError);
  }
}

// ===== USER MANAGEMENT FUNCTIONS =====

// Update FCM token (v2)
export const updateFCMToken = onCall(
  async (request: CallableRequest<{token: string}>):
    Promise<{success: boolean}> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }
    const {token} = request.data;
    await admin.firestore().collection("users").doc(request.auth.uid).update({
      fcmToken: token,
      tokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {success: true};
  }
);

// Manual function to initialize user preferences
export const manualInitializeUserPreferences = onCall(
  async (request: CallableRequest): Promise<{success: boolean}> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const db = admin.firestore();
    const userId = request.auth.uid;

    // Check if user document already exists
    const existingUser = await db.collection("users").doc(userId).get();

    if (!existingUser.exists) {
      // Create basic user document with notification settings
      await db.collection("users").doc(userId).set({
        notificationsEnabled: true, // Default to enabled for simplified system
        fcmToken: null, // Will be updated when app gets token
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      // Update existing user to have notification settings if missing
      const userData = existingUser.data();
      if (userData && userData.notificationsEnabled === undefined) {
        await db.collection("users").doc(userId).update({
          notificationsEnabled: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    logger.info(`Initialized simplified user settings for ${userId}`);
    return {success: true};
  }
);

// ===== THESIS-SPECIFIC FUNCTIONS =====

// Record metrics (v2)
export const recordThesisMetrics = onCall(
  async (
    request: CallableRequest<{eventType: string; metadata: unknown}>
  ): Promise<{success: boolean}> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }
    const {data} = request;
    const db = admin.firestore();
    await db.collection("thesis_metrics").add({
      userId: request.auth.uid,
      eventType: data.eventType,
      metadata: data.metadata,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {success: true};
  }
);