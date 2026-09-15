import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/request.dart';
import 'status_badge.dart';

class RequestCard extends StatelessWidget {
  final ExpenseRequest request;
  final VoidCallback? onTap;
  final bool showEmployeeName;

  const RequestCard({
    super.key,
    required this.request,
    this.onTap,
    this.showEmployeeName = false,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      request.requestType.label,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  StatusBadge(status: request.status),
                ],
              ),
              if (showEmployeeName && request.employeeName != null) ...[
                const SizedBox(height: 4),
                Text(request.employeeName!, style: const TextStyle(color: Colors.black54, fontSize: 13)),
              ],
              const SizedBox(height: 8),
              Text(
                '${dateFmt.format(request.firstDateTravel)}  →  ${dateFmt.format(request.secondDateTravel)}',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${request.finalDistance.toStringAsFixed(1)} km',
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  Text(
                    'EGP ${request.requestAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: PharcoColors.orangeDark,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
