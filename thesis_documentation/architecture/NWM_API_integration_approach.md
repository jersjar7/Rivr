# NOAA National Water Model API Integration Approach

## NOAA National Water Model Overview

### About the National Water Model (NWM)
The NOAA National Water Model is a comprehensive hydrologic modeling framework that provides streamflow forecasts and other water-related information across the continental United States. It's designed to improve water resource management and flood forecasting capabilities.

### Key Capabilities
- **Real-time Streamflow**: Current flow conditions at thousands of stream reaches
- **Forecasting**: Short-term (48 hours) and medium-term (30 days) flow predictions
- **Comprehensive Coverage**: Continental United States with high spatial resolution
- **Multiple Data Formats**: Various output formats and delivery mechanisms
- **Regular Updates**: Hourly model runs with updated forecasts

## API Research and Access Strategy

### Primary API Endpoints

#### 1. NOAA Water Data Services API
```
Base URL: https://api.water.noaa.gov/nwps/v1/
Endpoints:
- /reaches/{reachID}/streamflow - Current streamflow data
- /reaches/{reachID}/forecast - Streamflow forecasts  
- /reaches/search - Search for monitoring reaches
- /metadata/reaches - Reach metadata and information
```

#### 2. Alternative Data Sources
```
USGS Water Services (Backup):
Base URL: https://waterservices.usgs.gov/nwis/
- Current conditions API
- Statistical services API
- Site information services

NOAA Weather API (Supplementary):
Base URL: https://api.weather.gov/
- Weather conditions affecting flow
- Precipitation forecasts
```

### Authentication and Access

#### API Key Requirements
```javascript
// NOAA API Configuration
const NOAA_CONFIG = {
  baseUrl: 'https://api.water.noaa.gov/nwps/v1/',
  apiKey: process.env.NOAA_API_KEY, // If required
  userAgent: 'Rivr-Thesis-Research/1.0 (university-email@domain.edu)',
  timeout: 30000, // 30 second timeout
  retryAttempts: 3
};
```

#### Rate Limiting and Usage Constraints
- **Request Limits**: Typical government APIs allow 1000-5000 requests per hour
- **Bulk Requests**: Batch multiple reach IDs in single requests when possible
- **Caching Requirements**: Cache data to minimize API calls
- **Fair Use Policy**: Respect API terms and avoid excessive usage

### Data Format Analysis

#### Expected NOAA Response Format
```json
{
  "reachID": "101003005",
  "streamflow": {
    "value": 1250.5,
    "unit": "CFS",
    "timestamp": "2024-06-10T15:30:00Z",
    "quality": "good"
  },
  "location": {
    "latitude": 40.7589,
    "longitude": -111.8883,
    "name": "Bear Creek near Salt Lake City, UT",
    "state": "UT"
  },
  "forecast": [
    {
      "timestamp": "2024-06-10T16:00:00Z",
      "value": 1245.2,
      "confidence": "high"
    },
    {
      "timestamp": "2024-06-10T17:00:00Z", 
      "value": 1240.8,
      "confidence": "high"
    }
  ],
  "metadata": {
    "model_run": "2024-06-10T12:00:00Z",
    "units": "CFS",
    "drainage_area": 45.2,
    "datum": "NAVD88"
  }
}
```

#### Current Rivr Data Format (For Comparison)
```json
{
  "stationId": "station_123",
  "name": "Bear Creek",
  "flow": 1250.5,
  "unit": "CFS",
  "timestamp": "2024-06-10T15:30:00Z",
  "location": {
    "latitude": 40.7589,
    "longitude": -111.8883
  },
  "status": "active"
}
```

## Data Transformation Strategy

### NOAA to Rivr Data Mapping
```typescript
interface NOAAResponse {
  reachID: string;
  streamflow: {
    value: number;
    unit: string;
    timestamp: string;
    quality: string;
  };
  location: {
    latitude: number;
    longitude: number;
    name: string;
    state: string;
  };
  forecast?: Array<{
    timestamp: string;
    value: number;
    confidence: string;
  }>;
}

interface RivrFlowData {
  stationId: string;
  name: string;
  flow: number;
  unit: string;
  timestamp: string;
  location: {
    latitude: number;
    longitude: number;
  };
  source: 'NOAA_NWM';
  quality: 'good' | 'fair' | 'poor';
  forecast?: Array<{
    timestamp: string;
    value: number;
  }>;
}

// Transformation function
function transformNOAAToRivr(noaaData: NOAAResponse): RivrFlowData {
  return {
    stationId: `noaa_${noaaData.reachID}`,
    name: noaaData.location.name,
    flow: noaaData.streamflow.value,
    unit: noaaData.streamflow.unit,
    timestamp: noaaData.streamflow.timestamp,
    location: {
      latitude: noaaData.location.latitude,
      longitude: noaaData.location.longitude
    },
    source: 'NOAA_NWM',
    quality: mapQuality(noaaData.streamflow.quality),
    forecast: noaaData.forecast?.map(f => ({
      timestamp: f.timestamp,
      value: f.value
    }))
  };
}
```

### Unit Conversion Handling
```typescript
class UnitConverter {
  static convertFlow(value: number, fromUnit: string, toUnit: string): number {
    // CFS to CMS conversion
    if (fromUnit === 'CFS' && toUnit === 'CMS') {
      return value * 0.028317; // 1 CFS = 0.028317 CMS
    }
    
    // CMS to CFS conversion  
    if (fromUnit === 'CMS' && toUnit === 'CFS') {
      return value * 35.3147; // 1 CMS = 35.3147 CFS
    }
    
    return value; // Same unit, no conversion needed
  }
  
  static normalizeUnit(unit: string): 'CFS' | 'CMS' {
    const normalized = unit.toUpperCase();
    return ['CFS', 'CUBIC FEET PER SECOND'].includes(normalized) ? 'CFS' : 'CMS';
  }
}
```

## Integration Implementation Architecture

### Cloud Functions Service Layer
```typescript
// functions/src/noaa/noaa-service.ts
export class NOAAService {
  private readonly apiConfig = {
    baseUrl: 'https://api.water.noaa.gov/nwps/v1/',
    timeout: 30000,
    retryAttempts: 3
  };

  async fetchFlowData(reachIds: string[]): Promise<RivrFlowData[]> {
    try {
      // Batch API requests for multiple reaches
      const responses = await this.batchFetchReaches(reachIds);
      
      // Transform NOAA format to Rivr format
      const transformedData = responses.map(this.transformNOAAToRivr);
      
      // Cache data in Firestore
      await this.cacheFlowData(transformedData);
      
      return transformedData;
    } catch (error) {
      console.error('NOAA API Error:', error);
      throw new Error(`Failed to fetch NOAA data: ${error.message}`);
    }
  }

  private async batchFetchReaches(reachIds: string[]): Promise<NOAAResponse[]> {
    const batchSize = 10; // Respect API limits
    const batches = this.chunkArray(reachIds, batchSize);
    const results: NOAAResponse[] = [];

    for (const batch of batches) {
      const batchPromises = batch.map(reachId => this.fetchSingleReach(reachId));
      const batchResults = await Promise.allSettled(batchPromises);
      
      batchResults.forEach(result => {
        if (result.status === 'fulfilled') {
          results.push(result.value);
        } else {
          console.warn('Failed to fetch reach:', result.reason);
        }
      });
      
      // Rate limiting delay between batches
      await this.delay(1000);
    }

    return results;
  }

  private async fetchSingleReach(reachId: string): Promise<NOAAResponse> {
    const url = `${this.apiConfig.baseUrl}/reaches/${reachId}/streamflow`;
    
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Rivr-Thesis-Research/1.0',
        'Accept': 'application/json'
      },
      timeout: this.apiConfig.timeout
    });

    if (!response.ok) {
      throw new Error(`NOAA API Error: ${response.status} ${response.statusText}`);
    }

    return await response.json() as NOAAResponse;
  }

  private async cacheFlowData(data: RivrFlowData[]): Promise<void> {
    const firestore = admin.firestore();
    const batch = firestore.batch();

    data.forEach(flowData => {
      const docRef = firestore.collection('noaaFlowCache').doc(flowData.stationId);
      batch.set(docRef, {
        ...flowData,
        cachedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: new Date(Date.now() + 30 * 60 * 1000) // 30 minutes
      });
    });

    await batch.commit();
  }
}
```

### Error Handling and Fallback Strategy
```typescript
class NOAAErrorHandler {
  static async handleAPIError(error: any, reachId: string): Promise<RivrFlowData | null> {
    console.error(`NOAA API Error for reach ${reachId}:`, error);

    // Try to return cached data if available
    const cachedData = await this.getCachedData(reachId);
    if (cachedData && !this.isCacheExpired(cachedData)) {
      console.log(`Returning cached data for reach ${reachId}`);
      return cachedData;
    }

    // Try USGS backup API if NOAA fails
    try {
      const usgsData = await this.fetchUSGSBackup(reachId);
      return usgsData;
    } catch (usgsError) {
      console.error(`Backup USGS API also failed for reach ${reachId}:`, usgsError);
      return null;
    }
  }

  private static async getCachedData(reachId: string): Promise<RivrFlowData | null> {
    try {
      const doc = await admin.firestore()
        .collection('noaaFlowCache')
        .doc(reachId)
        .get();
      
      return doc.exists ? doc.data() as RivrFlowData : null;
    } catch (error) {
      console.error('Error fetching cached data:', error);
      return null;
    }
  }
}
```

### Scheduled Data Fetching
```typescript
// Cloud Function for scheduled NOAA data fetching
export const fetchNOAAData = functions.pubsub
  .schedule('every 30 minutes')
  .timeZone('America/Denver')
  .onRun(async (context) => {
    try {
      // Get all user-subscribed reach IDs
      const subscribedReaches = await getUserSubscribedReaches();
      
      // Fetch current data from NOAA
      const noaaService = new NOAAService();
      const flowData = await noaaService.fetchFlowData(subscribedReaches);
      
      // Check for threshold violations and send notifications
      await processThresholdAlerts(flowData);
      
      console.log(`Successfully processed ${flowData.length} NOAA data points`);
    } catch (error) {
      console.error('Error in scheduled NOAA fetch:', error);
      // Alert administrators of API issues
      await notifyAdministrators('NOAA API Error', error.message);
    }
  });
```

## Geographic Coverage and Station Mapping

### NOAA Reach ID to Geographic Mapping
```typescript
interface NOAAReach {
  reachID: string;
  name: string;
  location: {
    latitude: number;
    longitude: number;
    state: string;
    watershed: string;
  };
  characteristics: {
    drainageArea: number;
    streamOrder: number;
    length: number;
  };
}

class ReachMappingService {
  async findReachesInRegion(bounds: GeoBounds): Promise<NOAAReach[]> {
    // Query NOAA metadata API for reaches in geographic bounds
    const url = `${NOAA_CONFIG.baseUrl}/reaches/search`;
    const params = new URLSearchParams({
      minLat: bounds.south.toString(),
      maxLat: bounds.north.toString(),
      minLon: bounds.west.toString(),
      maxLon: bounds.east.toString(),
      limit: '100'
    });

    const response = await fetch(`${url}?${params}`);
    return await response.json();
  }

  async mapExistingStationsToNOAA(): Promise<Map<string, string>> {
    // Map existing Rivr stations to NOAA reach IDs
    const existingStations = await this.getExistingStations();
    const mapping = new Map<string, string>();

    for (const station of existingStations) {
      const nearbyReaches = await this.findNearbyReaches(
        station.location.latitude,
        station.location.longitude,
        5000 // 5km radius
      );

      if (nearbyReaches.length > 0) {
        // Use closest reach or best match based on name similarity
        const bestMatch = this.findBestReachMatch(station, nearbyReaches);
        mapping.set(station.id, bestMatch.reachID);
      }
    }

    return mapping;
  }
}
```

## Caching and Performance Strategy

### Multi-Level Caching Approach
```typescript
class NOAACacheManager {
  // Level 1: In-memory cache for frequent requests
  private memoryCache = new Map<string, CacheEntry>();
  
  // Level 2: Firestore cache for persistence
  private firestoreCache = admin.firestore().collection('noaaFlowCache');

  async getFlowData(reachId: string): Promise<RivrFlowData | null> {
    // Check memory cache first
    const memoryData = this.memoryCache.get(reachId);
    if (memoryData && !this.isExpired(memoryData)) {
      return memoryData.data;
    }

    // Check Firestore cache
    const firestoreData = await this.getFromFirestore(reachId);
    if (firestoreData && !this.isExpired(firestoreData)) {
      // Update memory cache
      this.memoryCache.set(reachId, firestoreData);
      return firestoreData.data;
    }

    // Data not cached or expired, fetch from NOAA
    return null;
  }

  async cacheFlowData(reachId: string, data: RivrFlowData): Promise<void> {
    const cacheEntry: CacheEntry = {
      data,
      timestamp: Date.now(),
      expiresAt: Date.now() + (30 * 60 * 1000) // 30 minutes
    };

    // Update both caches
    this.memoryCache.set(reachId, cacheEntry);
    await this.firestoreCache.doc(reachId).set(cacheEntry);
  }
}
```

### API Rate Limiting and Optimization
```typescript
class RateLimiter {
  private requestQueue: Array<() => Promise<any>> = [];
  private activeRequests = 0;
  private readonly maxConcurrent = 5;
  private readonly requestDelay = 200; // 200ms between requests

  async makeRequest<T>(requestFn: () => Promise<T>): Promise<T> {
    return new Promise((resolve, reject) => {
      this.requestQueue.push(async () => {
        try {
          this.activeRequests++;
          const result = await requestFn();
          resolve(result);
        } catch (error) {
          reject(error);
        } finally {
          this.activeRequests--;
          this.processQueue();
        }
      });

      this.processQueue();
    });
  }

  private processQueue(): void {
    if (this.activeRequests < this.maxConcurrent && this.requestQueue.length > 0) {
      const nextRequest = this.requestQueue.shift()!;
      setTimeout(() => nextRequest(), this.requestDelay);
    }
  }
}
```

## Testing and Validation Strategy

### API Integration Tests
```typescript
describe('NOAA API Integration', () => {
  let noaaService: NOAAService;

  beforeEach(() => {
    noaaService = new NOAAService();
  });

  test('fetches flow data for valid reach ID', async () => {
    const reachId = '101003005'; // Known test reach ID
    const data = await noaaService.fetchFlowData([reachId]);
    
    expect(data).toHaveLength(1);
    expect(data[0]).toHaveProperty('flow');
    expect(data[0]).toHaveProperty('unit');
    expect(data[0].source).toBe('NOAA_NWM');
  });

  test('handles API errors gracefully', async () => {
    const invalidReachId = 'invalid_reach';
    const data = await noaaService.fetchFlowData([invalidReachId]);
    
    // Should not throw, should return empty array or cached data
    expect(data).toBeDefined();
  });

  test('respects rate limits', async () => {
    const reachIds = Array.from({length: 20}, (_, i) => `reach_${i}`);
    const startTime = Date.now();
    
    await noaaService.fetchFlowData(reachIds);
    
    const endTime = Date.now();
    const duration = endTime - startTime;
    
    // Should take reasonable time due to rate limiting
    expect(duration).toBeGreaterThan(1000); // At least 1 second for rate limiting
  });
});
```

This NOAA integration approach provides a robust foundation for accessing National Water Model data while maintaining performance, reliability, and compatibility with the existing Rivr system.
