// functions/src/notifications/alert-cloud-function.ts

import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { AlertEngine, AlertGenerationResult } from './alert-engine';
import { FlowData } from '../types/flow-data';
import { FlowUnit } from '../types/flow-unit';
import { NotificationPreferences, AlertContext, UserThreshold } from '../types/notification-types';
import { ReturnPeriod } from '../types/return-period';


// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Cloud Function: Monitor Flow Conditions
 * 
 * Scheduled function that runs every 30 minutes to check flow conditions
 * and generate alerts for users based on their preferences and thresholds.
 */
export const monitorFlowConditions = functions.pubsub
  .schedule('*/30 * * * *') // Every 30 minutes for thesis demonstration
  .timeZone('America/Denver') // Mountain Time for typical western US rivers
  .onRun(async (context) => {
    
    console.log('🌊 Starting flow condition monitoring...');
    
    try {
      // Step 1: Get all active user configurations
      const userConfigs = await getUserConfigurations();
      console.log(`📊 Found ${userConfigs.length} active user configurations`);

      // Step 2: Get unique reaches that need monitoring
      const reachIds = getUniqueReachIds(userConfigs);
      console.log(`🎯 Monitoring ${reachIds.length} unique reaches`);

      // Step 3: Fetch current flow data from NOAA (placeholder for actual implementation)
      const flowDataMap = await fetchCurrentFlowData(reachIds);
      console.log(`💧 Retrieved flow data for ${flowDataMap.size} reaches`);

      // Step 4: Get return period data for flow classification
      const returnPeriodMap = await getReturnPeriodData(reachIds);

      // Step 5: Generate alerts for each user/reach combination
      const allAlerts: AlertGenerationResult[] = [];
      
      for (const userConfig of userConfigs) {
        const userAlerts = await generateAlertsForUser(
          userConfig,
          flowDataMap,
          returnPeriodMap
        );
        allAlerts.push(...userAlerts);
      }

      console.log(`🚨 Generated ${allAlerts.length} total alerts`);

      // Step 6: Send notifications and record history
      const sentCount = await sendNotifications(allAlerts);
      console.log(`📱 Successfully sent ${sentCount} notifications`);

      // Step 7: Update monitoring statistics for thesis metrics
      await updateMonitoringStats(allAlerts.length, sentCount);

      return { 
        success: true, 
        alertsGenerated: allAlerts.length, 
        notificationsSent: sentCount 
      };

    } catch (error) {
      console.error('❌ Error in flow monitoring:', error);
      throw new functions.https.HttpsError('internal', 'Flow monitoring failed');
    }
  });

/**
 * Manual Alert Trigger for Thesis Demonstration
 * 
 * HTTP function to manually trigger alerts for demonstration purposes
 */
export const triggerDemoAlert = functions.https.onCall(async (data, context) => {
  
  // Verify authentication for thesis demo
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const { reachId, flow, unit, scenario } = data;

  console.log(`🎓 Triggering demo alert for thesis: ${scenario || 'Demo scenario'}`);

  try {
    // Create demo flow data
    const demoFlowData: FlowData = {
      reachId: reachId || 'demo-reach',
      flow: flow || 600, // Default to high flow for demo
      unit: unit || FlowUnit.CFS,
      timestamp: new Date(),
      source: 'MANUAL'
    };

    // Get return period for classification (or use demo data)
    const returnPeriod = await getReturnPeriodForReach(demoFlowData.reachId);

    // Generate demo alert
    const demoAlert = AlertEngine.generateDemoAlert(
      demoFlowData,
      returnPeriod ?? undefined,
      scenario || 'Thesis demonstration of real-time NOAA data integration'
    );

    // Send the demo notification
    if (demoAlert.shouldSendAlert && context.auth.uid) {
      await sendSingleNotification(demoAlert, context.auth.uid);
      
      // Record demo alert in history
      await recordNotificationHistory(demoAlert, context.auth.uid);
    }

    console.log(`✅ Demo alert sent successfully`);

    return {
      success: true,
      alertType: demoAlert.alertType,
      message: demoAlert.alertMessage,
      category: demoAlert.classification.category
    };

  } catch (error) {
    console.error('❌ Error sending demo alert:', error);
    throw new functions.https.HttpsError('internal', 'Demo alert failed');
  }
});

/**
 * Helper Functions
 */

async function getUserConfigurations(): Promise<Array<{
  userId: string;
  preferences: NotificationPreferences;
  thresholds: UserThreshold[];
}>> {
  
  const configs: Array<{
    userId: string;
    preferences: NotificationPreferences;
    thresholds: UserThreshold[];
  }> = [];

  // Get all users with notification preferences
  const preferencesSnapshot = await db.collection('notificationPreferences').get();
  
  for (const prefDoc of preferencesSnapshot.docs) {
    const preferences = prefDoc.data() as NotificationPreferences;
    
    // Skip inactive users
    if (!preferences.emergencyAlerts && !preferences.activityAlerts && !preferences.informationAlerts) {
      continue;
    }

    // Get user's thresholds
    const thresholdsSnapshot = await db
      .collection('userThresholds')
      .where('userId', '==', preferences.userId)
      .where('enabled', '==', true)
      .get();

    const thresholds = thresholdsSnapshot.docs.map(doc => {
      const data = doc.data();
      // Ensure all required properties are present
      return {
        ...data,
        thresholdType: data.thresholdType ?? 'default',
        createdAt: data.createdAt ?? new Date(),
        updatedAt: data.updatedAt ?? new Date()
      } as UserThreshold;
    });

    configs.push({
      userId: preferences.userId,
      preferences,
      thresholds
    });
  }

  return configs;
}

function getUniqueReachIds(userConfigs: Array<{ preferences: NotificationPreferences; thresholds: UserThreshold[] }>): string[] {
  const reachIds = new Set<string>();
  
  userConfigs.forEach(config => {
    // Add reaches from user preferences
    config.preferences.enabledReaches.forEach(id => reachIds.add(id));
    
    // Add reaches from user thresholds
    config.thresholds.forEach(threshold => reachIds.add(threshold.reachId));
  });

  return Array.from(reachIds);
}

async function fetchCurrentFlowData(reachIds: string[]): Promise<Map<string, FlowData>> {
  // Placeholder: In the full implementation, this would call your NOAA service
  // For now, we'll simulate with cached data or return demo data
  
  const flowDataMap = new Map<string, FlowData>();

  for (const reachId of reachIds) {
    // Try to get cached NOAA data
    const cacheDoc = await db.collection('noaaFlowCache').doc(reachId).get();
    
    if (cacheDoc.exists) {
      const cacheData = cacheDoc.data();
      const flowData: FlowData = {
        reachId,
        flow: cacheData?.latestFlow?.flow || 0,
        unit: cacheData?.latestFlow?.unit || FlowUnit.CFS,
        timestamp: cacheData?.latestFlow?.timestamp?.toDate() || new Date(),
        source: 'NOAA'
      };
      flowDataMap.set(reachId, flowData);
    } else {
      console.log(`⚠️ No cached data for reach ${reachId}, skipping`);
    }
  }

  return flowDataMap;
}

async function getReturnPeriodData(reachIds: string[]): Promise<Map<string, ReturnPeriod>> {
  const returnPeriodMap = new Map<string, ReturnPeriod>();

  for (const reachId of reachIds) {
    const returnPeriod = await getReturnPeriodForReach(reachId);
    if (returnPeriod) {
      returnPeriodMap.set(reachId, returnPeriod);
    }
  }

  return returnPeriodMap;
}

async function getReturnPeriodForReach(reachId: string): Promise<ReturnPeriod | null> {
  // This would fetch from your existing return period cache or API
  // For demo purposes, return a sample return period
  
  const doc = await db.collection('returnPeriodCache').doc(reachId).get();
  
  if (doc.exists) {
    const data = doc.data();
    return {
      reachId,
      flowValues: data?.flowValues || {},
      unit: data?.unit || FlowUnit.CFS,
      retrievedAt: data?.retrievedAt?.toDate() || new Date()
    };
  }

  // Return demo data if no cached data exists
  return {
    reachId,
    flowValues: {
      2: 150,
      5: 250,
      10: 350,
      25: 500,
      50: 650,
      100: 800
    },
    unit: FlowUnit.CFS,
    retrievedAt: new Date()
  };
}

async function generateAlertsForUser(
  userConfig: { userId: string; preferences: NotificationPreferences; thresholds: UserThreshold[] },
  flowDataMap: Map<string, FlowData>,
  returnPeriodMap: Map<string, ReturnPeriod>
): Promise<AlertGenerationResult[]> {
  
  const alerts: AlertGenerationResult[] = [];

  // Check each reach the user is monitoring
  for (const reachId of userConfig.preferences.enabledReaches) {
    const flowData = flowDataMap.get(reachId);
    const returnPeriod = returnPeriodMap.get(reachId);

    if (!flowData) continue;

    // Get reach name for better alert messages
    const reachName = await getReachName(reachId);

    // Create alert context
    const context: AlertContext = {
      flowData,
      returnPeriod,
      userThresholds: userConfig.thresholds.filter(t => t.reachId === reachId),
      userPreferences: userConfig.preferences,
      reachName
    };

    // Generate alert using our tested AlertEngine
    const alert = AlertEngine.generateAlert(context);
    
    if (alert) {
      alerts.push(alert);
    }
  }

  return alerts;
}

async function getReachName(reachId: string): Promise<string> {
  // Get reach name from your existing database or map data
  // This is a placeholder - in your app you'd query your reach/station data
  return `River Location ${reachId}`;
}

async function sendNotifications(alerts: AlertGenerationResult[]): Promise<number> {
  let sentCount = 0;

  for (const alert of alerts) {
    if (!alert.shouldSendAlert) continue;

    try {
      await sendSingleNotification(alert, alert.recipientUserId);
      await recordNotificationHistory(alert, alert.recipientUserId);
      sentCount++;
    } catch (error) {
      console.error(`❌ Failed to send notification to ${alert.recipientUserId}:`, error);
    }
  }

  return sentCount;
}

async function sendSingleNotification(alert: AlertGenerationResult, userId: string): Promise<void> {
  // Get user's FCM token
  const userDoc = await db.collection('users').doc(userId).get();
  const fcmToken = userDoc.data()?.fcmToken;

  if (!fcmToken) {
    console.log(`⚠️ No FCM token for user ${userId}`);
    return;
  }

  // Send FCM notification
  if (alert.fcmPayload) {
    await messaging.send({
      token: fcmToken,
      notification: {
        title: alert.fcmPayload.title,
        body: alert.fcmPayload.body
      },
      data: alert.fcmPayload.data,
      android: {
        priority: alert.urgency === 'critical' ? 'high' : 'normal'
      },
      apns: {
        headers: {
          'apns-priority': alert.urgency === 'critical' ? '10' : '5'
        }
      }
    });
  }
}

async function recordNotificationHistory(alert: AlertGenerationResult, userId: string): Promise<void> {
  await db.collection('notificationHistory').add({
    userId,
    reachId: alert.reachId,
    notificationType: alert.alertType,
    flowValue: alert.classification.flowValue,
    flowUnit: alert.classification.unit,
    category: alert.classification.category,
    message: alert.alertMessage,
    deliveryStatus: 'sent',
    deliveryMethod: alert.deliveryMethod,
    triggeredBy: alert.triggeredBy,
    sentAt: admin.firestore.FieldValue.serverTimestamp()
  });
}

async function updateMonitoringStats(alertsGenerated: number, notificationsSent: number): Promise<void> {
  // Update thesis metrics
  await db.collection('thesisMetrics').doc('monitoring').set({
    lastRun: admin.firestore.FieldValue.serverTimestamp(),
    alertsGenerated,
    notificationsSent,
    totalRuns: admin.firestore.FieldValue.increment(1)
  }, { merge: true });
}

/**
 * Export additional utility functions for thesis demonstration
 */

// Function to seed demo data for thesis
export const seedDemoData = functions.https.onCall(async (data, context) => {
  // Only allow authenticated users to seed demo data
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  console.log('🌱 Seeding demo data for thesis...');

  // Create demo user preferences
  await db.collection('notificationPreferences').doc('demo-user').set({
    userId: 'demo-user',
    emergencyAlerts: true,
    activityAlerts: true,
    informationAlerts: true,
    frequency: 'realtime',
    quietHours: { enabled: false, startTime: '22:00', endTime: '07:00' },
    enabledReaches: ['demo-reach'],
    preferredUnit: FlowUnit.CFS,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });

  // Create demo thresholds
  await db.collection('userThresholds').doc('demo-threshold').set({
    id: 'demo-threshold',
    userId: 'demo-user',
    reachId: 'demo-reach',
    activityType: 'kayaking',
    minFlow: 200,
    maxFlow: 400,
    unit: FlowUnit.CFS,
    alertPriority: 'activity',
    enabled: true
  });

  console.log('✅ Demo data seeded successfully');

  return { success: true, message: 'Demo data seeded for thesis demonstration' };
});