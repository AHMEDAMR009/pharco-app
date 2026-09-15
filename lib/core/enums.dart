/// Domain enums mirrored from the original Pharco backend business rules.

enum RequestType {
  fieldVisit(1, 'Field Visit'),
  training(2, 'Training'),
  groupMeeting(3, 'Group Meeting'),
  standalone(4, 'Standalone'),
  officeMeeting(5, 'Office Meeting');

  final int code;
  final String label;
  const RequestType(this.code, this.label);

  static RequestType fromCode(int code) =>
      RequestType.values.firstWhere((e) => e.code == code, orElse: () => RequestType.fieldVisit);
}

/// 5 (PendingSecondApproval) is shown as "Pending" to the employee but is a
/// distinct pipeline stage for the manager-approval chain.
enum RequestStatus {
  pending(1, 'Pending'),
  approved(2, 'Approved'),
  declined(3, 'Declined'),
  pendingSecondApproval(5, 'Pending');

  final int code;
  final String label;
  const RequestStatus(this.code, this.label);

  static RequestStatus fromCode(int code) =>
      RequestStatus.values.firstWhere((e) => e.code == code, orElse: () => RequestStatus.pending);
}

enum ExtraCostType {
  carParking(1, 'Car Parking'),
  tollGate(2, 'Toll Gate'),
  tickets(3, 'Tickets'),
  allowance(4, 'Allowance'),
  uberReceipts(5, 'Uber Receipts');

  final int code;
  final String label;
  const ExtraCostType(this.code, this.label);

  static ExtraCostType fromCode(int code) =>
      ExtraCostType.values.firstWhere((e) => e.code == code, orElse: () => ExtraCostType.tollGate);

  /// Business rule: which extra-cost types are offered depends on the
  /// request type and the employee's title seniority.
  static List<ExtraCostType> allowedFor({
    required RequestType requestType,
    required int titleId,
  }) {
    if (requestType == RequestType.standalone) {
      return [ExtraCostType.tollGate];
    }
    final isJuniorTitle = titleId == 1 || titleId == 2;
    if (isJuniorTitle || requestType == RequestType.fieldVisit) {
      return [carParking, tollGate, tickets, allowance];
    }
    return ExtraCostType.values;
  }
}

/// Manager hierarchy role, stored on the employee row.
enum ManagerType {
  none(0),
  firstLine(1),
  secondLevel(2),
  direct(3);

  final int code;
  const ManagerType(this.code);

  static ManagerType fromCode(int? code) =>
      ManagerType.values.firstWhere((e) => e.code == code, orElse: () => ManagerType.none);

  bool get isManager => this != ManagerType.none;
}
