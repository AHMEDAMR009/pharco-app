import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/enums.dart';
import '../core/supabase_client.dart';
import '../models/employee.dart';
import '../models/lookups.dart';
import '../models/request.dart';
import 'distance_service.dart';
import 'employee_service.dart';
import 'lookup_service.dart';
import 'request_calculator.dart';

/// Everything needed to preview/submit a new travel request, gathered by the
/// create-request screen before calling [RequestService.previewRequest].
class NewRequestInput {
  final RequestType requestType;
  final int? firstFromCityId;
  final int? firstToCityId;
  final DateTime firstDateTravel;
  final int? secondFromCityId;
  final int? secondToCityId;
  final DateTime secondDateTravel;
  final List<RequestExtraCost> extraCosts;

  NewRequestInput({
    required this.requestType,
    this.firstFromCityId,
    this.firstToCityId,
    required this.firstDateTravel,
    this.secondFromCityId,
    this.secondToCityId,
    required this.secondDateTravel,
    this.extraCosts = const [],
  });
}

class RequestService {
  final SupabaseClient _client;
  final DistanceService _distanceService;
  final LookupService _lookupService;
  final EmployeeService _employeeService;

  RequestService({
    SupabaseClient? client,
    DistanceService? distanceService,
    LookupService? lookupService,
    EmployeeService? employeeService,
  })  : _client = client ?? supabase,
        _distanceService = distanceService ?? DistanceService(client),
        _lookupService = lookupService ?? LookupService(client),
        _employeeService = employeeService ?? EmployeeService(client);

  static const _listSelect = '''
    *,
    first_from_city:cities!requests_first_from_city_id_fkey ( name_en ),
    first_to_city:cities!requests_first_to_city_id_fkey ( name_en ),
    second_from_city:cities!requests_second_from_city_id_fkey ( name_en ),
    second_to_city:cities!requests_second_to_city_id_fkey ( name_en ),
    employees ( full_name, titles ( meal_cost ) ),
    request_extra_costs ( * )
  ''';

  // ---------------------------------------------------------------------
  // Validation ahead of preview/submit
  // ---------------------------------------------------------------------

  Future<void> _assertNoDateOverlap({
    required String employeeId,
    required DateTime firstDateTravel,
    required DateTime secondDateTravel,
  }) async {
    final existing = await _client
        .from('requests')
        .select('first_date_travel, second_date_travel')
        .eq('employee_id', employeeId)
        .eq('is_deleted', false)
        .neq('request_status', RequestStatus.declined.code);

    for (final row in existing as List<dynamic>) {
      final existingStart = DateTime.parse(row['first_date_travel'] as String);
      final existingEnd = DateTime.parse(row['second_date_travel'] as String);
      if (RequestCalculator.datesOverlap(
        candidateStart: firstDateTravel,
        candidateEnd: secondDateTravel,
        existingStart: existingStart,
        existingEnd: existingEnd,
      )) {
        throw RequestValidationError(
          'We cannot complete your request, you have a request with the same travel date',
        );
      }
    }
  }

  Future<void> _assertMonthlyQuotaNotExceeded(Employee employee) async {
    final quota = await _lookupService.getMonthlyQuota(employee.territoryId);
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final firstOfNextMonth = DateTime(now.year, now.month + 1, 1);

    final rows = await _client
        .from('requests')
        .select('id')
        .eq('employee_id', employee.id)
        .eq('is_deleted', false)
        .neq('request_status', RequestStatus.declined.code)
        .gte('created_at', firstOfMonth.toIso8601String())
        .lt('created_at', firstOfNextMonth.toIso8601String());

    if ((rows as List<dynamic>).length >= quota) {
      throw RequestValidationError(
        'We cannot complete your request, you have exceeded the number of allowed requests in this month',
      );
    }
  }

  // ---------------------------------------------------------------------
  // Distance resolution
  // ---------------------------------------------------------------------

  Future<double> _resolveLegDistance({
    required Employee employee,
    required int? fromCityId,
    required int? toCityId,
    required Map<int, City> citiesById,
  }) async {
    if (fromCityId == null && toCityId == null) return 0;
    final fromCoord = fromCityId != null
        ? LatLng(citiesById[fromCityId]!.latitude, citiesById[fromCityId]!.longitude)
        : LatLng(employee.homeLatitude!, employee.homeLongitude!);
    final toCoord = toCityId != null
        ? LatLng(citiesById[toCityId]!.latitude, citiesById[toCityId]!.longitude)
        : LatLng(employee.homeLatitude!, employee.homeLongitude!);
    return _distanceService.resolveLeg(
      fromCityId: fromCityId,
      toCityId: toCityId,
      employeeId: employee.id,
      fromCoord: fromCoord,
      toCoord: toCoord,
    );
  }

  // ---------------------------------------------------------------------
  // Preview + submit (Create + SendRequestToConfirm + ConfirmRequestForEmployee,
  // combined into one round trip as recommended by the reverse-engineering
  // report — no separate "Draft" status is persisted).
  // ---------------------------------------------------------------------

  Future<RequestPreview> previewRequest(NewRequestInput input, Map<int, City> citiesById) async {
    if (input.secondDateTravel.isBefore(input.firstDateTravel)) {
      throw RequestValidationError(
        'Your return date must be on or after the start date',
      );
    }

    final employee = await _employeeService.getMyProfile();

    await _assertNoDateOverlap(
      employeeId: employee.id,
      firstDateTravel: input.firstDateTravel,
      secondDateTravel: input.secondDateTravel,
    );
    await _assertMonthlyQuotaNotExceeded(employee);

    final noLegsSelected = input.firstFromCityId == null &&
        input.firstToCityId == null &&
        input.secondFromCityId == null &&
        input.secondToCityId == null;

    if (noLegsSelected) {
      if (input.extraCosts.isEmpty) {
        throw RequestValidationError('You must enter an extra cost for a request with no travel city');
      }
      final extraCostTotal = input.extraCosts.fold<double>(0, (sum, e) => sum + e.amount);
      return RequestPreview(
        travelDistance: 0,
        returnDistance: 0,
        finalDistance: 0,
        costOfDistance: 0,
        mealsCount: 0,
        mealCost: 0,
        costOfMeals: 0,
        extraCost: extraCostTotal,
        requestAmount: extraCostTotal,
      );
    }

    final travelDistance = await _resolveLegDistance(
      employee: employee,
      fromCityId: input.firstFromCityId,
      toCityId: input.firstToCityId,
      citiesById: citiesById,
    );
    final returnDistance = await _resolveLegDistance(
      employee: employee,
      fromCityId: input.secondFromCityId,
      toCityId: input.secondToCityId,
      citiesById: citiesById,
    );

    final policy = await _lookupService.getPolicy();
    final mealsCount = RequestCalculator.mealsCount(
      requestType: input.requestType,
      mealCost: employee.mealCost ?? 0,
      firstDateTravel: input.firstDateTravel,
      secondDateTravel: input.secondDateTravel,
    );
    final extraCostTotal = input.extraCosts.fold<double>(0, (sum, e) => sum + e.amount);

    return RequestCalculator.preview(
      travelDistance: travelDistance,
      returnDistance: returnDistance,
      policy: policy,
      mealsCount: mealsCount,
      mealCost: employee.mealCost ?? 0,
      extraCost: extraCostTotal,
    );
  }

  /// Persists the request as status=Pending (submission happens in one step;
  /// call [previewRequest] first to show the cost breakdown for confirmation).
  Future<ExpenseRequest> submitRequest(NewRequestInput input, RequestPreview preview) async {
    final employee = await _employeeService.getMyProfile();

    final inserted = await _client
        .from('requests')
        .insert({
          'employee_id': employee.id,
          'request_type': input.requestType.code,
          'request_status': RequestStatus.pending.code,
          'first_from_city_id': input.firstFromCityId,
          'first_to_city_id': input.firstToCityId,
          'first_date_travel': input.firstDateTravel.toIso8601String().split('T').first,
          'second_from_city_id': input.secondFromCityId,
          'second_to_city_id': input.secondToCityId,
          'second_date_travel': input.secondDateTravel.toIso8601String().split('T').first,
          'travel_distance': preview.travelDistance,
          'return_distance': preview.returnDistance,
          'final_distance': preview.finalDistance,
          'meals_count': preview.mealsCount,
          'extra_cost': preview.extraCost,
          'request_amount': preview.requestAmount,
        })
        .select()
        .single();

    final requestId = inserted['id'] as int;

    if (input.extraCosts.isNotEmpty) {
      await _client
          .from('request_extra_costs')
          .insert(input.extraCosts.map((e) => e.toInsertJson(requestId)).toList());
    }

    return getRequestById(requestId);
  }

  // ---------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------

  Future<ExpenseRequest> getRequestById(int id) async {
    final row = await _client.from('requests').select(_listSelect).eq('id', id).single();
    return ExpenseRequest.fromJson(row);
  }

  /// Employee's own request list, optionally filtered by status. "Pending"
  /// and "First Approved" (pendingSecondApproval) are distinct tabs, same as
  /// a manager's team view — see [getTeamRequests].
  Future<List<ExpenseRequest>> getMyRequests({RequestStatus? statusFilter}) async {
    final employeeId = _client.auth.currentUser!.id;
    var q = _client
        .from('requests')
        .select(_listSelect)
        .eq('employee_id', employeeId)
        .eq('is_deleted', false);

    if (statusFilter != null) {
      q = q.eq('request_status', statusFilter.code);
    }

    final rows = await q.order('created_at', ascending: false);
    return (rows as List<dynamic>).map((e) => ExpenseRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<RequestStatus, int>> getRequestCountsByStatus() async {
    final employeeId = _client.auth.currentUser!.id;
    final rows = await _client
        .from('requests')
        .select('request_status')
        .eq('employee_id', employeeId)
        .eq('is_deleted', false);

    final counts = <RequestStatus, int>{
      RequestStatus.pending: 0,
      RequestStatus.approved: 0,
      RequestStatus.declined: 0,
    };
    for (final row in rows as List<dynamic>) {
      final status = RequestStatus.fromCode(row['request_status'] as int);
      final bucket = status == RequestStatus.pendingSecondApproval ? RequestStatus.pending : status;
      counts[bucket] = (counts[bucket] ?? 0) + 1;
    }
    return counts;
  }

  /// Total approved amount for the current calendar month, recomputed fresh
  /// each month (based on when the request was approved, not when it was
  /// submitted or travelled).
  Future<double> getApprovedAmountForCurrentMonth() async {
    final employeeId = _client.auth.currentUser!.id;
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final firstOfNextMonth = DateTime(now.year, now.month + 1, 1);

    final rows = await _client
        .from('requests')
        .select('request_amount')
        .eq('employee_id', employeeId)
        .eq('is_deleted', false)
        .eq('request_status', RequestStatus.approved.code)
        .gte('approval_or_decline_time', firstOfMonth.toIso8601String())
        .lt('approval_or_decline_time', firstOfNextMonth.toIso8601String());

    return (rows as List<dynamic>)
        .fold<double>(0, (sum, row) => sum + (row['request_amount'] as num).toDouble());
  }

  /// A manager's pending-approval queue: their direct reports' requests
  /// (plus, for tier-2 managers, requests already forwarded by a first-line
  /// manager reporting to them) — RLS on `requests` already scopes this.
  Future<List<ExpenseRequest>> getTeamRequests({
    required String employeeId,
    RequestStatus? statusFilter,
  }) async {
    var q = _client
        .from('requests')
        .select(_listSelect)
        .eq('employee_id', employeeId)
        .eq('is_deleted', false);
    // Unlike getMyRequests, "Pending" and "First Approved" (pendingSecondApproval)
    // are shown to managers as distinct tabs, so each filters to its own status.
    if (statusFilter != null) {
      q = q.eq('request_status', statusFilter.code);
    }
    final rows = await q.order('created_at', ascending: false);
    return (rows as List<dynamic>).map((e) => ExpenseRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// This month's request counts by status for each of [employeeIds] — used
  /// to sort "My Team" so employees needing action float to the top.
  Future<Map<String, Map<RequestStatus, int>>> getMonthlyStatusCounts(List<String> employeeIds) async {
    if (employeeIds.isEmpty) return {};
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String().split('T').first;
    final monthEnd = DateTime(now.year, now.month + 1, 1).toIso8601String().split('T').first;

    final rows = await _client
        .from('requests')
        .select('employee_id, request_status')
        .inFilter('employee_id', employeeIds)
        .eq('is_deleted', false)
        .gte('first_date_travel', monthStart)
        .lt('first_date_travel', monthEnd);

    final counts = <String, Map<RequestStatus, int>>{};
    for (final row in rows as List<dynamic>) {
      final id = row['employee_id'] as String;
      final status = RequestStatus.fromCode(row['request_status'] as int);
      final byStatus = counts.putIfAbsent(id, () => {});
      byStatus[status] = (byStatus[status] ?? 0) + 1;
    }
    return counts;
  }

  // ---------------------------------------------------------------------
  // Manager actions
  // ---------------------------------------------------------------------

  /// Approves a request. First-line managers (ManagerType.firstLine) forward
  /// it to the second-level manager (status -> pendingSecondApproval) instead
  /// of finalizing it. Any extra-cost line the manager unchecks is deducted
  /// from the final request amount.
  Future<void> approveRequest({
    required ExpenseRequest request,
    required ManagerType approvingManagerType,
    required List<RequestExtraCost> extraCostDecisions,
  }) async {
    final now = DateTime.now();
    final isFirstLine = approvingManagerType == ManagerType.firstLine;

    for (final decision in extraCostDecisions) {
      if (decision.id != null) {
        await _client
            .from('request_extra_costs')
            .update({'is_checked': decision.isChecked}).eq('id', decision.id!);
      }
    }

    if (isFirstLine) {
      await _client.from('requests').update({
        'request_status': RequestStatus.pendingSecondApproval.code,
        'approval_or_decline_time': now.toIso8601String(),
      }).eq('id', request.id!);
      return;
    }

    final rejectedTotal = extraCostDecisions
        .where((e) => !e.isChecked)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final finalAmount = request.requestAmount - rejectedTotal;

    await _client.from('requests').update({
      'request_status': RequestStatus.approved.code,
      'request_amount': finalAmount,
      'approval_or_decline_time': now.toIso8601String(),
    }).eq('id', request.id!);
  }

  /// Approves several requests at once (e.g. "select all this month's
  /// pending requests and approve"), keeping each one's extra costs exactly
  /// as they already are (all accepted by default) — bulk approval doesn't
  /// offer a per-line accept/reject step like the single-request review does.
  Future<void> approveMultiple({
    required List<ExpenseRequest> requests,
    required ManagerType approvingManagerType,
  }) async {
    for (final request in requests) {
      await approveRequest(
        request: request,
        approvingManagerType: approvingManagerType,
        extraCostDecisions: request.extraCosts,
      );
    }
  }

  Future<void> declineRequest({required int requestId, required String notes}) async {
    await _client.from('requests').update({
      'request_status': RequestStatus.declined.code,
      'notes': notes,
      'approval_or_decline_time': DateTime.now().toIso8601String(),
    }).eq('id', requestId);
  }

  /// Business-cutoff rule: a manager can no longer approve/decline a request
  /// from a previous month once the 3rd of the current month has passed.
  static bool isPastApprovalCutoff(DateTime requestCreatedAt) {
    final now = DateTime.now();
    final sameMonth = requestCreatedAt.year == now.year && requestCreatedAt.month == now.month;
    if (sameMonth) return false;
    return now.day > 3;
  }
}
