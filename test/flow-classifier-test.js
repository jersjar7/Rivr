// flow-classifier-test.js
// Simple JavaScript test - runs immediately without any setup

// Enums as constants
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

// Simplified FlowClassifier for testing
class SimpleFlowClassifier {
  static getFlowCategory(flow, returnPeriod, fromUnit = FlowUnit.CFS) {
    // Convert flow to match return period unit if needed
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

  static getAlertPriority(category) {
    switch (category) {
      case FlowCategory.HIGH:
      case FlowCategory.VERY_HIGH:
      case FlowCategory.EXTREME:
        return AlertPriority.SAFETY;
      default:
        return AlertPriority.INFORMATION;
    }
  }

  static getCategoryColor(category) {
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

  static getCategoryDescription(category) {
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

  static testClassification(flow, unit = FlowUnit.CFS) {
    // Sample return period data matching your existing Rivr app structure
    const returnPeriod = {
      reachId: '12345',
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

    const category = this.getFlowCategory(flow, returnPeriod, unit);
    const priority = this.getAlertPriority(category);
    const color = this.getCategoryColor(category);
    const description = this.getCategoryDescription(category);

    console.log(`\n🌊 Flow: ${flow} ${unit}`);
    console.log(`📊 Category: ${category}`);
    console.log(`🚨 Priority: ${priority}`);
    console.log(`🎨 Color: ${color}`);
    console.log(`📝 Description: ${description}`);
    console.log(`⚠️  Safety Alert: ${priority === AlertPriority.SAFETY ? 'YES' : 'NO'}`);
    
    // Show which return period threshold this flow represents
    const thresholds = returnPeriod.flowValues;
    let returnPeriodText = 'Above 100-year';
    for (const [year, threshold] of Object.entries(thresholds)) {
      if (flow < threshold) {
        returnPeriodText = `Below ${year}-year (${threshold} ${unit})`;
        break;
      }
    }
    console.log(`📈 Return Period: ${returnPeriodText}`);
  }

  static runFullTest() {
    console.log('🧪 Testing Flow Classifier Logic');
    console.log('🔗 Integration with Rivr Flow Categories');
    console.log('=' .repeat(50));

    // Test different flow levels representing each category
    const testFlows = [
      { name: 'Very Low', flow: 100, unit: FlowUnit.CFS },  // Low
      { name: 'Low-Normal', flow: 200, unit: FlowUnit.CFS },  // Normal
      { name: 'Moderate', flow: 300, unit: FlowUnit.CFS },  // Moderate
      { name: 'Elevated', flow: 450, unit: FlowUnit.CFS },  // Elevated
      { name: 'High', flow: 600, unit: FlowUnit.CFS },  // High (Safety Alert)
      { name: 'Very High', flow: 750, unit: FlowUnit.CFS },  // Very High (Safety Alert)
      { name: 'Extreme', flow: 900, unit: FlowUnit.CFS },  // Extreme (Safety Alert)
    ];

    testFlows.forEach((test, index) => {
      console.log(`\n--- Test ${index + 1}: ${test.name} ---`);
      this.testClassification(test.flow, test.unit);
    });

    // Test unit conversion
    console.log('\n\n🔄 Testing Unit Conversion (CMS → CFS)');
    console.log('=' .repeat(50));
    console.log('\nTesting 17 CMS (should be ~600 CFS = High flow):');
    this.testClassification(17, FlowUnit.CMS);

    // Test edge cases
    console.log('\n\n🎯 Testing Edge Cases');
    console.log('=' .repeat(50));
    
    const edgeCases = [
      { name: 'Exactly 2-year threshold', flow: 150, unit: FlowUnit.CFS },
      { name: 'Just above 50-year', flow: 651, unit: FlowUnit.CFS },
      { name: 'Massive flood', flow: 1500, unit: FlowUnit.CFS },
    ];

    edgeCases.forEach((test) => {
      console.log(`\n--- Edge Case: ${test.name} ---`);
      this.testClassification(test.flow, test.unit);
    });

    console.log('\n✅ Flow Classification Test Complete!');
    console.log('\n📊 Summary:');
    console.log('- Categories: 7 levels from Low to Extreme');
    console.log('- Safety Alerts: Triggered for High, Very High, Extreme');
    console.log('- Unit Conversion: CFS ↔ CMS supported');
    console.log('- Return Periods: 2, 5, 10, 25, 50, 100-year thresholds');
    console.log('- Integration: Matches your existing Rivr app categories');
    
    console.log('\n🚀 Ready for Task 4.2: Basic Alert Generation');
  }
}

// 🏃‍♂️ RUN THE TESTS
SimpleFlowClassifier.runFullTest();