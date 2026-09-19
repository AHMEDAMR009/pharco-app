import 'package:flutter/material.dart';
import '../core/enums.dart';
import '../core/theme.dart';

class StatusBadge extends StatelessWidget {
  final RequestStatus status;
  const StatusBadge({super.key, required this.status});

  StatusStyle _styleFor(RequestStatus s) {
    switch (s) {
      case RequestStatus.approved:
        return const StatusStyle(PharcoColors.success, Color(0xFFE6F5EC));
      case RequestStatus.declined:
        return const StatusStyle(PharcoColors.danger, Color(0xFFFBEAEA));
      case RequestStatus.pending:
        return const StatusStyle(PharcoColors.pending, Color(0xFFEAF1FB));
      case RequestStatus.pendingSecondApproval:
        return const StatusStyle(PharcoColors.success, Color(0xFFE6F5EC));
    }
  }

  String _labelFor(RequestStatus s) {
    if (s == RequestStatus.pendingSecondApproval) return 'First Approved';
    return s.label;
  }

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _labelFor(status),
        style: TextStyle(color: style.color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
