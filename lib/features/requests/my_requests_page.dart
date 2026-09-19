import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/enums.dart';
import '../../core/providers.dart';
import '../../models/request.dart';
import '../../widgets/request_card.dart';

final _myRequestsProvider =
    FutureProvider.family<List<ExpenseRequest>, RequestStatus?>((ref, status) {
  ref.watch(authStateProvider);
  return ref.watch(requestServiceProvider).getMyRequests(statusFilter: status);
});

/// Whether my own direct manager is a first-line manager — i.e. whether my
/// own requests pass through a second, tier-2 approval stage and need the
/// extra "First Approved" tab (see the equivalent provider a manager's team
/// view uses, in employee_requests_page.dart).
final _myRequestsRequireSecondApprovalProvider = FutureProvider((ref) async {
  final me = await ref.watch(myProfileProvider.future);
  final tier = await ref.watch(employeeServiceProvider).getManagerTierOf(me.id);
  return tier == ManagerType.firstLine;
});

const _allTabStatuses = <RequestStatus?>[
  null,
  RequestStatus.pending,
  RequestStatus.pendingSecondApproval,
  RequestStatus.approved,
  RequestStatus.declined,
];

class MyRequestsPage extends ConsumerWidget {
  final RequestStatus? initialStatus;
  const MyRequestsPage({super.key, this.initialStatus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requiresSecondApprovalAsync = ref.watch(_myRequestsRequireSecondApprovalProvider);
    return requiresSecondApprovalAsync.when(
      data: (requiresSecondApproval) => _TabbedMyRequestsView(
        initialStatus: initialStatus,
        requiresSecondApproval: requiresSecondApproval,
      ),
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('My Requests')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('My Requests')),
        body: Center(child: Text('Failed to load: $e')),
      ),
    );
  }
}

class _TabbedMyRequestsView extends ConsumerStatefulWidget {
  final RequestStatus? initialStatus;
  final bool requiresSecondApproval;
  const _TabbedMyRequestsView({required this.initialStatus, required this.requiresSecondApproval});

  @override
  ConsumerState<_TabbedMyRequestsView> createState() => _TabbedMyRequestsViewState();
}

class _TabbedMyRequestsViewState extends ConsumerState<_TabbedMyRequestsView> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final List<RequestStatus?> _statuses;
  late final List<String> _labels;

  @override
  void initState() {
    super.initState();
    if (widget.requiresSecondApproval) {
      _statuses = _allTabStatuses;
      _labels = const ['All', 'Pending', 'First Approved', 'Approved', 'Declined'];
    } else {
      _statuses = const [null, RequestStatus.pending, RequestStatus.approved, RequestStatus.declined];
      _labels = const ['All', 'Pending', 'Approved', 'Declined'];
    }
    final initialIndex = _statuses.indexOf(widget.initialStatus);
    _tabController = TabController(
      length: _statuses.length,
      vsync: this,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
    );
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
        title: const Text('My Requests'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _labels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _statuses.map((status) => _RequestsList(status: status)).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/requests/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _RequestsList extends ConsumerWidget {
  final RequestStatus? status;
  const _RequestsList({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(_myRequestsProvider(status));
    return requestsAsync.when(
      data: (requests) {
        if (requests.isEmpty) {
          return const Center(child: Text('No requests here yet'));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_myRequestsProvider(status)),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: requests.length,
            itemBuilder: (context, i) {
              final r = requests[i];
              return RequestCard(
                request: r,
                onTap: () => context.push('/requests/${r.id}'),
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
