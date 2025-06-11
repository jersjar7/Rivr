// Temporary fix for functions/src/index.ts
// Comment out the auth functions that are failing to deploy

// functions/src/index.ts - Temporarily disable auth functions

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

// v2 Firestore triggers
import {
  onDocumentWritten,
  FirestoreEvent,
} from "firebase-functions/v2/firestore";

import {NOAAService, StreamflowData} from "./noaa/noaa-service";

// v1 Auth triggers + types - COMMENTED OUT TEMPORARILY
// import {auth} from "firebase-functions/v1";
// import type {UserRecord} from "firebase-admin/auth";

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

// Test scheduled function (v2)
export const testScheduledFunction = onSchedule(
  "every 5 minutes",
  async (event: ScheduledEvent): Promise<void> => {
    logger.info("Scheduled function test executed at:",
      new Date().toISOString());
    const db = admin.firestore();
    await db.collection("test_logs").add({
      message: "Scheduled function executed",
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      scheduleTime: event.scheduleTime,
      jobName: event.jobName,
    });
  }
);

// ===== ENHANCED NOAA INTEGRATION FUNCTIONS =====

// Enhanced flow monitoring with NOAA service
export const monitorFlowConditions = onSchedule({
  schedule: "every 30 minutes",
  timeZone: "America/Denver",
}, async (event: ScheduledEvent): Promise<void> => {
  logger.info("Flow monitoring triggered:", event);
  
  try {
    const noaaService = new NOAAService();
    
    // 1. Get all monitored reaches from user thresholds
    const monitoredReaches = await noaaService.getUserMonitoredReaches();
    logger.info(`Monitoring ${monitoredReaches.length} reaches`);
    
    if (monitoredReaches.length === 0) {
      logger.info("No reaches to monitor - no active user thresholds");
      return;
    }
    
    // 2. Fetch current flow data for all monitored reaches
    const flowDataResults = await noaaService.fetchMultipleReaches(monitoredReaches);
    logger.info(`Successfully fetched data for ${flowDataResults.length} reaches`);
    
    // 3. Log summary for thesis metrics
    await logMonitoringSummary(flowDataResults);
    
    // 4. Trigger threshold evaluation (this will be implemented in Phase 4)
    for (const flowData of flowDataResults) {
      // This will trigger the processThresholdUpdates function via Firestore
      // The data is already cached by the NOAA service
      logger.info(`Updated data for reach ${flowData.reachId}: ${flowData.currentFlow} ${flowData.unit}`);
    }
    
    logger.info("Flow monitoring completed successfully");
  } catch (error) {
    logger.error("Flow monitoring error:", error);
    // Record error for thesis analysis
    await recordMonitoringError(error);
  }
});

// Enhanced threshold processing with NOAA data
export const processThresholdUpdates = onDocumentWritten(
  "noaaFlowCache/{stationId}",
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  async (event: FirestoreEvent<any, {stationId: string}>): Promise<void> => {
    const stationId = event.params.stationId;
    
    logger.info(`Processing threshold updates for station: ${stationId}`);
    
    try {
      // Get the updated flow data
      const flowData = event.data?.after?.data();
      if (!flowData) {
        logger.warn(`No flow data found for station: ${stationId}`);
        return;
      }
      
      // TODO: Phase 4 - Implement threshold evaluation logic here
      // 1. Query user thresholds for this station
      // 2. Evaluate if any thresholds are exceeded
      // 3. Generate notifications for triggered thresholds
      
      logger.info(`Flow data received for ${stationId}:`, {
        currentFlow: flowData.currentFlow,
        unit: flowData.unit,
        flowCategory: flowData.flowCategory,
        changePercent: flowData.changePercent,
      });
      
    } catch (error) {
      logger.error(`Error processing thresholds for ${stationId}:`, error);
    }
  }
);

// ===== NEW NOAA API INTEGRATION FUNCTIONS =====

// Test NOAA service integration
export const testNOAAIntegration = onCall(
  async (request: CallableRequest<{reachId: string}>): 
    Promise<{success: boolean; data?: StreamflowData; error?: string}> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }
    
    const {reachId} = request.data;
    if (!reachId) {
      throw new HttpsError("invalid-argument", "reachId is required");
    }
    
    try {
      logger.info(`Testing NOAA integration for reach: ${reachId}`);
      
      const noaaService = new NOAAService();
      const flowData = await noaaService.fetchStreamflowData(reachId, true);
      
      if (flowData) {
        logger.info(`NOAA test successful for reach ${reachId}`);
        return {success: true, data: flowData};
      } else {
        logger.warn(`No data returned for reach ${reachId}`);
        return {success: false, error: "No data returned from NOAA API"};
      }
    } catch (error) {
      logger.error(`NOAA test failed for reach ${reachId}:`, error);
      throw new HttpsError("internal", `NOAA API test failed: ${error}`);
    }
  }
);

// Get current flow data for Flutter app (compatible with existing ForecastRemoteDataSource)
export const getCurrentFlowData = onCall(
  async (request: CallableRequest<{
    reachId: string; 
    includeForecast?: boolean;
  }>): Promise<{
    success: boolean; 
    data?: any; // Compatible with existing Dart models
    error?: string;
  }> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }
    
    const {reachId, includeForecast = false} = request.data;
    
    try {
      const noaaService = new NOAAService();
      const flowData = await noaaService.fetchStreamflowData(reachId, includeForecast);
      
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

// Batch fetch for multiple reaches (for Flutter app efficiency)
export const batchFetchFlowData = onCall(
  async (request: CallableRequest<{
    reachIds: string[];
    maxResults?: number;
  }>): Promise<{
    success: boolean;
    data?: Array<{reachId: string; flowData: any}>;
    errors?: Array<{reachId: string; error: string}>;
  }> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }
    
    const {reachIds, maxResults = 20} = request.data;
    
    if (!reachIds || reachIds.length === 0) {
      throw new HttpsError("invalid-argument", "reachIds array is required");
    }
    
    if (reachIds.length > maxResults) {
      throw new HttpsError(
        "invalid-argument", 
        `Too many reaches requested. Maximum: ${maxResults}`
      );
    }
    
    try {
      const noaaService = new NOAAService();
      const flowDataResults = await noaaService.fetchMultipleReaches(reachIds);
      
      const successfulResults = flowDataResults.map(flowData => ({
        reachId: flowData.reachId,
        flowData: transformToFlutterFormat(flowData),
      }));
      
      const errors = reachIds
        .filter(reachId => !flowDataResults.find(fd => fd.reachId === reachId))
        .map(reachId => ({reachId, error: "No data available"}));
      
      return {
        success: true,
        data: successfulResults,
        errors: errors.length > 0 ? errors : undefined,
      };
    } catch (error) {
      logger.error("Batch fetch error:", error);
      throw new HttpsError("internal", "Batch fetch failed");
    }
  }
);

// ===== UTILITY FUNCTIONS =====

// Transform Cloud Functions data to Flutter-compatible format
function transformToFlutterFormat(flowData: StreamflowData): any {
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
    forecast: flowData.forecast?.map(f => ({
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

// Log monitoring summary for thesis metrics
async function logMonitoringSummary(flowDataResults: StreamflowData[]): Promise<void> {
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
      significantChanges: flowDataResults.filter(data => 
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

// Record monitoring errors for thesis analysis
async function recordMonitoringError(error: any): Promise<void> {
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

// ===== COMPATIBILITY TESTING FUNCTIONS =====

// Test compatibility with existing Flutter app
export const testFlutterCompatibility = onCall(
  async (request: CallableRequest<{reachId: string}>): 
    Promise<{compatible: boolean; details: any}> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }
    
    const {reachId} = request.data;
    
    try {
      const noaaService = new NOAAService();
      const flowData = await noaaService.fetchStreamflowData(reachId, true);
      
      if (!flowData) {
        return {compatible: false, details: {error: "No data available"}};
      }
      
      const flutterFormat = transformToFlutterFormat(flowData);
      
      // Validate required fields for Flutter compatibility
      const requiredFields = ["reachId", "validTime", "flow", "unit", "retrievedAt"];
      const missingFields = requiredFields.filter(field => !(field in flutterFormat));
      
      return {
        compatible: missingFields.length === 0,
        details: {
          data: flutterFormat,
          missingFields: missingFields.length > 0 ? missingFields : undefined,
          dataTypes: {
            flow: typeof flutterFormat.flow,
            unit: typeof flutterFormat.unit,
            validTime: typeof flutterFormat.validTime,
          },
        },
      };
    } catch (error) {
      return {
        compatible: false, 
        details: {error: error instanceof Error ? error.message : String(error)},
      };
    }
  }
);

// ===== USER MANAGEMENT FUNCTIONS - TEMPORARILY DISABLED =====

/*
// TEMPORARILY COMMENTED OUT - These functions are failing to deploy
// We'll fix them after the core notification system is working

// Initialize preferences on user creation (v1)
export const initializeUserPreferences = auth.user().onCreate(
  async (user: UserRecord): Promise<void> => {
    const db = admin.firestore();
    await db.collection("notificationPreferences").doc(user.uid).set({
      emergencyAlerts: true,
      activityAlerts: false,
      informationAlerts: false,
      frequency: "realtime",
      quietHours: {enabled: false, start: "22:00", end: "07:00"},
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    logger.info(`Initialized preferences for user ${user.uid}`);
  }
);

// Cleanup on user deletion (v1)
export const cleanupUserData = auth.user().onDelete(
  async (user: UserRecord): Promise<void> => {
    const db = admin.firestore();
    const batch = db.batch();
    batch.delete(db.collection("notificationPreferences").doc(user.uid));
    const thrSnap = await db
      .collection("userThresholds")
      .doc(user.uid)
      .collection("thresholds")
      .get();
    thrSnap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    logger.info(`Cleaned up data for user ${user.uid}`);
  }
);
*/

// ===== THESIS-SPECIFIC FUNCTIONS =====

// Record metrics (v2)
export const recordThesisMetrics = onCall(
  async (
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    request: CallableRequest<{eventType: string; metadata: any}>
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

// Test notification (v2)
export const sendTestNotification = onCall(
  async (request: CallableRequest):
    Promise<{success: boolean; message: string}> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }
    logger.info(`Test notification by ${request.auth.uid}`);
    return {success: true, message: "Placeholder sent"};
  }
);

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

// ===== MANUAL USER SETUP FUNCTION (Replacement for auth triggers) =====

// Manual function to initialize user preferences when auth triggers fail
export const manualInitializeUserPreferences = onCall(
  async (request: CallableRequest): Promise<{success: boolean}> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const db = admin.firestore();
    const userId = request.auth.uid;

    // Check if preferences already exist
    const existingPrefs = await db
      .collection("notificationPreferences")
      .doc(userId)
      .get();

    if (existingPrefs.exists) {
      return {success: true}; // Already initialized
    }

    // Create default preferences
    await db.collection("notificationPreferences").doc(userId).set({
      emergencyAlerts: true,
      activityAlerts: false,
      informationAlerts: false,
      frequency: "realtime",
      quietHours: {enabled: false, start: "22:00", end: "07:00"},
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`Manually initialized preferences for user ${userId}`);
    return {success: true};
  }
);
