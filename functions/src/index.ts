// functions/src/index.ts - Main Cloud Functions entry point

import * as admin from 'firebase-admin';
import * as logger from 'firebase-functions/logger';

// v2 HTTP & Callable triggers
import {
  onRequest,
  onCall,
  HttpsError,
  CallableRequest
} from 'firebase-functions/v2/https';

import {
  onSchedule,
  ScheduledEvent
} from 'firebase-functions/v2/scheduler';

// v2 Firestore triggers
import {
  onDocumentWritten,
  FirestoreEvent
} from 'firebase-functions/v2/firestore';

// v1 Auth triggers + types
import { auth } from 'firebase-functions/v1';
import type { UserRecord } from 'firebase-admin/auth';

// Initialize Firebase Admin SDK
admin.initializeApp();

// ===== BASIC SETUP FUNCTIONS FOR TESTING =====

// Health check
export const healthCheck = onRequest((req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    project: 'rivr-official',
    version: '1.0.0'
  });
});

// Test database connection
export const testDatabase = onRequest(async (req, res) => {
  try {
    const db = admin.firestore();
    const testDocRef = await db.collection('test').add({
      message: 'Cloud Functions connected successfully',
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
    const docSnap = await testDocRef.get();
    res.json({
      status: 'success',
      docId: testDocRef.id,
      data: docSnap.data()
    });
  } catch (error) {
    logger.error('Database test failed:', error);
    res.status(500).json({
      status: 'error',
      message: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

// Test scheduled function (v2)
export const testScheduledFunction = onSchedule(
  'every 5 minutes',
  async (event: ScheduledEvent): Promise<void> => {
    logger.info('Scheduled function test executed at:', new Date().toISOString());
    const db = admin.firestore();
    await db.collection('test_logs').add({
      message: 'Scheduled function executed',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      scheduleTime: event.scheduleTime,
      jobName: event.jobName
    });
  }
);

// ===== NOTIFICATION SYSTEM FUNCTIONS =====

// Placeholder flow monitor (v2)
export const monitorFlowConditions = onSchedule(
  { schedule: 'every 30 minutes', timeZone: 'America/Denver' },
  async (event: ScheduledEvent): Promise<void> => {
    logger.info('Flow monitoring triggered:', event);
    // TODO: Implement fetching, caching, threshold checks, notifications
  }
);

// Firestore threshold processing (v2)
export const processThresholdUpdates = onDocumentWritten(
  'noaaFlowCache/{stationId}',
  async (event: FirestoreEvent<any, { stationId: string }>): Promise<void> => {
    const stationId = event.params.stationId;
    logger.info(`Threshold processing for station ${stationId}`, event.data);
    // TODO: Implement threshold evaluation and notifications
  }
);

// ===== USER MANAGEMENT FUNCTIONS =====

// Initialize preferences on user creation (v1)
export const initializeUserPreferences = auth.user().onCreate(
  async (user: UserRecord): Promise<void> => {
    const db = admin.firestore();
    await db.collection('notificationPreferences').doc(user.uid).set({
      emergencyAlerts: true,
      activityAlerts: false,
      informationAlerts: false,
      frequency: 'realtime',
      quietHours: { enabled: false, start: '22:00', end: '07:00' },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    logger.info(`Initialized preferences for user ${user.uid}`);
  }
);

// Cleanup on user deletion (v1)
export const cleanupUserData = auth.user().onDelete(
  async (user: UserRecord): Promise<void> => {
    const db = admin.firestore();
    const batch = db.batch();
    batch.delete(db.collection('notificationPreferences').doc(user.uid));
    const thrSnap = await db
      .collection('userThresholds')
      .doc(user.uid)
      .collection('thresholds')
      .get();
    thrSnap.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    logger.info(`Cleaned up data for user ${user.uid}`);
  }
);

// ===== THESIS-SPECIFIC FUNCTIONS =====

// Record metrics (v2)
export const recordThesisMetrics = onCall(
  async (
    request: CallableRequest<{ eventType: string; metadata: any }>
  ): Promise<{ success: boolean }> => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be authenticated');
    }
    const { data } = request;
    const db = admin.firestore();
    await db.collection('thesis_metrics').add({
      userId: request.auth.uid,
      eventType: data.eventType,
      metadata: data.metadata,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
    return { success: true };
  }
);

// Test notification (v2)
export const sendTestNotification = onCall(
  async (request: CallableRequest): Promise<{ success: boolean; message: string }> => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be authenticated');
    }
    logger.info(`Test notification by ${request.auth.uid}`);
    return { success: true, message: 'Placeholder sent' };
  }
);

// Update FCM token (v2)
export const updateFCMToken = onCall(
  async (request: CallableRequest<{ token: string }>): Promise<{ success: boolean }> => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be authenticated');
    }
    const { token } = request.data;
    await admin.firestore().collection('users').doc(request.auth.uid).update({
      fcmToken: token,
      tokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    return { success: true };
  }
);
