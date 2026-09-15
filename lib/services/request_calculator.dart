import '../core/enums.dart';
import '../models/lookups.dart';

/// Result of the "confirm your expense" preview shown before the employee
/// submits a request — mirrors ConfirmRequestDto from the original backend.
class RequestPreview {
  final double travelDistance;
  final double returnDistance;
  final double finalDistance;
  final double costOfDistance;
  final int mealsCount;
  final double mealCost;
  final double costOfMeals;
  final double extraCost;
  final double requestAmount;

  RequestPreview({
    required this.travelDistance,
    required this.returnDistance,
    required this.finalDistance,
    required this.costOfDistance,
    required this.mealsCount,
    required this.mealCost,
    required this.costOfMeals,
    required this.extraCost,
    required this.requestAmount,
  });
}

class RequestValidationError implements Exception {
  final String message;
  RequestValidationError(this.message);
  @override
  String toString() => message;
}

/// Pure business-rule calculations ported from RequestAppService.Create /
/// SendRequestToConfirm / ConfirmRequestForEmployee.
class RequestCalculator {
  /// Meals: Title.MealCost >= 300 => one meal per travel day (exclusive of
  /// the return day); otherwise one meal per day *inclusive* of both ends.
  /// Standalone requests never get meals.
  static int mealsCount({
    required RequestType requestType,
    required double mealCost,
    required DateTime firstDateTravel,
    required DateTime secondDateTravel,
  }) {
    if (requestType == RequestType.standalone) return 0;
    final days = secondDateTravel.difference(firstDateTravel).inDays;
    return mealCost >= 300 ? days : days + 1;
  }

  /// Given the two raw leg distances, applies the minimum-KM gating rule:
  /// a leg below the policy minimum is recorded but not paid; if *neither*
  /// leg reaches the minimum the whole request is rejected.
  static double finalDistance({
    required double travelDistance,
    required double returnDistance,
    required double minimumKm,
  }) {
    final travelOk = travelDistance >= minimumKm;
    final returnOk = returnDistance >= minimumKm;
    if (travelOk && returnOk) return travelDistance + returnDistance;
    if (travelOk) return travelDistance;
    if (returnOk) return returnDistance;
    throw RequestValidationError(
      'Your total distance (travel and return) is lower than $minimumKm KMs',
    );
  }

  static RequestPreview preview({
    required double travelDistance,
    required double returnDistance,
    required ReimbursementPolicy policy,
    required int mealsCount,
    required double mealCost,
    required double extraCost,
  }) {
    if (travelDistance == 0 && returnDistance == 0) {
      return RequestPreview(
        travelDistance: 0,
        returnDistance: 0,
        finalDistance: 0,
        costOfDistance: 0,
        mealsCount: 0,
        mealCost: 0,
        costOfMeals: 0,
        extraCost: extraCost,
        requestAmount: extraCost,
      );
    }
    final final_ = finalDistance(
      travelDistance: travelDistance,
      returnDistance: returnDistance,
      minimumKm: policy.minimumKm,
    );
    final costOfDistance = final_ * policy.pricePerKm;
    final costOfMeals = mealsCount * mealCost;
    return RequestPreview(
      travelDistance: travelDistance,
      returnDistance: returnDistance,
      finalDistance: final_,
      costOfDistance: costOfDistance,
      mealsCount: mealsCount,
      mealCost: mealCost,
      costOfMeals: costOfMeals,
      extraCost: extraCost,
      requestAmount: costOfDistance + costOfMeals + extraCost,
    );
  }

  /// Validates that [candidateStart]..[candidateEnd] doesn't overlap any of
  /// the employee's existing non-declined requests.
  static bool datesOverlap({
    required DateTime candidateStart,
    required DateTime candidateEnd,
    required DateTime existingStart,
    required DateTime existingEnd,
  }) {
    return candidateStart.isBefore(existingEnd.add(const Duration(days: 1))) &&
        candidateEnd.isAfter(existingStart.subtract(const Duration(days: 1)));
  }
}
