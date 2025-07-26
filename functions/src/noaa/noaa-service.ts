// functions/src/noaa/noaa-service.ts
// Cloud Functions NOAA service based on existing Rivr implementation

import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import axios, {AxiosResponse, isAxiosError} from "axios";

// Types based on existing Rivr data models
export interface StreamflowData {
  reachId: string;
  currentFlow: number;
  unit: "CFS" | "CMS";
  validTime: string;
  retrievedAt: Date;
  source: "NOAA_NWM";
  forecast?: StreamflowForecast[];
  returnPeriod?: ReturnPeriodData;
  flowCategory?: FlowCategory;
  previousFlow?: number;
  changePercent?: number;
}

export interface StreamflowForecast {
  validTime: string;
  flow: number;
  forecastType: "short_range" | "medium_range" | "long_range";
  member?: string;
}

export interface ReturnPeriodData {
  reachId: string;
  flowValues: {[year: number]: number};
  unit: "CFS" | "CMS";
  retrievedAt: Date;
}

export type FlowCategory =
  "Low" | "Normal" | "Moderate" | "Elevated" | "High" | "Very High" | "Extreme";

// NOAA API response interfaces (based on existing Rivr implementation)
interface NOAAStreamflowResponse {
  shortRange?: {
    series?: {
      data: Array<{
        validTime: string;
        flow: number;
      }>;
    };
    member1?: {data: Array<{validTime: string; flow: number}>};
    member2?: {data: Array<{validTime: string; flow: number}>};
    member3?: {data: Array<{validTime: string; flow: number}>};
    member4?: {data: Array<{validTime: string; flow: number}>};
    member5?: {data: Array<{validTime: string; flow: number}>};
    member6?: {data: Array<{validTime: string; flow: number}>};
  };
  mediumRange?: {
    series?: {data: Array<{validTime: string; flow: number}>};
  };
  longRange?: {
    member1?: {data: Array<{validTime: string; flow: number}>};
    member2?: {data: Array<{validTime: string; flow: number}>};
    member3?: {data: Array<{validTime: string; flow: number}>};
    member4?: {data: Array<{validTime: string; flow: number}>};
  };
}

interface ReturnPeriodResponse {
  comid: string;
  return_period_2: number;
  return_period_5: number;
  return_period_10: number;
  return_period_25: number;
  return_period_50: number;
  return_period_100: number;
}

interface CachedStreamflowData {
  reachId: string;
  currentFlow: number;
  unit: "CFS" | "CMS";
  validTime: string;
  retrievedAt: admin.firestore.Timestamp;
  source: "NOAA_NWM";
  forecast?: StreamflowForecast[];
  returnPeriod?: {
    reachId: string;
    flowValues: {[year: number]: number};
    unit: "CFS" | "CMS";
    retrievedAt: admin.firestore.Timestamp;
  };
  flowCategory?: FlowCategory;
  previousFlow?: number;
  changePercent?: number;
}

/**
 * NOAA Service for fetching streamflow and forecast data
 */
export class NOAAService {
  // Configuration based on existing Rivr environment
  private readonly config = {
    forecastBaseUrl: "https://api.water.noaa.gov/nwps/v1",
    returnPeriodBaseUrl: "https://nwm-api-updt-9f6idmxh.uc.gateway.dev",
    apiKey: "AIzaSyArCbLaEevrqrVPJDzu2OioM_kNmCBtsx8",
    timeout: 30000,
    retryAttempts: 3,
    batchSize: 5, // Process reaches in batches
  };

  private readonly db = admin.firestore();

  /**
   * Main method for fetching flow data (single reach)
   * @param {string} reachId - The reach identifier
   * @param {boolean} includeForecast - Whether to include forecast data
   * @return {Promise<StreamflowData | null>} Streamflow data or null
   */
  async fetchStreamflowData(
    reachId: string,
    includeForecast = true
  ): Promise<StreamflowData | null> {
    try {
      logger.info(`Fetching streamflow data for reach: ${reachId}`);

      // Check cache first
      const cachedData = await this.getCachedData(reachId);
      if (cachedData && this.isCacheValid(cachedData)) {
        logger.info(`Using cached data for reach: ${reachId}`);
        return cachedData;
      }

      // Fetch from NOAA API
      const streamflowData = await this.fetchFromNOAA(
        reachId,
        includeForecast
      );
      if (!streamflowData) {
        return null;
      }

      // Add return period context for flow categorization
      try {
        const returnPeriodData = await this.fetchReturnPeriod(reachId);
        if (returnPeriodData) {
          streamflowData.returnPeriod = returnPeriodData;
          streamflowData.flowCategory = this.categorizeFlow(
            streamflowData.currentFlow,
            returnPeriodData
          );
        }
      } catch (error) {
        logger.warn(`Failed to fetch return period for ${reachId}:`, error);
        // Continue without return period data
      }

      // Add change detection
      if (cachedData) {
        streamflowData.previousFlow = cachedData.currentFlow;
        streamflowData.changePercent = this.calculateChangePercent(
          streamflowData.currentFlow,
          cachedData.currentFlow
        );
      }

      // Cache the data
      await this.cacheStreamflowData(streamflowData);

      return streamflowData;
    } catch (error) {
      logger.error(`Error fetching streamflow data for ${reachId}:`, error);
      return null;
    }
  }

  /**
   * Batch processing for multiple reaches (for notifications)
   * @param {string[]} reachIds - Array of reach identifiers
   * @return {Promise<StreamflowData[]>} Array of streamflow data
   */
  async fetchMultipleReaches(reachIds: string[]): Promise<StreamflowData[]> {
    logger.info(`Fetching data for ${reachIds.length} reaches`);

    const results: StreamflowData[] = [];
    const batches = this.chunkArray(reachIds, this.config.batchSize);

    for (let i = 0; i < batches.length; i++) {
      const batch = batches[i];
      logger.info(
        `Processing batch ${i + 1}/${batches.length}: ${batch.length} reaches`
      );

      // Process batch in parallel
      const batchPromises = batch.map(async (reachId) => {
        try {
          return await this.fetchStreamflowData(reachId, false);
        } catch (error) {
          logger.warn(`Failed to fetch data for reach ${reachId}:`, error);
          return null;
        }
      });

      const batchResults = await Promise.allSettled(batchPromises);

      // Extract successful results
      batchResults.forEach((result, index) => {
        if (result.status === "fulfilled" && result.value) {
          results.push(result.value);
        } else {
          logger.warn(`Batch item ${batch[index]} failed or returned null`);
        }
      });

      // Rate limiting between batches
      if (i < batches.length - 1) {
        await this.delay(1000); // 1 second between batches
      }
    }

    logger.info(
      "Successfully fetched data for ${results.length}/${reachIds.length} " +
      "reaches"
    );
    return results;
  }

  /**
   * Fetch from NOAA API (ported from existing ForecastRemoteDataSource)
   * @param {string} reachId - The reach identifier
   * @param {boolean} includeForecast - Whether to include forecast data
   * @return {Promise<StreamflowData | null>} Streamflow data or null
   */
  private async fetchFromNOAA(
    reachId: string,
    includeForecast: boolean
  ): Promise<StreamflowData | null> {
    const url = "${this.config.forecastBaseUrl}/reaches/${reachId}/" +
      "streamflow";

    try {
      const response: AxiosResponse<NOAAStreamflowResponse> = await axios.get(
        url,
        {
          timeout: this.config.timeout,
          params: includeForecast ? {series: "short_range"} : undefined,
          headers: {
            "Content-Type": "application/json",
            "User-Agent": "Rivr-Thesis-Research/1.0",
          },
        }
      );

      if (response.status === 200) {
        return this.transformNOAAResponse(
          response.data,
          reachId,
          includeForecast
        );
      }

      logger.warn(
        `NOAA API returned status ${response.status} for reach ${reachId}`
      );
      return null;
    } catch (error) {
      if (isAxiosError(error)) {
        if (error.response?.status === 404) {
          logger.info(`Reach ${reachId} not found in NOAA database`);
        } else {
          logger.error(`NOAA API error for reach ${reachId}:`, error.message);
        }
      } else {
        logger.error(`Network error for reach ${reachId}:`, error);
      }
      return null;
    }
  }

  /**
   * Transform NOAA response (based on existing ForecastModel.fromApiJson)
   * @param {NOAAStreamflowResponse} response - NOAA API response
   * @param {string} reachId - The reach identifier
   * @param {boolean} includeForecast - Whether to include forecast data
   * @return {StreamflowData} Transformed streamflow data
   */
  private transformNOAAResponse(
    response: NOAAStreamflowResponse,
    reachId: string,
    includeForecast: boolean
  ): StreamflowData {
    // Extract current flow from short range data
    const currentFlowData = this.extractLatestFlow(response.shortRange);

    const streamflowData: StreamflowData = {
      reachId,
      currentFlow: currentFlowData.flow,
      unit: "CFS", // NOAA API returns CFS
      validTime: currentFlowData.validTime,
      retrievedAt: new Date(),
      source: "NOAA_NWM",
    };

    // Add forecast data if requested
    if (includeForecast) {
      streamflowData.forecast = this.extractAllForecasts(response);
    }

    return streamflowData;
  }

  /**
   * Extract latest flow value (current conditions)
   * @param {Object} shortRange - Short range data from NOAA response
   * @return {Object} Latest flow and time data
   */
  private extractLatestFlow(
    shortRange?: NOAAStreamflowResponse["shortRange"]
  ): {flow: number; validTime: string} {
    // Try series data first (mean forecast)
    if (shortRange?.series?.data && shortRange.series.data.length > 0) {
      const latest = shortRange.series.data[0]; // First entry is latest
      return {flow: latest.flow, validTime: latest.validTime};
    }

    // Fall back to member data
    for (let i = 1; i <= 6; i++) {
      const memberKey = `member${i}` as
        keyof NOAAStreamflowResponse["shortRange"];
      const memberData = (shortRange?.[memberKey] as {
        data: Array<{validTime: string; flow: number}>
      } | undefined)?.data;
      if (memberData && memberData.length > 0) {
        const latest = memberData[0];
        return {flow: latest.flow, validTime: latest.validTime};
      }
    }

    throw new Error("No flow data found in NOAA response");
  }

  /**
   * Extract forecast array (based on existing implementation)
   * @param {NOAAStreamflowResponse} response - NOAA API response
   * @return {StreamflowForecast[]} Array of forecast data
   */
  private extractAllForecasts(
    response: NOAAStreamflowResponse
  ): StreamflowForecast[] {
    const forecasts: StreamflowForecast[] = [];

    // Short range forecasts
    if (response.shortRange?.series?.data) {
      response.shortRange.series.data.forEach((item) => {
        forecasts.push({
          validTime: item.validTime,
          flow: item.flow,
          forecastType: "short_range",
        });
      });
    }

    // Medium range forecasts
    if (response.mediumRange?.series?.data) {
      response.mediumRange.series.data.forEach((item) => {
        forecasts.push({
          validTime: item.validTime,
          flow: item.flow,
          forecastType: "medium_range",
        });
      });
    }

    // Long range forecasts (ensemble members)
    if (response.longRange) {
      for (let i = 1; i <= 4; i++) {
        const memberKey = `member${i}` as
          keyof NOAAStreamflowResponse["longRange"];
        const memberData = (response.longRange[memberKey] as {
          data: Array<{validTime: string; flow: number}>
        } | undefined)?.data;
        if (memberData) {
          memberData.forEach((item) => {
            forecasts.push({
              validTime: item.validTime,
              flow: item.flow,
              forecastType: "long_range",
              member: memberKey,
            });
          });
        }
      }
    }

    return forecasts;
  }

  /**
   * Flow categorization (based on existing ReturnPeriod.getFlowCategory)
   * @param {number} flow - Current flow value
   * @param {ReturnPeriodData} returnPeriod - Return period data
   * @return {FlowCategory} Flow category
   */
  private categorizeFlow(
    flow: number,
    returnPeriod: ReturnPeriodData
  ): FlowCategory {
    // Convert flow to same unit as return period (CMS)
    const flowInCMS = flow * 0.028317; // CFS to CMS conversion

    const rp = returnPeriod.flowValues;

    if (flowInCMS < (rp[2] ?? Infinity)) {
      return "Low";
    } else if (flowInCMS < (rp[5] ?? Infinity)) {
      return "Normal";
    } else if (flowInCMS < (rp[10] ?? Infinity)) {
      return "Moderate";
    } else if (flowInCMS < (rp[25] ?? Infinity)) {
      return "Elevated";
    } else if (flowInCMS < (rp[50] ?? Infinity)) {
      return "High";
    } else if (flowInCMS < (rp[100] ?? Infinity)) {
      return "Very High";
    } else {
      return "Extreme";
    }
  }

  /**
   * Calculate percentage change
   * @param {number} current - Current flow value
   * @param {number} previous - Previous flow value
   * @return {number} Percentage change
   */
  private calculateChangePercent(current: number, previous: number): number {
    if (previous === 0) return 0;
    return Math.round(((current - previous) / previous) * 10000) / 100;
  }

  /**
   * Get cached data for a reach
   * @param {string} reachId - The reach identifier
   * @return {Promise<StreamflowData | null>} Cached data or null
   */
  private async getCachedData(reachId: string): Promise<StreamflowData | null> {
    try {
      const doc = await this.db.collection("noaaFlowCache").doc(reachId).get();
      if (doc.exists) {
        const data = doc.data() as CachedStreamflowData;
        return {
          ...data,
          retrievedAt: data.retrievedAt?.toDate(),
          returnPeriod: data.returnPeriod ? {
            ...data.returnPeriod,
            retrievedAt: data.returnPeriod.retrievedAt?.toDate(),
          } : undefined,
        };
      }
    } catch (error) {
      logger.warn(`Error reading cache for ${reachId}:`, error);
    }
    return null;
  }

  /**
   * Check if cached data is still valid
   * @param {StreamflowData} cachedData - Cached streamflow data
   * @return {boolean} True if cache is valid
   */
  private isCacheValid(cachedData: StreamflowData): boolean {
    const cacheAge = Date.now() - cachedData.retrievedAt.getTime();
    const maxAge = 30 * 60 * 1000; // 30 minutes
    return cacheAge < maxAge;
  }

  /**
   * Cache streamflow data in Firestore
   * @param {StreamflowData} data - Streamflow data to cache
   * @return {Promise<void>} Promise that resolves when cached
   */
  private async cacheStreamflowData(data: StreamflowData): Promise<void> {
    try {
      const cacheDoc = {
        ...data,
        retrievedAt: admin.firestore.Timestamp.fromDate(data.retrievedAt),
        expiresAt: admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + 30 * 60 * 1000)
        ),
        returnPeriod: data.returnPeriod ? {
          ...data.returnPeriod,
          retrievedAt: admin.firestore.Timestamp.fromDate(
            data.returnPeriod.retrievedAt
          ),
        } : undefined,
      };

      await this.db.collection("noaaFlowCache").doc(data.reachId).set(cacheDoc);
    } catch (error) {
      logger.error(`Error caching data for ${data.reachId}:`, error);
    }
  }

  /**
   * Split array into chunks
   * @param {Array} array - Array to chunk
   * @param {number} chunkSize - Size of each chunk
   * @return {Array} Array of chunks
   */
  private chunkArray<T>(array: T[], chunkSize: number): T[][] {
    const chunks: T[][] = [];
    for (let i = 0; i < array.length; i += chunkSize) {
      chunks.push(array.slice(i, i + chunkSize));
    }
    return chunks;
  }

  /**
   * Delay execution for specified milliseconds
   * @param {number} ms - Milliseconds to delay
   * @return {Promise<void>} Promise that resolves after delay
   */
  private delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  /**
   * Get current streamflow data for a single reach (simple method)
   * @param {string} reachId - The reach identifier
   * @return {Promise<StreamflowData | null>} Current streamflow data
   */
  async getCurrentStreamflow(reachId: string): Promise<StreamflowData | null> {
    return await this.fetchStreamflowData(reachId, false);
  }

  /**
   * Fetch return period data (made public for notification system)
   * @param {string} reachId - The reach identifier
   * @return {Promise<ReturnPeriodData | null>} Return period data or null
   */
  async fetchReturnPeriod(reachId: string): Promise<ReturnPeriodData | null> {
    const url = `${this.config.returnPeriodBaseUrl}/return-period`;

    try {
      const response: AxiosResponse<ReturnPeriodResponse> = await axios.get(
        url,
        {
          timeout: this.config.timeout,
          params: {
            comids: reachId,
            key: this.config.apiKey,
          },
          headers: {
            "Content-Type": "application/json",
          },
        }
      );

      if (response.status === 200) {
        return {
          reachId,
          flowValues: {
            2: response.data.return_period_2,
            5: response.data.return_period_5,
            10: response.data.return_period_10,
            25: response.data.return_period_25,
            50: response.data.return_period_50,
            100: response.data.return_period_100,
          },
          unit: "CMS", // Return period API returns CMS
          retrievedAt: new Date(),
        };
      }

      return null;
    } catch (error) {
      logger.warn(`Failed to fetch return period for reach ${reachId}:`, error);
      return null;
    }
  }

  /**
   * Get user's monitored reaches (for scheduled notifications)
   * @return {Promise<string[]>} Array of reach IDs
   */
  async getUserMonitoredReaches(): Promise<string[]> {
    try {
      // Get all active user thresholds
      const thresholds = await this.db.collectionGroup("thresholds")
        .where("enabled", "==", true)
        .get();

      const reachIds = new Set<string>();
      thresholds.docs.forEach((doc) => {
        const data = doc.data();
        if (data.stationId) {
          reachIds.add(data.stationId);
        }
      });

      return Array.from(reachIds);
    } catch (error) {
      logger.error("Error getting monitored reaches:", error);
      return [];
    }
  }
}

