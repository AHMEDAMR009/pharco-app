import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/enums.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/request.dart';
import '../../services/request_service.dart';
import '../../widgets/receipt_thumbnail.dart';
import '../../widgets/status_badge.dart';
import 'employee_requests_page.dart';

final _requestProvider = FutureProvider.family((ref, int id) {
  return ref.watch(requestServiceProvider).getRequestById(id);
});

class ApproveRequestPage extends ConsumerStatefulWidget {
  final int requestId;
  final String employeeId;
  const ApproveRequestPage({super.key, required this.requestId, required this.employeeId});

  @override
  ConsumerState<ApproveRequestPage> createState() => _ApproveRequestPageState();
}

class _ApproveRequestPageState extends ConsumerState<ApproveRequestPage> {
  final Map<int, bool> _checkedOverrides = {};
  bool _isSubmitting = false;

  Future<void> _approve(ExpenseRequest request) async {
    setState(() => _isSubmitting = true);
    try {
      final me = await ref.read(myProfileProvider.future);
      final decisions = request.extraCosts
          .map((e) => RequestExtraCost(
                id: e.id,
                type: e.type,
                amount: e.amount,
                invoiceImagePath: e.invoiceImagePath,
                isChecked: _checkedOverrides[e.id] ?? e.isChecked,
              ))
          .toList();
      await ref.read(requestServiceProvider).approveRequest(
            request: request,
            approvingManagerType: me.managerType,
            extraCostDecisions: decisions,
          );
      if (!mounted) return;
      ref.invalidate(_requestProvider(widget.requestId));
      invalidateEmployeeRequests(ref, widget.employeeId);
      context.pop();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _decline(int requestId) async {
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Decline Request'),
        content: TextField(
          controller: notesController,
          decoration: const InputDecoration(labelText: 'Reason'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Decline')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(requestServiceProvider).declineRequest(requestId: requestId, notes: notesController.text);
      if (!mounted) return;
      ref.invalidate(_requestProvider(requestId));
      invalidateEmployeeRequests(ref, widget.employeeId);
      context.pop();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestAsync = ref.watch(_requestProvider(widget.requestId));
    final dateFmt = DateFormat('dd MMMM yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Review Request')),
      body: requestAsync.when(
        data: (r) {
          final me = ref.watch(myProfileProvider).valueOrNull;
          final requiresSecondApproval = ref.watch(requiresSecondApprovalProvider(widget.employeeId)).valueOrNull ?? false;
          // A first-line manager who already forwarded this request has
          // nothing left to do; only the tier-2 manager it's now waiting on
          // can still act on it.
          final forwardedByMe = r.status == RequestStatus.pendingSecondApproval && me?.managerType == ManagerType.firstLine;
          // A still-plain-Pending request from a two-tier employee hasn't
          // been through their first-line manager yet — nobody else can
          // approve/decline it out of order.
          final awaitingFirstApproval =
              r.status == RequestStatus.pending && requiresSecondApproval && me?.managerType != ManagerType.firstLine;
          final isDecided = r.status == RequestStatus.approved ||
              r.status == RequestStatus.declined ||
              forwardedByMe ||
              awaitingFirstApproval;
          final pastCutoff = r.createdAt != null && RequestService.isPastApprovalCutoff(r.createdAt!);
          final isLocked = isDecided || pastCutoff;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (r.employeeName != null)
                      Text(r.employeeName!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(r.requestType.label),
                        const SizedBox(width: 8),
                        StatusBadge(status: r.status),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('${dateFmt.format(r.firstDateTravel)} → ${dateFmt.format(r.secondDateTravel)}'),
                    const SizedBox(height: 4),
                    Text('${r.firstFromCityName ?? "Home"} → ${r.firstToCityName ?? "Home"}'),
                    Text('${r.secondFromCityName ?? "Home"} → ${r.secondToCityName ?? "Home"}'),
                    const SizedBox(height: 20),
                    Text('Total: EGP ${r.requestAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: PharcoColors.orangeDark)),
                    if (r.extraCosts.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(isDecided ? 'Extra Costs' : 'Extra Costs (uncheck to reject a receipt)',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      // A plain Row with its own Checkbox (rather than
                      // CheckboxListTile, whose tap target spans the whole
                      // row) so tapping the receipt thumbnail can't also
                      // toggle the checkbox underneath it.
                      ...r.extraCosts.map((e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _checkedOverrides[e.id] ?? e.isChecked,
                                  onChanged:
                                      isDecided ? null : (v) => setState(() => _checkedOverrides[e.id!] = v ?? true),
                                ),
                                const SizedBox(width: 4),
                                ReceiptThumbnail(path: e.invoiceImagePath),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(e.type.label),
                                      Text('EGP ${e.amount.toStringAsFixed(2)}',
                                          style: const TextStyle(color: Colors.black54, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                    if (r.status == RequestStatus.declined && r.notes != null && r.notes!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFFBEAEA), borderRadius: BorderRadius.circular(12)),
                        child: Text('Rejection reason: ${r.notes}'),
                      ),
                    ],
                    if (forwardedByMe) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(12)),
                        child: const Text(
                          "You've approved this request and forwarded it for second-level approval — no further action needed from you.",
                        ),
                      ),
                    ] else if (awaitingFirstApproval) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFEAF1FB), borderRadius: BorderRadius.circular(12)),
                        child: const Text(
                          "This request hasn't been approved by the employee's direct manager yet.",
                        ),
                      ),
                    ] else if (isDecided) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          'This request has already been ${r.status.label.toLowerCase()} and can no longer be changed.',
                        ),
                      ),
                    ] else if (pastCutoff) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFFBEAEA), borderRadius: BorderRadius.circular(12)),
                        child: const Text(
                          'This request is from a previous month and can no longer be approved or declined '
                          '(cutoff: the 3rd of the current month).',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isLocked)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSubmitting ? null : () => _decline(r.id!),
                          child: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : () => _approve(r),
                          child: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
      ),
    );
  }
}
