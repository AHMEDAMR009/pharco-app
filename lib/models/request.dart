import '../core/enums.dart';

class RequestExtraCost {
  final int? id;
  final ExtraCostType type;
  final double amount;
  final String? invoiceImagePath; // storage object path
  final bool isChecked;

  RequestExtraCost({
    this.id,
    required this.type,
    required this.amount,
    this.invoiceImagePath,
    this.isChecked = true,
  });

  factory RequestExtraCost.fromJson(Map<String, dynamic> j) => RequestExtraCost(
        id: j['id'] as int?,
        type: ExtraCostType.fromCode(j['extra_cost_type'] as int),
        amount: (j['extra_cost'] as num).toDouble(),
        invoiceImagePath: j['invoice_image'] as String?,
        isChecked: j['is_checked'] as bool? ?? true,
      );

  Map<String, dynamic> toInsertJson(int requestId) => {
        'request_id': requestId,
        'extra_cost_type': type.code,
        'extra_cost': amount,
        'invoice_image': invoiceImagePath,
        'is_checked': isChecked,
      };
}

class ExpenseRequest {
  final int? id;
  final String employeeId;
  final RequestType requestType;
  final RequestStatus status;

  final int? firstFromCityId;
  final int? firstToCityId;
  final DateTime firstDateTravel;

  final int? secondFromCityId;
  final int? secondToCityId;
  final DateTime secondDateTravel;

  final double travelDistance;
  final double returnDistance;
  final double finalDistance;

  final int mealsCount;
  final double extraCost;
  final double requestAmount;

  final String? notes;
  final DateTime? approvalOrDeclineTime;
  final DateTime? createdAt;

  final List<RequestExtraCost> extraCosts;

  // Optional joined display fields (populated when reading list/detail views).
  final String? firstFromCityName;
  final String? firstToCityName;
  final String? secondFromCityName;
  final String? secondToCityName;
  final String? employeeName;

  ExpenseRequest({
    this.id,
    required this.employeeId,
    required this.requestType,
    this.status = RequestStatus.pending,
    this.firstFromCityId,
    this.firstToCityId,
    required this.firstDateTravel,
    this.secondFromCityId,
    this.secondToCityId,
    required this.secondDateTravel,
    this.travelDistance = 0,
    this.returnDistance = 0,
    this.finalDistance = 0,
    this.mealsCount = 0,
    this.extraCost = 0,
    this.requestAmount = 0,
    this.notes,
    this.approvalOrDeclineTime,
    this.createdAt,
    this.extraCosts = const [],
    this.firstFromCityName,
    this.firstToCityName,
    this.secondFromCityName,
    this.secondToCityName,
    this.employeeName,
  });

  factory ExpenseRequest.fromJson(Map<String, dynamic> j) => ExpenseRequest(
        id: j['id'] as int?,
        employeeId: j['employee_id'] as String,
        requestType: RequestType.fromCode(j['request_type'] as int),
        status: RequestStatus.fromCode(j['request_status'] as int),
        firstFromCityId: j['first_from_city_id'] as int?,
        firstToCityId: j['first_to_city_id'] as int?,
        firstDateTravel: DateTime.parse(j['first_date_travel'] as String),
        secondFromCityId: j['second_from_city_id'] as int?,
        secondToCityId: j['second_to_city_id'] as int?,
        secondDateTravel: DateTime.parse(j['second_date_travel'] as String),
        travelDistance: (j['travel_distance'] as num).toDouble(),
        returnDistance: (j['return_distance'] as num).toDouble(),
        finalDistance: (j['final_distance'] as num).toDouble(),
        mealsCount: j['meals_count'] as int,
        extraCost: (j['extra_cost'] as num).toDouble(),
        requestAmount: (j['request_amount'] as num).toDouble(),
        notes: j['notes'] as String?,
        approvalOrDeclineTime: j['approval_or_decline_time'] != null
            ? DateTime.parse(j['approval_or_decline_time'] as String)
            : null,
        createdAt: j['created_at'] != null ? DateTime.parse(j['created_at'] as String) : null,
        extraCosts: (j['request_extra_costs'] as List<dynamic>?)
                ?.map((e) => RequestExtraCost.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        firstFromCityName: (j['first_from_city'] as Map<String, dynamic>?)?['name_en'] as String?,
        firstToCityName: (j['first_to_city'] as Map<String, dynamic>?)?['name_en'] as String?,
        secondFromCityName: (j['second_from_city'] as Map<String, dynamic>?)?['name_en'] as String?,
        secondToCityName: (j['second_to_city'] as Map<String, dynamic>?)?['name_en'] as String?,
        employeeName: (j['employees'] as Map<String, dynamic>?)?['full_name'] as String?,
      );

  /// Employee-facing status label: statuses 1 and 5 both read as "Pending".
  String get displayStatusLabel => status.label;
}
