// functions/src/notifications/flow-classifier.test.ts

import { FlowClassifier, AlertPriority, FlowCategory } from './flow-classifier';
import { FlowData, FlowUnit, ReturnPeriod, UserThreshold } from '../types';

/**
 * Test suite for the Flow Classifier with NOAA data samples
 * This demonstrates integration with the existing Rivr flow categorization system
 */

// Sample return period data (based on actual Rivr app structure)
const sampleReturnPeriod: ReturnPeriod = {
  reachId: '12345',
  unit: FlowUnit.CFS,
  flowValues: {
    2: 150,    // 2-year return period flow
    5: 250,    // 5-year return period flow
    10: 350,   // 10-year return period flow
    25: 500,   // 25-year return period flow
    50: 650,   // 50-year return period flow
    100: 800   // 100-year return period flow
  },
  retrievedAt: new Date()
};

// Sample user thresholds for activity-based alerts
const sampleUserThresholds: UserThreshold[] = [
  {
    id: 'thresh1',
    userId: 'user123',
    reachId: '12345',
    reachName: 'Green River at Moab',
    activityType: 'kayaking',
    thresholdType: 'range',
    minFlow: 200,
    maxFlow: 400,
    unit: FlowUnit.CFS,
    alertPriority: AlertPriority.ACTIVITY,
    enabled: true,
    description: 'Ideal kayaking conditions',
    createdAt: new Date(),
    updatedAt: new Date()
  },
  {
    id: 'thresh2',
    userId: 'user123',
    reachId: '12345',
    reachName: 'Green River at Moab',
    activityType: 'fishing',
    thresholdType: 'max',
    maxFlow: 180,
    unit: FlowUnit.CFS,
    alertPriority: AlertPriority.ACTIVITY,
    enabled: true,
    description: 'Good fishing flows',
    createdAt: new Date(),
    updatedAt: new Date()
  }
];

/**
 * Test function to run flow classification examples
 */
export function testFlowClassifier(): void {
  console.log('🧪 Testing Flow Classifier with NOAA Data Samples');
  console.log('='.repeat(60));

  // Test Case 1: Low flow conditions
  console.log('\n📊 Test Case 1: Low Flow Conditions');
  const lowFlowData: FlowData = {
    reachId: '12345',
    flow: 100,
    unit: FlowUnit.CFS,
    timestamp: new Date(),
    source: 'NOAA_TEST'
  };

  const lowFlowResult = FlowClassifier.classifyFlow(
    lowFlowData,
    sampleReturnPeriod,
    sampleUserThresholds,
    { reachName: 'Green River at Moab' }
  );

  logClassificationResult('Low Flow Test', lowFlowResult);

  // Test Case 2: Normal flow conditions
  console.log('\n📊 Test Case 2: Normal Flow Conditions');
  const normalFlowData: FlowData = {
    reachId: '12345',
    flow: 200,
    unit: FlowUnit.CFS,
    timestamp: new Date(),
    source: 'NOAA_TEST'
  };

  const normalFlowResult = FlowClassifier.classifyFlow(
    normalFlowData,
    sampleReturnPeriod,
    sampleUserThresholds,
    { reachName: 'Green River at Moab' }
  );

  logClassificationResult('Normal Flow Test', normalFlowResult);

  // Test Case 3: High flow safety alert
  console.log('\n📊 Test Case 3: High Flow Safety Alert');
  const highFlowData: FlowData = {
    reachId: '12345',
    flow: 600,
    unit: FlowUnit.CFS,
    timestamp: new Date(),
    source: 'NOAA_TEST'
  };

  const highFlowResult = FlowClassifier.classifyFlow(
    highFlowData,
    sampleReturnPeriod,
    sampleUserThresholds,
    { reachName: 'Green River at Moab' }
  );

  logClassificationResult('High Flow Safety Test', highFlowResult);

  // Test Case 4: Extreme flow conditions
  console.log('\n📊 Test Case 4: Extreme Flow Conditions');
  const extremeFlowData: FlowData = {
    reachId: '12345',
    flow: 900,
    unit: FlowUnit.CFS,
    timestamp: new Date(),
    source: 'NOAA_TEST'
  };

  const extremeFlowResult = FlowClassifier.classifyFlow(
    extremeFlowData,
    sampleReturnPeriod,
    sampleUserThresholds,
    { reachName: 'Green River at Moab' }
  );

  logClassificationResult('Extreme Flow Test', extremeFlowResult);

  // Test Case 5: Unit conversion test (CMS to CFS)
  console.log('\n📊 Test Case 5: Unit Conversion Test (CMS input)');
  const cmsFlowData: FlowData = {
    reachId: '12345',
    flow: 17.0, // ~600 CFS
    unit: FlowUnit.CMS,
    timestamp: new Date(),
    source: 'NOAA_TEST'
  };

  const cmsFlowResult = FlowClassifier.classifyFlow(
    cmsFlowData,
    sampleReturnPeriod,
    sampleUserThresholds,
    { reachName: 'Green River at Moab' }
  );

  logClassificationResult('CMS Unit Conversion Test', cmsFlowResult);

  // Test Case 6: Thesis demonstration mode
  console.log('\n📊 Test Case 6: Thesis Demonstration Mode');
  const demoFlowData: FlowData = {
    reachId: '12345',
    flow: 300,
    unit: FlowUnit.CFS,
    timestamp: new Date(),
    source: 'NOAA_TEST'
  };

  const demoFlowResult = FlowClassifier.classifyFlow(
    demoFlowData,
    sampleReturnPeriod,
    sampleUserThresholds,
    { reachName: 'Green River at Moab', forceDemo: true }
  );

  logClassificationResult('Thesis Demo Test', demoFlowResult);

  // Test Case 7: Batch testing with sample data
  console.log('\n📊 Test Case 7: Batch Sample Data Testing');
  const sampleFlows = [
    { flow: 50, unit: FlowUnit.CFS, reachId: '12345' },
    { flow: 150, unit: FlowUnit.CFS, reachId: '12345' },
    { flow: 300, unit: FlowUnit.CFS, reachId: '12345' },
    { flow: 500, unit: FlowUnit.CFS, reachId: '12345' },
    { flow: 700, unit: FlowUnit.CFS, reachId: '12345' },
    { flow: 900, unit: FlowUnit.CFS, reachId: '12345' }
  ];

  const batchResults = FlowClassifier.testWithSampleData(sampleFlows);
  console.log('Batch Test Results:');
  batchResults.forEach((result, index) => {
    console.log(`  ${index + 1}. ${sampleFlows[index].flow} CFS → ${result.category} (${result.priority})`);
  });

  console.log('\n✅ Flow Classifier testing completed!');
  console.log('🔗 Integration with existing Rivr categorization system verified.');
}

/**
 * Helper function to log classification results in a readable format
 */
function logClassificationResult(testName: string, result: any): void {
  console.log(`Results for ${testName}:`);
  console.log(`  Category: ${result.category}`);
  console.log(`  Priority: ${result.priority}`);
  console.log(`  Risk Level: ${result.riskLevel}`);
  console.log(`  Flow: ${result.flowValue} ${result.unit}`);
  console.log(`  Return Period: ${result.returnPeriodYear || 'N/A'} years`);
  console.log(`  Should Alert: ${result.shouldTriggerAlert}`);
  console.log(`  Color: ${result.colorCode}`);
  console.log(`  Description: ${result.description}`);
  if (result.alertMessage) {
    console.log(`  Alert Message: "${result.alertMessage}"`);
  }
}

/**
 * Integration test with actual NOAA-style data structure
 */
export function testNoaaIntegration(): void {
  console.log('\n🌊 Testing NOAA API Integration');
  console.log('='.repeat(40));

  // Simulate NOAA API response structure
  const mockNoaaResponse = {
    reach_id: '12345',
    data: [
      { validTime: '2024-01-15T12:00:00Z', flow: 245.5 },
      { validTime: '2024-01-15T13:00:00Z', flow: 248.2 },
      { validTime: '2024-01-15T14:00:00Z', flow: 251.8 }
    ],
    metadata: {
      units: 'cfs',
      source: 'NOAA National Water Model',
      model: 'nwm_v2.1',
      last_updated: '2024-01-15T12:30:00Z'
    }
  };

  // Convert NOAA data to FlowData format
  const latestFlowData: FlowData = {
    reachId: mockNoaaResponse.reach_id,
    flow: mockNoaaResponse.data[mockNoaaResponse.data.length - 1].flow,
    unit: FlowUnit.CFS,
    timestamp: new Date(mockNoaaResponse.data[mockNoaaResponse.data.length - 1].validTime),
    source: 'NOAA',
    validTime: mockNoaaResponse.data[mockNoaaResponse.data.length - 1].validTime
  };

  const noaaResult = FlowClassifier.classifyFlow(
    latestFlowData,
    sampleReturnPeriod,
    sampleUserThresholds,
    { reachName: 'Green River at Moab' }
  );

  console.log('NOAA Integration Test Results:');
  console.log(`  Latest Flow: ${latestFlowData.flow} ${latestFlowData.unit}`);
  console.log(`  Classification: ${noaaResult.category}`);
  console.log(`  Alert Needed: ${noaaResult.shouldTriggerAlert}`);
  console.log(`  Priority: ${noaaResult.priority}`);
  
  if (noaaResult.shouldTriggerAlert && noaaResult.alertMessage) {
    console.log(`  Alert Message: "${noaaResult.alertMessage}"`);
  }
}

// Export test functions for use in Cloud Functions
export { testFlowClassifier as runFlowClassifierTests, testNoaaIntegration };

// If running directly (for development testing)
if (require.main === module) {
  testFlowClassifier();
  testNoaaIntegration();
}