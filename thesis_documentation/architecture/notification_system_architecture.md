# Task 1.3 - Notification System Architecture for Thesis Demonstration

## System Architecture Overview

### High-Level Architecture Design
```
┌─────────────────────────────────────────────────────────────────┐
│                    NOAA National Water Model                    │
│                         (External API)                          │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  │ HTTP/REST API Calls
                  │
┌─────────────────▼───────────────────────────────────────────────┐
│                   Firebase Cloud Functions                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  NOAA Service   │  │ Threshold       │  │ Notification    │  │
│  │  • Data Fetch   │  │ Processor       │  │ Dispatcher      │  │
│  │  • Transform    │  │ • Check Alerts  │  │ • FCM Delivery  │  │
│  │  • Cache        │  │ • Priority      │  │ • Message Gen   │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────┬───────────────┬───────────────┬───────────────┘
                  │               │               │
                  │               │               │
┌─────────────────▼───────────────▼───────────────▼───────────────┐
│                     Firebase Firestore                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ User Thresholds │  │ Flow Data Cache │  │ Notification    │  │
│  │ Preferences     │  │ NOAA Responses  │  │ History         │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  │ Real-time Data Sync
                  │
┌─────────────────▼───────────────────────────────────────────────┐
│                Firebase Cloud Messaging (FCM)                   │
│                    • Cross-platform delivery                    │
│                    • Background notifications                   │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  │ Push Notifications
                  │
┌─────────────────▼───────────────────────────────────────────────┐
│                     Flutter Mobile App                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ Notification    │  │ Settings UI     │  │ Threshold       │  │
│  │ Handler         │  │ Preferences     │  │ Management      │  │
│  │ • Display       │  │ • Enable/Disable│  │ • Create/Edit   │  │
│  │ • Deep Link     │  │ • Frequency     │  │ • Activity Type │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Component Architecture Detail

### 1. Data Ingestion Layer (Cloud Functions)

#### NOAA Data Service Component
```typescript
// Architecture: Scheduled data fetching service
export class NOAADataService {
  // Core responsibilities:
  // 1. Scheduled API calls to NOAA NWM
  // 2. Data transformation and validation
  // 3. Cache management in Firestore
  // 4. Error handling and fallback strategies

  private scheduler: CloudScheduler;
  private apiClient: NOAAApiClient;
  private cacheManager: DataCacheManager;
  private errorHandler: APIErrorHandler;

  async processScheduledFetch(): Promise<void> {
    // 1. Get list of monitored reaches from active user thresholds
    // 2. Batch fetch data from NOAA API
    // 3. Transform data to Rivr format
    // 4. Update cache in Firestore
    // 5. Trigger threshold evaluation
  }
}
```

#### Data Processing Pipeline
```
NOAA API Response → Validation → Transformation → Caching → Event Trigger
       ↓               ↓            ↓             ↓           ↓
   Raw JSON      Schema Check   Rivr Format   Firestore   Threshold Check
```

### 2. Threshold Processing Engine

#### Threshold Evaluation Service
```typescript
export class ThresholdProcessor {
  // Architecture: Event-driven threshold evaluation
  // Triggered by: New flow data availability
  // Output: Alert candidates for notification dispatch

  async evaluateThresholds(newFlowData: FlowData[]): Promise<AlertCandidate[]> {
    const alerts: AlertCandidate[] = [];
    
    // 1. Get all active user thresholds for affected stations
    const thresholds = await this.getActiveThresholds(newFlowData);
    
    // 2. Evaluate each threshold against new data
    for (const threshold of thresholds) {
      const alert = this.checkThreshold(threshold, newFlowData);
      if (alert) {
        alerts.push(alert);
      }
    }
    
    // 3. Apply alert suppression logic (prevent spam)
    return this.deduplicateAlerts(alerts);
  }
}

interface AlertCandidate {
  userId: string;
  thresholdId: string;
  stationId: string;
  alertType: 'above' | 'below' | 'rapid_change' | 'safety';
  priority: 'high' | 'medium' | 'low';
  currentValue: number;
  thresholdValue: number;
  activity: string;
  timestamp: Date;
}
```

#### Threshold Types and Logic
```typescript
enum ThresholdType {
  ABOVE = 'above',           // Flow exceeds threshold
  BELOW = 'below',           // Flow drops below threshold
  RANGE = 'range',           // Flow within optimal range
  RAPID_CHANGE = 'change',   // Flow changing quickly
  SAFETY = 'safety'          // Dangerous conditions
}

class ThresholdEvaluator {
  evaluateAboveThreshold(current: number, threshold: number): boolean {
    return current >= threshold;
  }
  
  evaluateBelowThreshold(current: number, threshold: number): boolean {
    return current <= threshold;
  }
  
  evaluateRangeThreshold(current: number, min: number, max: number): boolean {
    return current >= min && current <= max;
  }
  
  evaluateRapidChange(previous: number, current: number, changeThreshold: number): boolean {
    const percentChange = Math.abs((current - previous) / previous) * 100;
    return percentChange >= changeThreshold;
  }
}
```

### 3. Notification Dispatch System

#### Message Generation Engine
```typescript
export class NotificationMessageGenerator {
  generateMessage(alert: AlertCandidate, flowData: FlowData): NotificationMessage {
    const template = this.selectTemplate(alert.alertType, alert.activity);
    
    return {
      title: this.generateTitle(template, alert, flowData),
      body: this.generateBody(template, alert, flowData),
      data: {
        stationId: alert.stationId,
        alertType: alert.alertType,
        deepLink: `/stations/${alert.stationId}`
      },
      priority: this.mapPriority(alert.priority),
      timeToLive: this.getTimeToLive(alert.alertType)
    };
  }

  private selectTemplate(alertType: string, activity: string): MessageTemplate {
    // Activity-specific message templates
    const templates = {
      'fishing-above': {
        title: '🎣 Great Fishing Flows!',
        body: '{river} is at {flow} {unit} - Perfect for fishing!'
      },
      'kayaking-above': {
        title: '🚣 Optimal Kayaking Conditions!',
        body: '{river} reached {flow} {unit} - Great for paddling!'
      },
      'safety-high': {
        title: '⚠️ DANGER - High Water!',
        body: '{river} at {flow} {unit} - UNSAFE CONDITIONS'
      }
    };
    
    return templates[`${activity}-${alertType}`] || templates.default;
  }
}
```

#### FCM Delivery Service
```typescript
export class FCMDeliveryService {
  private messaging: admin.messaging.Messaging;
  
  async deliverNotification(
    userToken: string, 
    message: NotificationMessage
  ): Promise<DeliveryResult> {
    try {
      const fcmMessage: admin.messaging.Message = {
        token: userToken,
        notification: {
          title: message.title,
          body: message.body
        },
        data: message.data,
        android: {
          priority: 'high',
          notification: {
            channelId: 'rivr_flow_alerts',
            priority: 'high',
            defaultSound: true,
            defaultVibrateTimings: true
          }
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title: message.title,
                body: message.body
              },
              sound: 'default',
              badge: 1
            }
          }
        }
      };

      const messageId = await this.messaging.send(fcmMessage);
      
      // Log delivery for thesis metrics
      await this.logDelivery(userToken, messageId, message);
      
      return { success: true, messageId };
    } catch (error) {
      console.error('FCM Delivery Error:', error);
      return { success: false, error: error.message };
    }
  }
}
```

### 4. Mobile App Integration Architecture

#### Notification Handler Service
```typescript
// lib/core/services/notification_service.dart
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();

  // Initialize notification handling
  static Future<void> initialize() async {
    // Request permissions
    await _requestPermissions();
    
    // Configure FCM
    await _configureFCM();
    
    // Setup local notifications
    await _setupLocalNotifications();
    
    // Configure notification handlers
    _setupNotificationHandlers();
  }

  // Handle foreground notifications
  static void _setupNotificationHandlers() {
    // Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showForegroundNotification(message);
      _trackNotificationReceived(message);
    });

    // Background message handler
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

    // Notification tap handler
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message);
    });
  }

  // Deep linking from notifications
  static void _handleNotificationTap(RemoteMessage message) {
    final stationId = message.data['stationId'];
    final alertType = message.data['alertType'];
    
    // Navigate to appropriate screen
    NavigationService.navigateToStation(stationId);
    
    // Track user engagement
    AnalyticsService.trackNotificationTap(alertType);
  }
}
```

#### Settings and Preference Management
```typescript
// User preference architecture
interface NotificationPreferences {
  userId: string;
  globalSettings: {
    enabled: boolean;
    quietHours: {
      start: string; // "22:00"
      end: string;   // "07:00"
    };
    frequency: 'realtime' | 'daily' | 'weekly';
  };
  alertTypes: {
    safety: boolean;
    activity: boolean;
    information: boolean;
  };
  deliverySettings: {
    sound: boolean;
    vibration: boolean;
    led: boolean;
  };
}

class PreferenceManager {
  async updatePreferences(
    userId: string, 
    preferences: NotificationPreferences
  ): Promise<void> {
    // Update local storage
    await LocalStorage.setNotificationPreferences(preferences);
    
    // Sync to Firestore
    await FirestoreService.updateUserPreferences(userId, preferences);
    
    // Update FCM subscription topics if needed
    await this.updateFCMSubscriptions(preferences);
  }
}
```

## Data Flow Architecture

### Real-time Data Processing Flow
```
1. Scheduled Trigger (every 30 minutes)
   ↓
2. NOAA API Data Fetch
   ↓
3. Data Validation & Transformation
   ↓
4. Firestore Cache Update
   ↓
5. Threshold Evaluation Trigger
   ↓
6. User Threshold Queries
   ↓
7. Alert Generation
   ↓
8. Message Template Processing
   ↓
9. FCM Delivery
   ↓
10. Mobile App Notification Display
    ↓
11. User Interaction Tracking
    ↓
12. Analytics & Metrics Collection
```

### User Configuration Flow
```
1. User Opens Settings
   ↓
2. Configure Notification Preferences
   ↓
3. Create/Edit Flow Thresholds
   ↓
4. Local Validation
   ↓
5. Firestore Sync
   ↓
6. FCM Token Update
   ↓
7. Cloud Function Subscription Update
```

## Scalability and Performance Architecture

### Horizontal Scaling Design
```typescript
// Cloud Functions scaling configuration
export const processNOAAData = functions
  .runWith({
    timeoutSeconds: 540,
    memory: '1GB',
    maxInstances: 10  // Limit for thesis scope
  })
  .pubsub
  .schedule('every 30 minutes')
  .onRun(async (context) => {
    // Distributed processing logic
  });

export const processThresholds = functions
  .runWith({
    memory: '512MB',
    maxInstances: 5
  })
  .firestore
  .document('noaaFlowCache/{stationId}')
  .onWrite(async (change, context) => {
    // Event-driven threshold processing
  });
```

### Caching Architecture
```typescript
class MultiLevelCache {
  // Level 1: Cloud Function memory cache (30 seconds)
  private static memoryCache = new Map<string, CacheEntry>();
  
  // Level 2: Firestore cache (30 minutes)
  private static firestoreCache = admin.firestore().collection('cache');
  
  // Level 3: Mobile app cache (5 minutes)
  // Implemented in Flutter using shared_preferences
  
  async get(key: string): Promise<any> {
    // Check memory first
    let data = this.memoryCache.get(key);
    if (data && !this.isExpired(data)) return data.value;
    
    // Check Firestore
    data = await this.firestoreCache.doc(key).get();
    if (data.exists && !this.isExpired(data.data())) {
      this.memoryCache.set(key, data.data());
      return data.data().value;
    }
    
    return null;
  }
}
```

## Security and Privacy Architecture

### Authentication and Authorization
```typescript
// Security rules for notification data
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // User can only access their own notification preferences
    match /notificationPreferences/{userId} {
      allow read, write: if request.auth != null 
        && request.auth.uid == userId;
    }
    
    // User can only access their own thresholds
    match /userThresholds/{userId}/{document=**} {
      allow read, write: if request.auth != null 
        && request.auth.uid == userId;
    }
    
    // Notification history is user-specific
    match /notificationHistory/{userId}/{document=**} {
      allow read, write: if request.auth != null 
        && request.auth.uid == userId;
    }
    
    // Flow cache is read-only for authenticated users
    match /noaaFlowCache/{document=**} {
      allow read: if request.auth != null;
      allow write: if false; // Only Cloud Functions can write
    }
  }
}
```

### Data Privacy Protection
```typescript
class PrivacyManager {
  // Anonymize data for analytics
  static anonymizeUserData(userData: any): AnonymizedData {
    return {
      hashedUserId: this.hashUserId(userData.userId),
      demographics: {
        ageRange: this.binAge(userData.age),
        region: this.generalizeLocation(userData.location)
      },
      usage: userData.usage,
      // Remove all PII
    };
  }
  
  // Implement data retention policies
  static async enforceRetentionPolicy(): Promise<void> {
    const cutoffDate = new Date(Date.now() - 365 * 24 * 60 * 60 * 1000); // 1 year
    
    // Delete old notification history
    await this.deleteOldNotifications(cutoffDate);
    
    // Archive user analytics data
    await this.archiveOldAnalytics(cutoffDate);
  }
}
```

## Monitoring and Analytics Architecture

### System Health Monitoring
```typescript
class SystemMonitor {
  static async logSystemMetrics(): Promise<void> {
    const metrics = {
      noaaApiLatency: await this.measureNOAAApiLatency(),
      cacheHitRate: await this.calculateCacheHitRate(),
      notificationDeliveryRate: await this.getDeliverySuccessRate(),
      activeUsers: await this.countActiveUsers(),
      thresholdEvaluations: await this.countThresholdEvaluations()
    };
    
    // Log to Firebase Analytics for thesis metrics
    await admin.analytics().logEvent('system_metrics', metrics);
  }
}
```

### User Experience Analytics
```typescript
class UXAnalytics {
  static trackNotificationEngagement(userId: string, action: string, metadata: any) {
    return admin.analytics().logEvent('notification_engagement', {
      user_id: this.hashUserId(userId),
      action, // 'received', 'opened', 'dismissed', 'acted_upon'
      alert_type: metadata.alertType,
      response_time: metadata.responseTime,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
  }
}
```

This notification system architecture provides a robust, scalable foundation for delivering accessible NOAA flow data through intelligent mobile notifications while maintaining security, privacy, and performance standards appropriate for thesis research.
