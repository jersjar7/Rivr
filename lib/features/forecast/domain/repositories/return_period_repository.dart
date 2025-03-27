// lib/features/forecast/domain/repositories/return_period_repository.dart

import 'package:dartz/dartz.dart';
import 'package:rivr/core/error/failures.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';

abstract class ReturnPeriodRepository {
  /// Gets return period data for a specific reach
  Future<Either<Failure, ReturnPeriod>> getReturnPeriods(
    String reachId, {
    bool forceRefresh = false,
  });

  /// Gets flow category for a given flow value and reach ID
  Future<Either<Failure, String>> getFlowCategory(String reachId, double flow);

  /// Determines if a flow value exceeds a specific return period
  Future<Either<Failure, bool>> exceedsReturnPeriod(
    String reachId,
    double flow,
    int returnPeriodYear,
  );
}
