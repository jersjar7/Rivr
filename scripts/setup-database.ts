// setup-database.ts - Run this script to initialize notification collections
// Place this in a scripts/ directory and run with: npx ts-node setup-database.ts

import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

// Initialize Firebase Admin SDK
initializeApp({
  projectId: 'rivr-official',
});

const db = getFirestore();

// Database schema interfaces for TypeScript
interface NotificationPreferences {
  emergencyAlerts: boolean;
  activityAlerts: boolean;
  informationAlerts: boolean;
  frequency: 'realtime' | 'daily' | 'weekly';
  quietHours: {
    enabled: boolean;
    start: string; // "22:00"
    end: string;   // "07:00"
  };
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.Timestamp;
}

interface UserThreshold {
  stationId: string;
  alertType: 'above' | 'below' | 'range';
  value: number;
  unit: 'CFS' | 'CMS';
  activity: string; // 'fishing', 'kayaking', 'safety', etc.
  enabled: boolean;
  createdAt: FirebaseFirestore.Timestamp;
  lastTriggered?: FirebaseFirestore.Timestamp;
}

interface NotificationHistory {
  title: string;
  body: string;
  type: 'safety' | 'activity' | 'information';
  stationId: string;
  thresholdId?: string;
  sentAt: FirebaseFirestore.Timestamp;
  opened: boolean;
  actionTaken: boolean;
  deliveryStatus: 'sent' | 'delivered' | 'failed';
}

interface NOAAFlowCache {
  stationId: string;
  currentFlow: number;
  unit: string;
  timestamp: FirebaseFirestore.Timestamp;
  lastUpdated: FirebaseFirestore.Timestamp;
  expiresAt: FirebaseFirestore.Timestamp;
  source: 'NOAA_NWM';
  quality: 'good' | 'fair' | 'poor';
  forecast?: Array<{
    timestamp: FirebaseFirestore.Timestamp;
    value: number;
  }>;
}

// Function to create sample data structures
async function setupNotificationCollections() {
  try {
    console.log('Setting up notification collections...');

    // 1. Create sample notification preferences structure
    const samplePreferences: NotificationPreferences = {
      emergencyAlerts: true,
      activityAlerts: true,
      informationAlerts: false,
      frequency: 'realtime',
      quietHours: {
        enabled: true,
        start: '22:00',
        end: '07:00'
      },
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now()
    };

    // Create a sample document to establish collection structure
    await db.collection('notificationPreferences').doc('_sample').set(samplePreferences);
    console.log('✅ Created notificationPreferences collection structure');

    // 2. Create sample threshold structure  
    const sampleThreshold: UserThreshold = {
      stationId: 'sample_station',
      alertType: 'above',
      value: 1000,
      unit: 'CFS',
      activity: 'fishing',
      enabled: true,
      createdAt: Timestamp.now()
    };

    await db.collection('userThresholds').doc('_sample').collection('thresholds').doc('_sample').set(sampleThreshold);
    console.log('✅ Created userThresholds collection structure');

    // 3. Create sample notification history structure
    const sampleNotification: NotificationHistory = {
      title: 'Sample Flow Alert',
      body: 'Sample river is at optimal levels for fishing',
      type: 'activity',
      stationId: 'sample_station',
      sentAt: Timestamp.now(),
      opened: false,
      actionTaken: false,
      deliveryStatus: 'sent'
    };

    await db.collection('notificationHistory').doc('_sample').collection('notifications').doc('_sample').set(sampleNotification);
    console.log('✅ Created notificationHistory collection structure');

    // 4. Create sample NOAA flow cache structure
    const sampleCache: NOAAFlowCache = {
      stationId: 'sample_noaa_reach',
      currentFlow: 850,
      unit: 'CFS',
      timestamp: Timestamp.now(),
      lastUpdated: Timestamp.now(),
      expiresAt: Timestamp.fromMillis(Date.now() + 30 * 60 * 1000), // 30 minutes
      source: 'NOAA_NWM',
      quality: 'good'
    };

    await db.collection('noaaFlowCache').doc('sample_reach').set(sampleCache);
    console.log('✅ Created noaaFlowCache collection structure');

    console.log('\n🎉 All notification collections initialized!');
    console.log('\nNext steps:');
    console.log('1. Deploy firestore.rules: firebase deploy --only firestore:rules');
    console.log('2. Deploy firestore.indexes: firebase deploy --only firestore:indexes');
    console.log('3. Delete sample documents when ready');

  } catch (error) {
    console.error('❌ Error setting up collections:', error);
  }
}

// Import Timestamp
import { Timestamp } from 'firebase-admin/firestore';

// Run the setup
setupNotificationCollections();

// Command to clean up sample documents later:
async function cleanupSampleData() {
  await db.collection('notificationPreferences').doc('_sample').delete();
  await db.collection('userThresholds').doc('_sample').collection('thresholds').doc('_sample').delete();
  await db.collection('notificationHistory').doc('_sample').collection('notifications').doc('_sample').delete();
  await db.collection('noaaFlowCache').doc('sample_reach').delete();
  console.log('🧹 Sample data cleaned up');
}