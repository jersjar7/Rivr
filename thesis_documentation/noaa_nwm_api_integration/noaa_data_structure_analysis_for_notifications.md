# Task 3.2 - NOAA Data Structure Analysis for Notification System

## Current Rivr Data Models (Working Implementation)

### **Forecast Data Structure**
```dart
// Individual forecast point
class ForecastModel {
  final String reachId;
  final String validTime;      // ISO datetime string
  final double flow;           // Flow value
  final ForecastType forecastType; // short_range, medium_range, long_range
  final DateTime retrievedAt;  // When data was fetched
  final String? member;        // Ensemble member (e.g., "member1")
}

// Collection of forecasts
class ForecastCollectionModel {
  final String reachId;
  final ForecastType forecastType;
  final List<ForecastModel> forecasts;
  final DateTime retrievedAt;
}
```

### **Return Period Data Structure**
```dart
class ReturnPeriod {
  final String reachId;
  final Map<int, double> flowValues;  // {2: 1200.0, 5: 1800.0, 10: 2200.0...}
  final DateTime retrievedAt;
  final FlowUnit unit;  // CFS or CMS
  
  // Methods for flood analysis
  String getFlowCategory(double flow);     // "Low", "Normal", "High", "Extreme"
  int? getReturnPeriod(double flow);       // Closest return period year
}
```

### **Data Processing Features (Already Working)**
- ✅ **Unit Conversion**: CFS ↔ CMS with FlowUnitsService
- ✅ **Flow Categorization**: Low/Normal/Moderate/Elevated/High/Very High/Extreme
- ✅ **Return Period Analysis**: 2, 5, 10, 25, 50, 100-year flood levels
- ✅ **Daily Aggregation**: Min, max, mean flow values per day
- ✅ **Error Handling**: Network, server, format exceptions
- ✅ **Caching**: Timestamp-based cache invalidation

## Mapping to Cloud Functions Data Structure

### **Enhanced Data Model for Notifications**
```typescript
// Base streamflow data (compatible with existing Rivr models)
interface StreamflowData {
  reachId: string;
  currentFlow: number;
  unit: 'CFS' | 'CMS';
  validTime: string;           // ISO datetime
  retrievedAt: Date;
  source: 'NOAA_NWM';
  
  // Enhanced for notifications
  forecast?: StreamflowForecast[];
  returnPeriod?: ReturnPeriodData;
  flowCategory?: FlowCategory;
  previousFlow?: number;       // For change detection
  changePercent?: number;      // Percentage change from previous
}

// Forecast data structure
interface StreamflowForecast {
  validTime: string;
  flow: number;
  forecastType: 'short_range' | 'medium_range' | 'long_range';
  member?: string;
}

// Return period data for flood context
interface ReturnPeriodData {
  reachId: string;
  flowValues: { [year: number]: number };  // {2: 1200, 5: 1800, ...}
  unit: 'CFS' | 'CMS';
  retrievedAt: Date;
}

// Flow categorization for notifications
type FlowCategory = 'Low' | 'Normal' | 'Moderate' | 'Elevated' | 'High' | 'Very High' | 'Extreme';
```

## Data Transformation Requirements

### **1. NOAA API Response → Streamflow Data**
```typescript
// Current NOAA API response format (from working implementation)
interface NOAAStreamflowResponse {
  shortRange?: {
    series?: {
      data: Array<{
        validTime: string;
        flow: number;
      }>;
    };
    member1?: { data: Array<{ validTime: string; flow: number; }>; };
    // ... up to member6
  };
  mediumRange?: { /* similar structure */ };
  longRange?: { /* similar structure */ };
}

// Transformation function
function transformNOAAResponse(
  response: NOAAStreamflowResponse, 
  reachId: string
): StreamflowData {
  // Extract current flow (latest short-range value)
  const currentFlow = extractLatestFlow(response.shortRange);
  
  // Extract forecast array
  const forecast = extractAllForecasts(response);
  
  return {
    reachId,
    currentFlow: currentFlow.flow,
    unit: 'CFS',  // NOAA API returns CFS
    validTime: currentFlow.validTime,
    retrievedAt: new Date(),
    source: 'NOAA_NWM',
    forecast,
  };
}
```

### **2. Return Period Integration**
```typescript
// Existing return period API format
interface ReturnPeriodResponse {
  comid: string;
  return_period_2: number;
  return_period_5: number;
  return_period_10: number;
  return_period_25: number;
  return_period_50: number;
  return_period_100: number;
}

// Enhanced with flow categorization
function addFlowContext(
  streamflowData: StreamflowData,
  returnPeriodData: ReturnPeriodResponse
): StreamflowData {
  const returnPeriod: ReturnPeriodData = {
    reachId: streamflowData.reachId,
    flowValues: {
      2: returnPeriodData.return_period_2,
      5: returnPeriodData.return_period_5,
      10: returnPeriodData.return_period_10,
      25: returnPeriodData.return_period_25,
      50: returnPeriodData.return_period_50,
      100: returnPeriodData.return_period_100,
    },
    unit: 'CMS', // Return period API returns CMS
    retrievedAt: new Date(),
  };

  return {
    ...streamflowData,
    returnPeriod,
    flowCategory: categorizeFlow(streamflowData.currentFlow, returnPeriod),
  };
}
```

### **3. Change Detection for Notifications**
```typescript
// Enhanced with change detection
function addChangeDetection(
  currentData: StreamflowData,
  previousData?: StreamflowData
): StreamflowData {
  if (!previousData) {
    return currentData;
  }

  const changePercent = ((currentData.currentFlow - previousData.currentFlow) / 
                        previousData.currentFlow) * 100;

  return {
    ...currentData,
    previousFlow: previousData.currentFlow,
    changePercent: Math.round(changePercent * 100) / 100, // Round to 2 decimals
  };
}
```

## Integration with Existing Rivr System

### **Compatibility Considerations**
1. **✅ Maintain Data Format**: Cloud Functions data should be convertible to existing Dart models
2. **✅ Unit Consistency**: Support both CFS/CMS with conversion utilities
3. **✅ Timestamp Format**: Use ISO strings compatible with Flutter DateTime parsing
4. **✅ Error Handling**: Similar error response format as existing API calls

### **Data Flow Enhancement**
```typescript
// Current Rivr app flow (Flutter)
ForecastRemoteDataSource → ForecastModel → UI

// Enhanced flow with notifications (Cloud Functions + Flutter)
NOAA API → Cloud Functions → Firestore Cache → Threshold Check → FCM Notification
                ↓
            Flutter App (existing) + Notification Handler
```

### **Caching Strategy Enhancement**
```typescript
// Firestore cache document structure (extends existing caching)
interface CachedStreamflowData extends StreamflowData {
  cacheKey: string;          // "reach_${reachId}_${date}"
  expiresAt: Date;           // Cache expiration
  lastModified: Date;        // For change detection
  notificationSent?: Date;   // Track if notification sent for this data
}
```

## Notification-Specific Data Requirements

### **Threshold Evaluation Context**
```typescript
interface ThresholdEvaluationContext {
  streamflowData: StreamflowData;
  userThreshold: {
    value: number;
    unit: 'CFS' | 'CMS';
    alertType: 'above' | 'below' | 'range';
    activity: string;  // "fishing", "kayaking", "safety"
  };
  evaluationResult: {
    triggered: boolean;
    currentValue: number;
    thresholdValue: number;
    changeFromPrevious?: number;
    riskLevel?: 'low' | 'moderate' | 'high' | 'extreme';
  };
}
```

### **Notification Message Context**
```typescript
interface NotificationContext {
  reachId: string;
  stationName: string;
  currentFlow: number;
  unit: 'CFS' | 'CMS';
  flowCategory: FlowCategory;
  changePercent?: number;
  returnPeriodYear?: number;  // If flood level exceeded
  activity?: string;
  alertPriority: 'low' | 'medium' | 'high' | 'urgent';
}
```

## Performance Optimization Strategy

### **Batch Processing for Multiple Reaches**
```typescript
// Efficient batch fetching (extending existing API patterns)
class NOAABatchService {
  async fetchMultipleReaches(reachIds: string[]): Promise<StreamflowData[]> {
    // Parallel API calls with rate limiting
    const batchSize = 5;  // Respect API limits
    const batches = chunk(reachIds, batchSize);
    const results: StreamflowData[] = [];
    
    for (const batch of batches) {
      const batchPromises = batch.map(reachId => 
        this.fetchSingleReach(reachId).catch(error => {
          console.warn(`Failed to fetch ${reachId}:`, error);
          return null; // Continue with other reaches
        })
      );
      
      const batchResults = await Promise.all(batchPromises);
      results.push(...batchResults.filter(Boolean));
      
      // Rate limiting delay
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
    
    return results;
  }
}
```

### **Geographic Coverage for Thesis**
Based on existing implementation, focus on:
- **CONUS rivers**: Primary user base
- **Popular recreation areas**: High-usage stations
- **Flood-prone areas**: Safety-critical locations
- **Diverse flow ranges**: Good for threshold testing

### **Data Validation Strategy**
```typescript
// Validation using existing patterns
function validateStreamflowData(data: StreamflowData): boolean {
  return (
    data.reachId?.length > 0 &&
    typeof data.currentFlow === 'number' &&
    data.currentFlow >= 0 &&
    ['CFS', 'CMS'].includes(data.unit) &&
    data.validTime?.length > 0 &&
    data.source === 'NOAA_NWM'
  );
}
```

## Next Steps for Implementation

1. **✅ Leverage Existing API Logic**: Port working ForecastRemoteDataSource to TypeScript
2. **✅ Extend Data Models**: Add notification-specific fields to existing structures  
3. **✅ Maintain Compatibility**: Ensure Cloud Functions data can be consumed by existing Flutter app
4. **✅ Add Batch Processing**: Implement efficient multiple-reach fetching
5. **✅ Integrate Caching**: Use Firestore as server-side cache with existing patterns

This analysis shows the current NOAA integration is already sophisticated and notification-ready. The enhancement focuses on server-side batch processing and threshold evaluation rather than rebuilding the data layer.