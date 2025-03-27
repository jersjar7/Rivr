// lib/features/forecast/domain/usecases/get_return_periods.dart

import 'package:dartz/dartz.dart';
import 'package:rivr/core/error/failures.dart';
import 'package:rivr/features/forecast/domain/entities/return_period.dart';
import 'package:rivr/features/forecast/domain/repositories/return_period_repository.dart';

class GetReturnPeriods {
  final ReturnPeriodRepository repository;

  GetReturnPeriods(this.repository);

  Future<Either<Failure, ReturnPeriod>> call(
    String reachId, {
    bool forceRefresh = false,
  }) {
    return repository.getReturnPeriods(reachId, forceRefresh: forceRefresh);
  }
}

class GetFlowCategory {
  final ReturnPeriodRepository repository;

  GetFlowCategory(this.repository);

  Future<Either<Failure, String>> call(String reachId, double flow) {
    return repository.getFlowCategory(reachId, flow);
  }
}

class CheckFlowExceedsThreshold {
  final ReturnPeriodRepository repository;

  CheckFlowExceedsThreshold(this.repository);

  Future<Either<Failure, bool>> call(
    String reachId,
    double flow,
    int returnPeriodYear,
  ) {
    return repository.exceedsReturnPeriod(reachId, flow, returnPeriodYear);
  }
}
