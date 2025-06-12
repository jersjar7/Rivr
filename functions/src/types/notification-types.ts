// functions/src/types/notification-types.ts
import { FlowUnit } from "./flow-unit";
import { AlertPriority } from "../notifications/flow-classifier";
import { FlowData } from "./flow-data";
import { ReturnPeriod } from "./return-period";

/**
 * User notification preferences
 * Will be stored in Firestore 'notificationPreferences' collection
 */
export interface NotificationPreferences {
  userId: string;
  emergencyAlerts: boolean;        // Safety alerts (High, Very High, Extreme)
  activityAlerts: boolean;         // Custom threshold alerts
  informationAlerts: boolean;      // General flow updates
  frequency: 'realtime' | 'daily' | 'weekly';
  quietHours: {
    enabled: boolean;
    startTime: string;  // "22:00"
    endTime: string;    // "07:00"
  };
  enabledReaches: string[];        // Array of reach IDs user wants alerts for
  preferredUnit: FlowUnit;
  createdAt: Date;
  updatedAt: Date;
}

/**
 * User custom threshold configuration
 * Will be stored in Firestore 'userThresholds' collection
 */
export interface UserThreshold {
  id: string;
  userId: string;
  reachId: string;
  reachName?: string;
  activityType: 'fishing' | 'kayaking' | 'rafting' | 'swimming' | 'boating' | 'general';
  thresholdType: 'min' | 'max' | 'range' | 'exact';
  minFlow?: number;
  maxFlow?: number;
  targetFlow?: number;           // For 'exact' type
  tolerance?: number;            // ±tolerance for 'exact' type
  unit: FlowUnit;
  alertPriority: AlertPriority;
  enabled: boolean;
  description?: string;          // User's custom description
  createdAt: Date;
  updatedAt: Date;
}

/**
 * Notification delivery record
 * Will be stored in Firestore 'notificationHistory' collection
 */
export interface NotificationHistory {
  id: string;
  userId: string;
  reachId: string;
  notificationType: AlertPriority;
  flowValue: number;
  flowUnit: FlowUnit;
  category: string;              // Flow category at time of notification
  message: string;
  deliveryStatus: 'sent' | 'failed' | 'pending';
  deliveryMethod: 'fcm' | 'email' | 'sms';
  fcmToken?: string;
  triggeredBy: 'threshold' | 'safety' | 'manual' | 'demo';
  sentAt: Date;
  readAt?: Date;
  errorMessage?: string;
}

/**
 * NOAA flow cache entry
 * Will be stored in Firestore 'noaaFlowCache' collection
 */
export interface NoaaFlowCache {
  reachId: string;
  latestFlow: FlowData;
  historicalData: FlowData[];     // Last 24-48 hours of data
  returnPeriod?: ReturnPeriod;
  lastUpdated: Date;
  nextUpdateDue: Date;
  updateFrequency: number;        // Minutes between updates
  isActive: boolean;              // Whether to continue monitoring this reach
}

/**
 * Monitoring job configuration
 */
export interface MonitoringJob {
  id: string;
  reachIds: string[];
  frequency: number;              // Minutes
  enabled: boolean;
  lastRun?: Date;
  nextRun: Date;
  errorCount: number;
  maxErrors: number;
}

/**
 * Alert generation context
 */
export interface AlertContext {
  flowData: FlowData;
  previousFlow?: FlowData;
  returnPeriod?: ReturnPeriod;
  userThresholds: UserThreshold[];
  userPreferences: NotificationPreferences;
  reachName?: string;
  locationInfo?: {
    river?: string;
    state?: string;
    region?: string;
  };
}

/**
 * Alert delivery payload for FCM
 */
export interface AlertPayload {
  title: string;
  body: string;
  data: {
    reachId: string;
    flowValue: string;
    flowUnit: string;
    category: string;
    priority: string;
    timestamp: string;
    deepLink?: string;          // rivr://reach/12345
  };
}