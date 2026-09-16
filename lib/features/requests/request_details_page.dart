import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers.dart';
import '../../widgets/receipt_thumbnail.dart';
import '../../widgets/status_badge.dart';

final _requestDetailProvider = FutureProvider.family((ref, int id) {
  return ref.watch(requestServiceProvider).getRequestById(id);
});

class RequestDetailsPage extends ConsumerWidget {
  final int requestId;
  const RequestDetailsPage({super.key, required this.requestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestAsync = ref.watch(_requestDetailProvider(requestId));
    final dateFmt = DateFormat('dd MMMM yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Request Details')),
      body: requestAsync.when(
        data: (r) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(r.requestType.label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                StatusBadge(status: r.status),
              ],
            ),
            if (r.status.label == 'Declined' && r.notes != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBEAEA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Rejection reason: ${r.notes}'),
              ),
            ],
            const SizedBox(height: 20),
            _SectionCard(
              title: 'Travel',
              rows: [
                _row('Outbound date', dateFmt.format(r.firstDateTravel)),
                _row('From', r.firstFromCityName ?? 'Home address'),
                _row('To', r.firstToCityName ?? 'Home address'),
                _row('Return date', dateFmt.format(r.secondDateTravel)),
                _row('From', r.secondFromCityName ?? 'Home address'),
                _row('To', r.secondToCityName ?? 'Home address'),
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Cost Breakdown',
              rows: [
                _row('Travel distance', '${r.travelDistance.toStringAsFixed(1)} km'),
                _row('Return distance', '${r.returnDistance.toStringAsFixed(1)} km'),
                _row('Billable distance', '${r.finalDistance.toStringAsFixed(1)} km'),
                _row('Meals', '${r.mealsCount}'),
                _row('Extra costs', 'EGP ${r.extraCost.toStringAsFixed(2)}'),
                _row('Total amount', 'EGP ${r.requestAmount.toStringAsFixed(2)}', bold: true),
              ],
            ),
            if (r.extraCosts.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Extra Cost Items',
                rows: r.extraCosts
                    .map<Widget>((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              ReceiptThumbnail(path: e.invoiceImagePath),
                              if (e.invoiceImagePath != null) const SizedBox(width: 12),
                              Expanded(child: Text(e.type.label, style: const TextStyle(color: Colors.black54))),
                              Text(
                                'EGP ${e.amount.toStringAsFixed(2)}${e.isChecked ? '' : ' (rejected)'}',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
      ),
    );
  }

  static Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(
            value,
            style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> rows;
  const _SectionCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const Divider(height: 20),
            ...rows,
          ],
        ),
      ),
    );
  }
}
