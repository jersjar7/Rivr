// functions/src/notifications/alert-engine.ts

import { FlowData } from '../types/flow-data';
import { FlowUnit } from '../types/flow-unit';
import { AlertPayload, NotificationPreferences, AlertContext } from '../types/notification-types';
import { ReturnPeriod } from '../types/return-period';
import { FlowClassifier, AlertPriority, FlowCategory, FlowClassificationResult } from './flow-classifier';
import { UserThreshold } from '../types/notification-types';

/**
 * Alert generation result containing all necessary information for notification delivery
 */
export interface AlertGenerationResult {
  shouldSendAlert: boolean;
  alertType: AlertPriority;
  classification: FlowClassificationResult;
  alertMessage: string;
  alertTitle: string;
  fcmPayload?: AlertPayload;
  recipientUserId: string;
  reachId: string;
  triggeredBy: 'threshold' | 'safety' | 'manual' | 'demo';
  urgency: 'low' | 'medium' | 'high' | 'critical';
  deliveryMethod: 'fcm' | 'email' | 'sms' | 'all';
}

/**
 * Emergency condition detection configuration
 */
interface EmergencyCondition {
  flowCategory: FlowCategory;
  minReturnPeriod?: number; // Minimum return period year that triggers emergency
  description: string;
  urgency: 'high' | 'critical';
  immediateAlert: boolean;
}

/**
 * Alert Engine - Core system for generating flow-based notifications
 * 
 * This engine integrates with the existing Rivr flow classification system
 * and generates appropriate alerts based on user preferences and safety conditions.
 */
export class AlertEngine {
  
  /**
   * Emergency conditions that trigger immediate safety alerts
   * Based on your existing Rivr flow categories and return periods
   */
  private static readonly EMERGENCY_CONDITIONS: EmergencyCondition[] = [
    {
      flowCategory: FlowCategory.HIGH,
      minReturnPeriod: 25,
      description: 'High flow conditions with significant navigation risks',
      urgency: 'high',
      immediateAlert: true
    },
    {
      flowCategory: FlowCategory.VERY_HIGH,
      minReturnPeriod: 50,
      description: 'Very high flow with extreme danger of capsizing',
      urgency: 'critical',
      immediateAlert: true
    },
    {
      flowCategory: FlowCategory.EXTREME,
      minReturnPeriod: 100,
      description: 'Extreme flooding conditions - life threatening',
      urgency: 'critical',
      immediateAlert: true
    }
  ];

  /**
   * Check if current time is within user's quiet hours
   */
  private static isInQuietHours(preferences: NotificationPreferences): boolean {
    if (!preferences.quietHours.enabled) return false;

    const now = new Date();
    const currentTime = now.getHours() * 60 + now.getMinutes(); // Minutes since midnight
    
    const [startHour, startMin] = preferences.quietHours.startTime.split(':').map(Number);
    const [endHour, endMin] = preferences.quietHours.endTime.split(':').map(Number);
    
    const startTime = startHour * 60 + startMin;
    const endTime = endHour * 60 + endMin;

    // Handle overnight quiet hours (e.g., 22:00 to 07:00)
    if (startTime > endTime) {
      return currentTime >= startTime || currentTime <= endTime;
    } else {
      return currentTime >= startTime && currentTime <= endTime;
    }
  }

  /**
   * Detect emergency conditions based on flow classification
   */
  private static detectEmergencyConditions(
    classification: FlowClassificationResult
  ): EmergencyCondition | null {
    
    for (const condition of this.EMERGENCY_CONDITIONS) {
      if (classification.category === condition.flowCategory) {
        // Check if return period meets emergency threshold
        if (condition.minReturnPeriod && classification.returnPeriodYear) {
          if (classification.returnPeriodYear >= condition.minReturnPeriod) {
            return condition;
          }
        } else if (!condition.minReturnPeriod) {
          // Emergency condition doesn't require specific return period
          return condition;
        }
      }
    }

    return null;
  }

  /**
   * Check user custom thresholds against current flow
   */
  private static checkUserThresholds(
    flowData: FlowData,
    userThresholds: UserThreshold[]
  ): UserThreshold[] {
    
    return userThresholds.filter(threshold => {
      if (!threshold.enabled || threshold.reachId !== flowData.reachId) {
        return false;
      }

      // Convert flow to threshold unit if needed
      let comparableFlow = flowData.flow;
      if (flowData.unit !== threshold.unit) {
        comparableFlow = flowData.unit === FlowUnit.CFS && threshold.unit === FlowUnit.CMS
          ? flowData.flow * 0.0283168  // CFS to CMS
          : flowData.flow * 35.3147;   // CMS to CFS
      }

      // Check threshold conditions
      if (threshold.minFlow && comparableFlow < threshold.minFlow) {
        return true; // Below minimum - alert user
      }
      
      if (threshold.maxFlow && comparableFlow > threshold.maxFlow) {
        return true; // Above maximum - alert user
      }

      return false;
    });
  }

  /**
   * Generate alert title based on alert type and conditions
   */
  private static generateAlertTitle(
    alertType: AlertPriority,
    classification: FlowClassificationResult,
    reachName?: string
  ): string {
    
    const location = reachName || 'River Location';

    switch (alertType) {
      case AlertPriority.SAFETY:
        return `⚠️ Safety Alert: ${classification.category} Flow`;
      
      case AlertPriority.ACTIVITY:
        return `🎯 Activity Alert: ${location}`;
      
      case AlertPriority.DEMONSTRATION:
        return `🎓 Thesis Demo: Flow Update`;
      
      case AlertPriority.INFORMATION:
        return `📊 Flow Update: ${location}`;
      
      default:
        return `Flow Notification: ${location}`;
    }
  }

  /**
   * Generate detailed alert message
   */
  private static generateAlertMessage(
    alertType: AlertPriority,
    classification: FlowClassificationResult,
    context: AlertContext,
    triggeredThresholds?: UserThreshold[],
    emergency?: EmergencyCondition
  ): string {
    
    const flowText = `${classification.flowValue.toFixed(1)} ${classification.unit}`;
    const location = context.reachName || 'Selected location';

    // Build base message
    let message = `${location}: ${classification.category} flow conditions (${flowText}).`;

    // Add context based on alert type
    switch (alertType) {
      case AlertPriority.SAFETY:
        if (emergency) {
          message += ` ${emergency.description}. Avoid water activities.`;
        } else {
          message += ` ${classification.description} Exercise caution.`;
        }
        break;

      case AlertPriority.ACTIVITY:
        if (triggeredThresholds && triggeredThresholds.length > 0) {
          const activities = triggeredThresholds.map(t => t.activityType).join(', ');
          message += ` This affects your ${activities} preferences.`;
        }
        break;

      case AlertPriority.DEMONSTRATION:
        message += ` Thesis demonstration showing real-time NOAA data integration.`;
        if (classification.returnPeriodYear) {
          message += ` This represents a ${classification.returnPeriodYear}-year flow event.`;
        }
        break;

      case AlertPriority.INFORMATION:
        message += ` ${classification.description}`;
        break;
    }

    // Add trend information if previous flow data is available
    if (context.previousFlow) {
      const trend = classification.flowValue > context.previousFlow.flow ? 'rising' : 'falling';
      const change = Math.abs(classification.flowValue - context.previousFlow.flow);
      message += ` Flow is ${trend} (${change.toFixed(1)} ${classification.unit} change).`;
    }

    return message;
  }

  /**
   * Create FCM payload for push notification
   */
  private static createFcmPayload(
    title: string,
    message: string,
    context: AlertContext,
    classification: FlowClassificationResult,
    alertType: AlertPriority
  ): AlertPayload {
    
    return {
      title,
      body: message,
      data: {
        reachId: context.flowData.reachId,
        flowValue: classification.flowValue.toString(),
        flowUnit: classification.unit,
        category: classification.category,
        priority: alertType,
        timestamp: context.flowData.timestamp.toISOString(),
        deepLink: `rivr://reach/${context.flowData.reachId}` // Deep link to reach details
      }
    };
  }

  /**
   * Determine delivery method based on alert urgency and user preferences
   */
  private static determineDeliveryMethod(
    alertType: AlertPriority,
    urgency: 'low' | 'medium' | 'high' | 'critical',
    preferences: NotificationPreferences
  ): 'fcm' | 'email' | 'sms' | 'all' {
    
    // Critical safety alerts - use all available methods
    if (urgency === 'critical') {
      return 'all';
    }

    // High urgency safety alerts - FCM + SMS
    if (urgency === 'high' && alertType === AlertPriority.SAFETY) {
      return 'sms'; // Will be expanded to include FCM in full implementation
    }

    // Activity and information alerts - FCM only
    return 'fcm';
  }

  /**
   * Main alert generation method
   * 
   * This method integrates all components to generate comprehensive alerts
   * based on flow conditions, user preferences, and safety considerations.
   */
  static generateAlert(context: AlertContext): AlertGenerationResult | null {
    
    const { flowData, returnPeriod, userThresholds, userPreferences, reachName } = context;

    // Skip if reach is not in user's enabled list
    if (!userPreferences.enabledReaches.includes(flowData.reachId)) {
      return null;
    }

    // Classify the flow using our tested classification system
    const classification = FlowClassifier.classifyFlow(
      flowData,
      returnPeriod,
      userThresholds,
      { reachName }
    );

    // Detect emergency conditions
    const emergency = this.detectEmergencyConditions(classification);
    
    // Check user custom thresholds
    const triggeredThresholds = this.checkUserThresholds(flowData, userThresholds);

    // Determine alert type and urgency
    let alertType = classification.priority;
    let urgency: 'low' | 'medium' | 'high' | 'critical' = 'low';
    let triggeredBy: 'threshold' | 'safety' | 'manual' | 'demo' = 'manual';

    // Override based on conditions
    if (emergency) {
      alertType = AlertPriority.SAFETY;
      urgency = emergency.urgency;
      triggeredBy = 'safety';
    } else if (triggeredThresholds.length > 0) {
      alertType = AlertPriority.ACTIVITY;
      urgency = 'medium';
      triggeredBy = 'threshold';
    } else if (classification.priority === AlertPriority.DEMONSTRATION) {
      urgency = 'low';
      triggeredBy = 'demo';
    } else {
      urgency = 'low';
    }

    // Check if we should send alert based on user preferences
    let shouldSendAlert = false;

    if (alertType === AlertPriority.SAFETY && userPreferences.emergencyAlerts) {
      shouldSendAlert = true; // Always send safety alerts if enabled
    } else if (alertType === AlertPriority.ACTIVITY && userPreferences.activityAlerts) {
      shouldSendAlert = true;
    } else if (alertType === AlertPriority.INFORMATION && userPreferences.informationAlerts) {
      shouldSendAlert = true;
    } else if (alertType === AlertPriority.DEMONSTRATION) {
      shouldSendAlert = true; // Always send demo alerts for thesis
    }

    // Check quiet hours (but allow critical safety alerts)
    if (shouldSendAlert && urgency !== 'critical' && this.isInQuietHours(userPreferences)) {
      shouldSendAlert = false;
    }

    // Generate alert content
    const alertTitle = this.generateAlertTitle(alertType, classification, reachName);
    const alertMessage = this.generateAlertMessage(
      alertType,
      classification,
      context,
      triggeredThresholds,
      emergency ?? undefined
    );

    // Create FCM payload
    const fcmPayload = this.createFcmPayload(
      alertTitle,
      alertMessage,
      context,
      classification,
      alertType
    );

    // Determine delivery method
    const deliveryMethod = this.determineDeliveryMethod(alertType, urgency, userPreferences);

    return {
      shouldSendAlert,
      alertType,
      classification,
      alertMessage,
      alertTitle,
      fcmPayload,
      recipientUserId: userPreferences.userId,
      reachId: flowData.reachId,
      triggeredBy,
      urgency,
      deliveryMethod
    };
  }

  /**
   * Generate multiple alerts for different users and reaches
   * Useful for batch processing during scheduled monitoring
   */
  static generateBatchAlerts(
    flowDataArray: FlowData[],
    returnPeriods: Map<string, ReturnPeriod>,
    userConfigurations: Array<{
      preferences: NotificationPreferences;
      thresholds: UserThreshold[];
    }>,
    reachNames?: Map<string, string>
  ): AlertGenerationResult[] {
    
    const alerts: AlertGenerationResult[] = [];

    for (const flowData of flowDataArray) {
      const returnPeriod = returnPeriods.get(flowData.reachId);
      const reachName = reachNames?.get(flowData.reachId);

      for (const userConfig of userConfigurations) {
        const context: AlertContext = {
          flowData,
          returnPeriod,
          userThresholds: userConfig.thresholds.filter(t => t.reachId === flowData.reachId),
          userPreferences: userConfig.preferences,
          reachName
        };

        const alert = this.generateAlert(context);
        if (alert) {
          alerts.push(alert);
        }
      }
    }

    return alerts;
  }

  /**
   * Thesis-specific demo alert generation
   * Creates alerts with demonstration context for academic presentation
   */
  static generateDemoAlert(
    flowData: FlowData,
    returnPeriod?: ReturnPeriod,
    demoScenario: string = 'Real-time NOAA data demonstration'
  ): AlertGenerationResult {
    
    // Force demo mode classification
    const classification = FlowClassifier.classifyFlow(
      flowData,
      returnPeriod,
      [],
      { forceDemo: true, reachName: 'Demo River Location' }
    );

    const alertTitle = `🎓 Thesis Demo: ${classification.category} Flow Detected`;
    const alertMessage = `${demoScenario}. Current flow: ${flowData.flow} ${flowData.unit} (${classification.category} conditions). This demonstrates real-time integration with NOAA National Water Model data.`;

    const fcmPayload: AlertPayload = {
      title: alertTitle,
      body: alertMessage,
      data: {
        reachId: flowData.reachId,
        flowValue: flowData.flow.toString(),
        flowUnit: flowData.unit,
        category: classification.category,
        priority: AlertPriority.DEMONSTRATION,
        timestamp: flowData.timestamp.toISOString(),
        deepLink: `rivr://demo/${flowData.reachId}`
      }
    };

    return {
      shouldSendAlert: true,
      alertType: AlertPriority.DEMONSTRATION,
      classification,
      alertMessage,
      alertTitle,
      fcmPayload,
      recipientUserId: 'demo-user',
      reachId: flowData.reachId,
      triggeredBy: 'demo',
      urgency: 'low',
      deliveryMethod: 'fcm'
    };
  }
}