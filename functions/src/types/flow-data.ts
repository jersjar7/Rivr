// functions/src/types/flow-data.ts
import {FlowUnit} from "./flow-unit";

/**
 * Core flow data structure matching the Rivr app entities
 * Based on lib/features/forecast/domain/entities/forecast.dart
 */
export interface FlowData {
  reachId: string;
  flow: number;
  unit: FlowUnit;
  timestamp: Date;
  source: "NOAA" | "NOAA_TEST" | "MANUAL";
  validTime?: string; // ISO string for forecast validity
  member?: string; // For ensemble forecasts (member1, member2, etc.)
}
