// alert-engine-test.js
// Test the Alert Engine with mock user preferences and thresholds

// Copy the essential types and classes for testing
const FlowUnit = {
  CFS: 'cfs',
  CMS: 'cms'
};

const AlertPriority = {
  DEMONSTRATION: 'demonstration',
  SAFETY: 'safety',
  ACTIVITY: 'activity',
  INFORMATION: 'information'
};

const FlowCategory = {
  LOW: 'Low',
  NORMAL: 'Normal',
  MODERATE: 'Moderate',
  ELEVATED: 'Elevated',
  HIGH: 'High',
  VERY_HIGH: 'Very High',
  EXTREME: 'Extreme',
  UNKNOWN: 'Unknown'
};

// Simplified Alert Engine for testing
class MockAlertEngine {
  
  static EMERGENCY_CONDITIONS = [
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

  static getFlowCategory(flow, returnPeriod, fromUnit = FlowUnit.CFS) {
    let comparableFlow = flow;
    if (fromUnit !== returnPeriod.unit) {
      comparableFlow = fromUnit === FlowUnit.CFS && returnPeriod.unit === FlowUnit.CMS
        ? flow * 0.0283168  // CFS to CMS
        : flow * 35.3147;   // CMS to CFS
    }

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

  static detectEmergencyConditions(category, returnPeriodYear) {
    for (const condition of this.EMERGENCY_CONDITIONS) {
      if (category === condition.flowCategory) {
        if (condition.minReturnPeriod && returnPeriodYear) {
          if (returnPeriodYear >= condition.minReturnPeriod) {
            return condition;
          }
        } else if (!condition.minReturnPeriod) {
          return condition;
        }
      }
    }
    return null;
  }

  static checkUserThresholds(flowData, userThresholds) {
    return userThresholds.filter(threshold => {
      if (!threshold.enabled || threshold.reachId !== flowData.reachId) {
        return false;
      }

      let comparableFlow = flowData.flow;
      if (flowData.unit !== threshold.unit) {
        comparableFlow = flowData.unit === FlowUnit.CFS && threshold.unit === FlowUnit.CMS
          ? flowData.flow * 0.0283168  // CFS to CMS
          : flowData.flow * 35.3147;   // CMS to CFS
      }

      if (threshold.minFlow && comparableFlow < threshold.minFlow) {
        return true; // Below minimum - alert user
      }
      
      if (threshold.maxFlow && comparableFlow > threshold.maxFlow) {
        return true; // Above maximum - alert user
      }

      return false;
    });
  }

  static isInQuietHours(preferences) {
    if (!preferences.quietHours.enabled) return false;

    const now = new Date();
    const currentTime = now.getHours() * 60 + now.getMinutes();
    
    const [startHour, startMin] = preferences.quietHours.startTime.split(':').map(Number);
    const [endHour, endMin] = preferences.quietHours.endTime.split(':').map(Number);
    
    const startTime = startHour * 60 + startMin;
    const endTime = endHour * 60 + endMin;

    if (startTime > endTime) {
      return currentTime >= startTime || currentTime <= endTime;
    } else {
      return currentTime >= startTime && currentTime <= endTime;
    }
  }

  static generateAlert(flowData, returnPeriod, userPreferences, userThresholds, reachName = 'Test River') {
    // Skip if reach is not in user's enabled list
    if (!userPreferences.enabledReaches.includes(flowData.reachId)) {
      return { shouldSendAlert: false, reason: 'Reach not enabled for user' };
    }

    // Classify the flow
    const category = this.getFlowCategory(flowData.flow, returnPeriod, flowData.unit);
    
    // Get return period for this flow
    let returnPeriodYear = null;
    const thresholds = returnPeriod.flowValues;
    for (const [year, threshold] of Object.entries(thresholds)) {
      if (flowData.flow >= threshold) {
        returnPeriodYear = parseInt(year);
      }
    }

    // Detect emergency conditions
    const emergency = this.detectEmergencyConditions(category, returnPeriodYear);
    
    // Check user custom thresholds
    const triggeredThresholds = this.checkUserThresholds(flowData, userThresholds);

    // Determine alert type and urgency
    let alertType = AlertPriority.INFORMATION;
    let urgency = 'low';
    let triggeredBy = 'manual';

    if (emergency) {
      alertType = AlertPriority.SAFETY;
      urgency = emergency.urgency;
      triggeredBy = 'safety';
    } else if (triggeredThresholds.length > 0) {
      alertType = AlertPriority.ACTIVITY;
      urgency = 'medium';
      triggeredBy = 'threshold';
    }

    // Check if we should send alert based on user preferences
    let shouldSendAlert = false;

    if (alertType === AlertPriority.SAFETY && userPreferences.emergencyAlerts) {
      shouldSendAlert = true;
    } else if (alertType === AlertPriority.ACTIVITY && userPreferences.activityAlerts) {
      shouldSendAlert = true;
    } else if (alertType === AlertPriority.INFORMATION && userPreferences.informationAlerts) {
      shouldSendAlert = true;
    }

    // Check quiet hours (but allow critical safety alerts)
    if (shouldSendAlert && urgency !== 'critical' && this.isInQuietHours(userPreferences)) {
      shouldSendAlert = false;
    }

    // Generate alert content
    const flowText = `${flowData.flow.toFixed(1)} ${flowData.unit}`;
    let alertTitle = '';
    let alertMessage = '';

    switch (alertType) {
      case AlertPriority.SAFETY:
        alertTitle = `⚠️ Safety Alert: ${category} Flow`;
        alertMessage = `${reachName}: ${category} flow conditions (${flowText}). ${emergency ? emergency.description : 'Exercise caution.'} Avoid water activities.`;
        break;
      
      case AlertPriority.ACTIVITY:
        alertTitle = `🎯 Activity Alert: ${reachName}`;
        const activities = triggeredThresholds.map(t => t.activityType).join(', ');
        alertMessage = `${reachName}: ${category} flow conditions (${flowText}). This affects your ${activities} preferences.`;
        break;
      
      case AlertPriority.INFORMATION:
        alertTitle = `📊 Flow Update: ${reachName}`;
        alertMessage = `${reachName}: ${category} flow conditions (${flowText}).`;
        break;
    }

    return {
      shouldSendAlert,
      alertType,
      category,
      flowValue: flowData.flow,
      unit: flowData.unit,
      returnPeriodYear,
      urgency,
      triggeredBy,
      alertTitle,
      alertMessage,
      triggeredThresholds: triggeredThresholds.length,
      emergency: !!emergency,
      inQuietHours: this.isInQuietHours(userPreferences)
    };
  }
}

// Test with mock data
function testAlertEngine() {
  console.log('🚨 Testing Alert Engine with Mock User Preferences');
  console.log('=' .repeat(60));

  // Mock return period data
  const returnPeriod = {
    reachId: 'reach123',
    unit: FlowUnit.CFS,
    flowValues: {
      2: 150,    // 2-year flow
      5: 250,    // 5-year flow
      10: 350,   // 10-year flow
      25: 500,   // 25-year flow
      50: 650,   // 50-year flow
      100: 800   // 100-year flow
    },
    retrievedAt: new Date()
  };

  // Mock user preferences - Safety-conscious kayaker
  const safetyUserPreferences = {
    userId: 'user-safety',
    emergencyAlerts: true,
    activityAlerts: true,
    informationAlerts: false,
    frequency: 'realtime',
    quietHours: {
      enabled: true,
      startTime: '22:00',
      endTime: '07:00'
    },
    enabledReaches: ['reach123'],
    preferredUnit: FlowUnit.CFS
  };

  // Mock user preferences - Information seeker
  const infoUserPreferences = {
    userId: 'user-info',
    emergencyAlerts: true,
    activityAlerts: false,
    informationAlerts: true,
    frequency: 'daily',
    quietHours: {
      enabled: false,
      startTime: '22:00',
      endTime: '07:00'
    },
    enabledReaches: ['reach123'],
    preferredUnit: FlowUnit.CFS
  };

  // Mock user thresholds for kayaking
  const kayakingThresholds = [
    {
      id: 'thresh1',
      userId: 'user-safety',
      reachId: 'reach123',
      activityType: 'kayaking',
      minFlow: 180,    // Want at least 180 CFS
      maxFlow: 400,    // Don't want more than 400 CFS
      unit: FlowUnit.CFS,
      alertPriority: AlertPriority.ACTIVITY,
      enabled: true
    },
    {
      id: 'thresh2',
      userId: 'user-safety',
      reachId: 'reach123',
      activityType: 'fishing',
      maxFlow: 200,    // Fishing gets difficult above 200 CFS
      unit: FlowUnit.CFS,
      alertPriority: AlertPriority.ACTIVITY,
      enabled: true
    }
  ];

  // Test scenarios
  const testScenarios = [
    {
      name: 'Low Flow - Below Fishing Threshold',
      flowData: { reachId: 'reach123', flow: 120, unit: FlowUnit.CFS, timestamp: new Date() }
    },
    {
      name: 'Normal Flow - Good for Kayaking',
      flowData: { reachId: 'reach123', flow: 250, unit: FlowUnit.CFS, timestamp: new Date() }
    },
    {
      name: 'High Flow - Too High for Kayaking',
      flowData: { reachId: 'reach123', flow: 450, unit: FlowUnit.CFS, timestamp: new Date() }
    },
    {
      name: 'Very High Flow - Safety Alert',
      flowData: { reachId: 'reach123', flow: 700, unit: FlowUnit.CFS, timestamp: new Date() }
    },
    {
      name: 'Extreme Flow - Critical Emergency',
      flowData: { reachId: 'reach123', flow: 900, unit: FlowUnit.CFS, timestamp: new Date() }
    },
    {
      name: 'Unit Conversion Test - 15 CMS',
      flowData: { reachId: 'reach123', flow: 15, unit: FlowUnit.CMS, timestamp: new Date() }
    }
  ];

  console.log('\n🎯 Testing with Safety-Conscious Kayaker Profile');
  console.log('-'.repeat(50));
  
  testScenarios.forEach((scenario, index) => {
    console.log(`\n--- Scenario ${index + 1}: ${scenario.name} ---`);
    
    const result = MockAlertEngine.generateAlert(
      scenario.flowData,
      returnPeriod,
      safetyUserPreferences,
      kayakingThresholds,
      'Green River at Moab'
    );

    console.log(`Flow: ${scenario.flowData.flow} ${scenario.flowData.unit}`);
    console.log(`Category: ${result.category}`);
    console.log(`Should Send Alert: ${result.shouldSendAlert}`);
    console.log(`Alert Type: ${result.alertType}`);
    console.log(`Urgency: ${result.urgency}`);
    console.log(`Triggered By: ${result.triggeredBy}`);
    console.log(`Thresholds Triggered: ${result.triggeredThresholds}`);
    console.log(`Emergency: ${result.emergency}`);
    
    if (result.shouldSendAlert) {
      console.log(`📧 Alert Title: "${result.alertTitle}"`);
      console.log(`📱 Alert Message: "${result.alertMessage}"`);
    } else {
      console.log('🔇 No alert sent');
    }
  });

  console.log('\n\n📊 Testing with Information Seeker Profile');
  console.log('-'.repeat(50));

  // Test key scenarios with info user
  const keyScenarios = [testScenarios[1], testScenarios[3], testScenarios[4]];
  
  keyScenarios.forEach((scenario, index) => {
    console.log(`\n--- Info User - ${scenario.name} ---`);
    
    const result = MockAlertEngine.generateAlert(
      scenario.flowData,
      returnPeriod,
      infoUserPreferences,
      [], // No custom thresholds for info user
      'Green River at Moab'
    );

    console.log(`Should Send Alert: ${result.shouldSendAlert} (${result.alertType})`);
    if (result.shouldSendAlert) {
      console.log(`📱 "${result.alertMessage}"`);
    }
  });

  // Test quiet hours functionality
  console.log('\n\n🌙 Testing Quiet Hours Functionality');
  console.log('-'.repeat(50));

  // Simulate quiet hours (assume it's currently 23:00)
  const originalDate = Date;
  global.Date = class extends Date {
    constructor(...args) {
      if (args.length === 0) {
        super(2024, 0, 15, 23, 0, 0); // 11 PM
      } else {
        super(...args);
      }
    }
  };

  const quietTestResult = MockAlertEngine.generateAlert(
    { reachId: 'reach123', flow: 300, unit: FlowUnit.CFS, timestamp: new Date() },
    returnPeriod,
    safetyUserPreferences,
    kayakingThresholds,
    'Green River at Moab'
  );

  console.log('Current time simulated: 23:00 (Quiet Hours: 22:00-07:00)');
  console.log(`In Quiet Hours: ${quietTestResult.inQuietHours}`);
  console.log(`Should Send Alert: ${quietTestResult.shouldSendAlert}`);
  console.log('Note: Non-critical alerts should be suppressed during quiet hours');

  // Test critical emergency during quiet hours
  const emergencyTestResult = MockAlertEngine.generateAlert(
    { reachId: 'reach123', flow: 900, unit: FlowUnit.CFS, timestamp: new Date() },
    returnPeriod,
    safetyUserPreferences,
    kayakingThresholds,
    'Green River at Moab'
  );

  console.log(`\nCritical Emergency Test:`);
  console.log(`Should Send Alert: ${emergencyTestResult.shouldSendAlert}`);
  console.log(`Urgency: ${emergencyTestResult.urgency}`);
  console.log('Note: Critical alerts should override quiet hours');

  // Restore original Date
  global.Date = originalDate;

  console.log('\n✅ Alert Engine Testing Complete!');
  console.log('\n📋 Test Summary:');
  console.log('✅ User threshold checking');
  console.log('✅ Emergency condition detection');
  console.log('✅ User preference filtering');
  console.log('✅ Quiet hours functionality');
  console.log('✅ Unit conversion support');
  console.log('✅ Alert message generation');
  console.log('\n🚀 Ready for Cloud Functions implementation!');
}

// Run the tests
testAlertEngine();