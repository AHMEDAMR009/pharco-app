import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/enums.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);
    final countsAsync = ref.watch(requestCountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myProfileProvider);
          ref.invalidate(requestCountsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            profileAsync.when(
              data: (employee) => Text(
                'Welcome, ${employee.fullName.split(' ').first}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              loading: () => const SizedBox(height: 28),
              error: (e, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),
            countsAsync.when(
              data: (counts) => Row(
                children: [
                  Expanded(
                    child: _CountTile(
                      label: 'Pending',
                      count: counts[RequestStatus.pending] ?? 0,
                      color: PharcoColors.pending,
                      onTap: () => context.push('/requests?status=pending'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CountTile(
                      label: 'Approved',
                      count: counts[RequestStatus.approved] ?? 0,
                      color: PharcoColors.success,
                      onTap: () => context.push('/requests?status=approved'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CountTile(
                      label: 'Declined',
                      count: counts[RequestStatus.declined] ?? 0,
                      color: PharcoColors.danger,
                      onTap: () => context.push('/requests?status=declined'),
                    ),
                  ),
                ],
              ),
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )),
              error: (e, _) => Text('Could not load counts: $e'),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => context.push('/requests/new'),
              icon: const Icon(Icons.add),
              label: const Text('New Expense Request'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/requests'),
              icon: const Icon(Icons.list_alt_outlined),
              label: const Text('My Requests'),
            ),
            profileAsync.maybeWhen(
              data: (employee) => employee.managerType.isManager
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/team'),
                        icon: const Icon(Icons.groups_outlined),
                        label: const Text('My Team'),
                      ),
                    )
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _CountTile({
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color),
              ),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}
