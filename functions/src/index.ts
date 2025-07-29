// functions/src/index.ts - Simple notification system

import * as admin from 'firebase-admin';
import * as logger from 'firebase-functions/logger';
import {
  onRequest,
  onCall,
  HttpsError,
  CallableRequest,
} from 'firebase-functions/v2/https';
import {NOAAService} from './noaa/noaa-service';

// ===== SIMPLE NOTIFICATION SYSTEM =====
import {checkFlowNotifications} from './notifications/alert-cloud-function';

// Export the notification function
export {checkFlowNotifications};

// Initialize Firebase Admin SDK
admin.initializeApp();

// ===== BASIC TESTING FUNCTIONS =====

/**
 * Health check endpoint
 */
export const healthCheck = onRequest((req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    project: 'rivr-official',
    version: '1.0.0',
    environment: {
      scaleFactor: process.env.NOTIFICATION_SCALE_FACTOR || '1',
      checkFrequency: process.env.NOTIFICATION_CHECK_FREQUENCY_MINUTES || '360',
    },
  });
});

/**
 * Test NOAA connection
 */
export const testNoaaConnection = onRequest(async (req, res) => {
  try {
    const noaaService = new NOAAService();
    const testSiteId = '23021904';
    // Test current data fetch
    const currentData = await noaaService.getCurrentStreamflow(testSiteId);
    res.json({
      status: 'success',
      testSite: testSiteId,
      currentFlow: currentData,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('NOAA test failed:', error);
    res.status(500).json({
      status: 'error',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

/**
 * Manual notification trigger for testing
 */
export const triggerNotificationTest = onCall(
  async (request: CallableRequest) => {
    try {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Must be authenticated');
      }
      const userId = request.auth.uid;
      logger.info(`Manual notification test for user: ${userId}`);
      // Check if user has notifications enabled
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(userId)
        .get();

      if (!userDoc.exists) {
        throw new HttpsError('not-found', 'User document not found');
      }
      const userData = userDoc.data();
      if (!userData?.notificationsEnabled) {
        return {
          success: false,
          message: 'Notifications are disabled for this user',
        };
      }
      if (!userData?.fcmToken) {
        return {
          success: false,
          message: 'No FCM token found for this user',
        };
      }

      // Send test notification
      await admin.messaging().send({
        token: userData.fcmToken,
        notification: {
          title: '🧪 Test Notification',
          body: 'Your Rivr notifications are working correctly!',
        },
        data: {
          type: 'test',
          timestamp: new Date().toISOString(),
        },
      });

      return {
        success: true,
        message: 'Test notification sent successfully',
        userId: userId,
        timestamp: new Date().toISOString(),
      };
    } catch (error) {
      logger.error('Manual trigger failed:', error);
      throw new HttpsError(
        'internal',
        error instanceof Error ? error.message : 'Unknown error'
      );
    }
  }
);

/**
 * Update FCM token
 */
export const updateFCMToken = onCall(
  async (request: CallableRequest<{token: string}>):
    Promise<{success: boolean}> => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be authenticated');
    }
    const {token} = request.data;
    await admin.firestore().collection('users').doc(request.auth.uid).update({
      fcmToken: token,
      tokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    logger.info(`FCM token updated for user: ${request.auth.uid}`);
    return {success: true};
  }

);

