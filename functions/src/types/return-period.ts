// functions/src/types/return-period.ts
import {FlowUnit} from "./flow-unit";

/**
 * Return period data structure matching the Rivr app
 * Based on lib/features/forecast/domain/entities/return_period.dart
 */
export interface ReturnPeriod {
  reachId: string;
  flowValues: { [year: number]: number }; // 2, 5, 10, 25, 50, 100 year flows
  unit: FlowUnit;
  retrievedAt: Date;
}

/**
 * Standard return period years used by the system
 */
export const STANDARD_RETURN_PERIOD_YEARS = [2, 5, 10, 25, 50, 100];
