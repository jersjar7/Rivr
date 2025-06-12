// functions/src/notifications/flow-classifier.ts

import { FlowUnit } from "../types/flow-unit";
import { FlowData } from "../types/flow-data";
import { ReturnPeriod } from "../types/return-period";

/**
 * Alert priority levels for the notification system
 * Based on the existing Rivr flow categorization system
 */
export enum AlertPriority {
  DEMONSTRATION = 'demonstration', // For thesis demo purposes
  SAFETY = 'safety',               // Dangerous conditions (High, Very High, Extreme)
  ACTIVITY = 'activity',           // Custom user thresholds
  INFORMATION = 'information'      // General updates (Low, Normal, Moderate, Elevated)
}

/**
 * Flow categories matching the existing Rivr system
 * Maps directly to lib/features/forecast/utils/flow_thresholds.dart
 */
export enum FlowCategory {
  LOW = 'Low',
  NORMAL = 'Normal',
  MODERATE = 'Moderate',
  ELEVATED = 'Elevated',
  HIGH = 'High',
  VERY_HIGH = 'Very High',
  EXTREME = 'Extreme',
  UNKNOWN = 'Unknown'
}

/**
 * Classification result containing flow analysis
 */
export interface FlowClassificationResult {
  category: FlowCategory;
  priority: AlertPriority;
  flowValue: number;
  unit: FlowUnit;
  returnPeriodYear?: number;
  riskLevel: 'LOW' | 'MODERATE' | 'HIGH' | 'CRITICAL';
  description: string;
  shouldTriggerAlert: boolean;
  alertMessage?: string;
  colorCode: string;
}

/**
 * User threshold configuration for custom alerts
 */
export interface UserThreshold {
  id: string
  reachId: string;
  userId: string;
  activityType: string; // 'fishing', 'kayaking', 'rafting', etc.
  minFlow?: number;
  maxFlow?: number;
  unit: FlowUnit;
  alertPriority: AlertPriority;
  enabled: boolean;
}

/**
 * Flow Classifier that integrates with existing Rivr categorization
 * 
 * This class replicates the logic from:
 * - lib/features/forecast/utils/flow_thresholds.dart
 * - lib/features/forecast/domain/entities/return_period.dart
 */
export class FlowClassifier {
  
  /**
   * Get category color matching the Flutter implementation
   * Maps to FlowThresholds.getColorForCategory()
   */
  private static getCategoryColor(category: FlowCategory): string {
    switch (category) {
      case FlowCategory.LOW:
        return '#90CAF9';      // Colors.blue.shade200
      case FlowCategory.NORMAL:
        return '#4CAF50';      // Colors.green
      case FlowCategory.MODERATE:
        return '#FFEB3B';      // Colors.yellow
      case FlowCategory.ELEVATED:
        return '#FF9800';      // Colors.orange
      case FlowCategory.HIGH:
        return '#FF5722';      // Colors.deepOrange
      case FlowCategory.VERY_HIGH:
        return '#F44336';      // Colors.red
      case FlowCategory.EXTREME:
        return '#9C27B0';      // Colors.purple
      default:
        return '#9E9E9E';      // Colors.grey
    }
  }

  /**
   * Get category descriptions matching the Flutter implementation
   * Maps to FlowThresholds.categories
   */
  private static getCategoryDescription(category: FlowCategory): string {
    switch (category) {
      case FlowCategory.LOW:
        return 'Shallow waters and potentially exposed obstacles.';
      case FlowCategory.NORMAL:
        return 'Ideal conditions for most river activities.';
      case FlowCategory.MODERATE:
        return 'Slightly faster current with good visibility.';
      case FlowCategory.ELEVATED:
        return 'Strong current with potential for submerged hazards.';
      case FlowCategory.HIGH:
        return 'Powerful water flow with difficult navigation conditions.';
      case FlowCategory.VERY_HIGH:
        return 'Rapid currents with significant danger of capsizing.';
      case FlowCategory.EXTREME:
        return 'Severe flooding with destructive potential.';
      default:
        return 'Flow information unavailable.';
    }
  }

  /**
   * Convert flow between units
   * Matches the conversion logic in lib/core/models/flow_unit.dart
   */
  private static convertFlow(
    flow: number, 
    fromUnit: FlowUnit, 
    toUnit: FlowUnit
  ): number {
    if (fromUnit === toUnit) return flow;
    
    // CFS to CMS: multiply by 0.0283168
    // CMS to CFS: multiply by 35.3147
    if (fromUnit === FlowUnit.CFS && toUnit === FlowUnit.CMS) {
      return flow * 0.0283168;
    } else if (fromUnit === FlowUnit.CMS && toUnit === FlowUnit.CFS) {
      return flow * 35.3147;
    }
    
    return flow; // Fallback
  }

  /**
   * Get flow category based on return period thresholds
   * Replicates the logic from return_period.dart getFlowCategory()
   */
  private static getFlowCategory(
    flow: number,
    returnPeriod: ReturnPeriod,
    fromUnit: FlowUnit = FlowUnit.CFS
  ): FlowCategory {
    // Convert flow to match return period unit if needed
    let comparableFlow = flow;
    if (fromUnit !== returnPeriod.unit) {
      comparableFlow = this.convertFlow(flow, fromUnit, returnPeriod.unit);
    }

    // Compare with thresholds (standard years: 2, 5, 10, 25, 50, 100)
    const thresholds = returnPeriod.flowValues;
    
    if (comparableFlow < (thresholds[2] || Infinity)) {
      return FlowCategory.LOW;
    } else if (comparableFlow < (thresholds[5] || Infinity)) {
      return FlowCategory.NORMAL;
    } else if (comparableFlow < (thresholds[10] || Infinity)) {
      return FlowCategory.MODERATE;
    } else if (comparableFlow < (thresholds[25] || Infinity)) {
      return FlowCategory.ELEVATED;
    } else if (comparableFlow < (thresholds[50] || Infinity)) {
      return FlowCategory.HIGH;
    } else if (comparableFlow < (thresholds[100] || Infinity)) {
      return FlowCategory.VERY_HIGH;
    } else {
      return FlowCategory.EXTREME;
    }
  }

  /**
   * Get return period year for a given flow
   * Replicates return_period.dart getReturnPeriod()
   */
  private static getReturnPeriodYear(
    flow: number,
    returnPeriod: ReturnPeriod,
    fromUnit: FlowUnit = FlowUnit.CFS
  ): number | undefined {
    let comparableFlow = flow;
    if (fromUnit !== returnPeriod.unit) {
      comparableFlow = this.convertFlow(flow, fromUnit, returnPeriod.unit);
    }

    const standardYears = [2, 5, 10, 25, 50, 100];
    let closestYear: number | undefined;
    let minDifference = Infinity;

    for (const year of standardYears) {
      const returnFlow = returnPeriod.flowValues[year];
      if (returnFlow === undefined) continue;

      const difference = Math.abs(returnFlow - comparableFlow);
      if (difference < minDifference) {
        minDifference = difference;
        closestYear = year;
      }
    }

    return closestYear;
  }

  /**
   * Determine alert priority based on flow category
   */
  private static getAlertPriority(category: FlowCategory): AlertPriority {
    switch (category) {
      case FlowCategory.HIGH:
      case FlowCategory.VERY_HIGH:
      case FlowCategory.EXTREME:
        return AlertPriority.SAFETY;
      case FlowCategory.LOW:
      case FlowCategory.NORMAL:
      case FlowCategory.MODERATE:
      case FlowCategory.ELEVATED:
        return AlertPriority.INFORMATION;
      default:
        return AlertPriority.INFORMATION;
    }
  }

  /**
   * Determine risk level for safety assessments
   */
  private static getRiskLevel(category: FlowCategory): 'LOW' | 'MODERATE' | 'HIGH' | 'CRITICAL' {
    switch (category) {
      case FlowCategory.LOW:
      case FlowCategory.NORMAL:
        return 'LOW';
      case FlowCategory.MODERATE:
      case FlowCategory.ELEVATED:
        return 'MODERATE';
      case FlowCategory.HIGH:
        return 'HIGH';
      case FlowCategory.VERY_HIGH:
      case FlowCategory.EXTREME:
        return 'CRITICAL';
      default:
        return 'LOW';
    }
  }

  /**
   * Generate alert message based on classification
   */
  private static generateAlertMessage(
    classification: {
      category: FlowCategory;
      priority: AlertPriority;
      flowValue: number;
      unit: FlowUnit;
      returnPeriodYear?: number;
    },
    reachName?: string
  ): string {
    const location = reachName || 'Selected location';
    const flowText = `${classification.flowValue.toFixed(1)} ${classification.unit}`;
    
    switch (classification.priority) {
      case AlertPriority.SAFETY:
        return `⚠️ ${location}: ${classification.category} flow conditions (${flowText}). Exercise extreme caution.`;
      case AlertPriority.INFORMATION:
        return `📊 ${location}: ${classification.category} flow conditions (${flowText}).`;
      case AlertPriority.DEMONSTRATION:
        return `🎓 Thesis Demo: ${location} showing ${classification.category} conditions (${flowText}).`;
      default:
        return `${location}: Flow update - ${flowText}`;
    }
  }

  /**
   * Check if user thresholds are exceeded
   */
  private static checkUserThresholds(
    flow: number,
    unit: FlowUnit,
    thresholds: UserThreshold[]
  ): UserThreshold[] {
    return thresholds.filter(threshold => {
      if (!threshold.enabled) return false;

      // Convert flow to threshold unit if needed
      const comparableFlow = this.convertFlow(flow, unit, threshold.unit);

      // Check if flow is within user's specified range
      const exceedsMin = threshold.minFlow ? comparableFlow >= threshold.minFlow : true;
      const exceedsMax = threshold.maxFlow ? comparableFlow <= threshold.maxFlow : true;

      return !(exceedsMin && exceedsMax); // Alert if outside the desired range
    });
  }

  /**
   * Main classification method that integrates with existing Rivr system
   */
  static classifyFlow(
    flowData: FlowData,
    returnPeriod?: ReturnPeriod,
    userThresholds: UserThreshold[] = [],
    options: {
      reachName?: string;
      forceDemo?: boolean;
    } = {}
  ): FlowClassificationResult {
    
    const { flow, unit } = flowData;
    
    // Get flow category using return period if available
    let category = FlowCategory.UNKNOWN;
    let returnPeriodYear: number | undefined;
    
    if (returnPeriod) {
      category = this.getFlowCategory(flow, returnPeriod, unit);
      returnPeriodYear = this.getReturnPeriodYear(flow, returnPeriod, unit);
    }

    // Determine alert priority
    let priority = this.getAlertPriority(category);
    
    // Check user thresholds for activity alerts
    const exceededThresholds = this.checkUserThresholds(flow, unit, userThresholds);
    if (exceededThresholds.length > 0) {
      priority = AlertPriority.ACTIVITY;
    }

    // Override for thesis demonstration
    if (options.forceDemo) {
      priority = AlertPriority.DEMONSTRATION;
    }

    const riskLevel = this.getRiskLevel(category);
    const description = this.getCategoryDescription(category);
    const colorCode = this.getCategoryColor(category);
    
    // Determine if this should trigger an alert
    const shouldTriggerAlert = 
      priority === AlertPriority.SAFETY ||
      priority === AlertPriority.DEMONSTRATION ||
      exceededThresholds.length > 0;

    const alertMessage = shouldTriggerAlert ? 
      this.generateAlertMessage({
        category,
        priority,
        flowValue: flow,
        unit,
        returnPeriodYear
      }, options.reachName) : undefined;

    return {
      category,
      priority,
      flowValue: flow,
      unit,
      returnPeriodYear,
      riskLevel,
      description,
      shouldTriggerAlert,
      alertMessage,
      colorCode
    };
  }

  /**
   * Convenience method for testing with NOAA data samples
   */
  static testWithSampleData(
    samples: Array<{ flow: number; unit: FlowUnit; reachId: string }>
  ): FlowClassificationResult[] {
    return samples.map(sample => {
      const flowData: FlowData = {
        reachId: sample.reachId,
        flow: sample.flow,
        unit: sample.unit,
        timestamp: new Date(),
        source: 'NOAA_TEST'
      };

      return this.classifyFlow(flowData, undefined, [], { 
        forceDemo: true,
        reachName: `Test Reach ${sample.reachId}`
      });
    });
  }
}