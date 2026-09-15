import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/enums.dart';
import '../../core/providers.dart';
import '../../models/request.dart';
import '../../widgets/request_card.dart';

typedef EmployeeRequestsParams = ({String employeeId, RequestStatus? status});

final employeeRequestsProvider = FutureProvider.family<List<ExpenseRequest>, EmployeeRequestsParams>((ref, params) {
  return ref.watch(requestServiceProvider).getTeamRequests(employeeId: params.employeeId, statusFilter: params.status);
});

/// Invalidates every status-tab variant of [employeeRequestsProvider] for one
/// employee — call this after an approve/decline action so whichever tab the
/// manager returns to shows the fresh status.
void invalidateEmployeeRequests(WidgetRef ref, String employeeId) {
  for (final status in <RequestStatus?>[null, RequestStatus.pending, RequestStatus.approved, RequestStatus.declined]) {
    ref.invalidate(employeeRequestsProvider((employeeId: employeeId, status: status)));
  }
}

class EmployeeRequestsPage extends ConsumerStatefulWidget {
  final String employeeId;
  final String employeeName;
  const EmployeeRequestsPage({super.key, required this.employeeId, required this.employeeName});

  @override
  ConsumerState<EmployeeRequestsPage> createState() => _EmployeeRequestsPageState();
}

class _EmployeeRequestsPageState extends ConsumerState<EmployeeRequestsPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  static const _statuses = <RequestStatus?>[null, RequestStatus.pending, RequestStatus.approved, RequestStatus.declined];
  static const _labels = ['All', 'Pending', 'Approved', 'Declined'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statuses.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employeeName),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _labels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _statuses
            .map((status) => _EmployeeRequestsList(employeeId: widget.employeeId, status: status))
            .toList(),
      ),
    );
  }
}

class _EmployeeRequestsList extends ConsumerWidget {
  final String employeeId;
  final RequestStatus? status;
  const _EmployeeRequestsList({required this.employeeId, required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (employeeId: employeeId, status: status);
    final requestsAsync = ref.watch(employeeRequestsProvider(params));
    return requestsAsync.when(
      data: (requests) {
        if (requests.isEmpty) {
          return const Center(child: Text('No requests here yet'));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(employeeRequestsProvider(params)),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: requests.length,
            itemBuilder: (context, i) {
              final r = requests[i];
              return RequestCard(
                request: r,
                onTap: () => context.push('/team/$employeeId/requests/${r.id}'),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load: $e')),
    );
  }
}
