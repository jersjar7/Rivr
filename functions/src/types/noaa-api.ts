// functions/src/types/noaa-api.ts

/**
 * NOAA API response structure
 * Based on the National Water Model API
 */
export interface NoaaApiResponse {
  reach_id: string;
  data: NoaaDataPoint[];
  metadata?: {
    units: string;
    source: string;
    model: string;
    last_updated: string;
  };
}

export interface NoaaDataPoint {
  validTime: string; // ISO 8601 timestamp
  flow: number;
  forecast_type?: "analysis" | "short_range" | "medium_range" | "long_range";
  member?: string; // For ensemble forecasts
}

/**
 * NOAA Return Period API response
 */
export interface NoaaReturnPeriodResponse {
  reach_id: string;
  return_period_2: number;
  return_period_5: number;
  return_period_10: number;
  return_period_25: number;
  return_period_50: number;
  return_period_100: number;
  units: string;
  calculated_at: string;
}
