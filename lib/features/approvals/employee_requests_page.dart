import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/enums.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/request.dart';
import '../../widgets/request_card.dart';

typedef EmployeeRequestsParams = ({String employeeId, RequestStatus? status});

final employeeRequestsProvider = FutureProvider.family<List<ExpenseRequest>, EmployeeRequestsParams>((ref, params) {
  return ref.watch(requestServiceProvider).getTeamRequests(employeeId: params.employeeId, statusFilter: params.status);
});

/// Whether [employeeId]'s own direct manager is a first-line manager — i.e.
/// whether this employee's requests always pass through a second, tier-2
/// approval stage and therefore need the extra "First Approved" tab.
final _requiresSecondApprovalProvider = FutureProvider.family<bool, String>((ref, employeeId) async {
  final tier = await ref.watch(employeeServiceProvider).getManagerTierOf(employeeId);
  return tier == ManagerType.firstLine;
});

const _allTabStatuses = <RequestStatus?>[
  null,
  RequestStatus.pending,
  RequestStatus.pendingSecondApproval,
  RequestStatus.approved,
  RequestStatus.declined,
];

/// Invalidates every status-tab variant of [employeeRequestsProvider] for one
/// employee — call this after an approve/decline action so whichever tab the
/// manager returns to shows the fresh status.
void invalidateEmployeeRequests(WidgetRef ref, String employeeId) {
  for (final status in _allTabStatuses) {
    ref.invalidate(employeeRequestsProvider((employeeId: employeeId, status: status)));
  }
}

class EmployeeRequestsPage extends ConsumerWidget {
  final String employeeId;
  final String employeeName;
  const EmployeeRequestsPage({super.key, required this.employeeId, required this.employeeName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requiresSecondApprovalAsync = ref.watch(_requiresSecondApprovalProvider(employeeId));
    return requiresSecondApprovalAsync.when(
      data: (requiresSecondApproval) => _TabbedRequestsView(
        employeeId: employeeId,
        employeeName: employeeName,
        requiresSecondApproval: requiresSecondApproval,
      ),
      loading: () => Scaffold(
        appBar: AppBar(title: Text(employeeName)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(employeeName)),
        body: Center(child: Text('Failed to load: $e')),
      ),
    );
  }
}

class _TabbedRequestsView extends ConsumerStatefulWidget {
  final String employeeId;
  final String employeeName;
  final bool requiresSecondApproval;
  const _TabbedRequestsView({
    required this.employeeId,
    required this.employeeName,
    required this.requiresSecondApproval,
  });

  @override
  ConsumerState<_TabbedRequestsView> createState() => _TabbedRequestsViewState();
}

class _TabbedRequestsViewState extends ConsumerState<_TabbedRequestsView> with SingleTickerProviderStateMixin {
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
        children: _statuses.map((status) {
          if (status == RequestStatus.pending) {
            return _PendingRequestsList(employeeId: widget.employeeId);
          }
          return _EmployeeRequestsList(employeeId: widget.employeeId, status: status);
        }).toList(),
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
                managerView: true,
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

/// Pending tab, with bulk selection: a "select all" for this month's pending
/// requests and a single "Approve Selected" action, so a manager doesn't have
/// to open each request individually. Extra costs on bulk-approved requests
/// are accepted as-is (checked by default) — there's no per-line review here,
/// unlike opening a single request.
class _PendingRequestsList extends ConsumerStatefulWidget {
  final String employeeId;
  const _PendingRequestsList({required this.employeeId});

  @override
  ConsumerState<_PendingRequestsList> createState() => _PendingRequestsListState();
}

class _PendingRequestsListState extends ConsumerState<_PendingRequestsList> {
  final Set<int> _selectedIds = {};
  bool _isApproving = false;

  bool _isCurrentMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  Future<void> _approveSelected(List<ExpenseRequest> requests) async {
    final selected = requests.where((r) => _selectedIds.contains(r.id)).toList();
    if (selected.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Approve Selected Requests'),
        content: Text('Approve ${selected.length} request(s) for this month? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Approve')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isApproving = true);
    try {
      final me = await ref.read(myProfileProvider.future);
      await ref.read(requestServiceProvider).approveMultiple(
            requests: selected,
            approvingManagerType: me.managerType,
          );
      if (!mounted) return;
      setState(() => _selectedIds.clear());
      invalidateEmployeeRequests(ref, widget.employeeId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not approve all: $e')));
      }
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final params = (employeeId: widget.employeeId, status: RequestStatus.pending);
    final requestsAsync = ref.watch(employeeRequestsProvider(params));

    final body = requestsAsync.when(
      data: (requests) {
        if (requests.isEmpty) {
          return const Center(child: Text('No requests here yet'));
        }

        final currentMonthRequests = requests.where((r) => _isCurrentMonth(r.firstDateTravel)).toList();
        final currentMonthIds = currentMonthRequests.map((r) => r.id).whereType<int>().toSet();
        final allSelected = currentMonthIds.isNotEmpty && currentMonthIds.every(_selectedIds.contains);

        return Column(
          children: [
            if (currentMonthRequests.isNotEmpty)
              CheckboxListTile(
                value: allSelected,
                onChanged: _isApproving
                    ? null
                    : (v) => setState(() {
                          if (v == true) {
                            _selectedIds.addAll(currentMonthIds);
                          } else {
                            _selectedIds.removeAll(currentMonthIds);
                          }
                        }),
                title: const Text('Select all this month', style: TextStyle(fontWeight: FontWeight.w600)),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(employeeRequestsProvider(params)),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80, top: 8),
                  itemCount: requests.length,
                  itemBuilder: (context, i) {
                    final r = requests[i];
                    final selectable = _isCurrentMonth(r.firstDateTravel);
                    return Row(
                      children: [
                        SizedBox(
                          width: 48,
                          child: selectable
                              ? Checkbox(
                                  value: _selectedIds.contains(r.id),
                                  onChanged: _isApproving
                                      ? null
                                      : (v) => setState(() {
                                            if (v == true) {
                                              _selectedIds.add(r.id!);
                                            } else {
                                              _selectedIds.remove(r.id);
                                            }
                                          }),
                                )
                              : null,
                        ),
                        Expanded(
                          child: RequestCard(
                            request: r,
                            managerView: true,
                            onTap: () => context.push('/team/${widget.employeeId}/requests/${r.id}'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load: $e')),
    );

    return Stack(
      children: [
        body,
        if (_selectedIds.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: ElevatedButton(
              onPressed: _isApproving
                  ? null
                  : () async {
                      final requests = await ref.read(employeeRequestsProvider(params).future);
                      await _approveSelected(requests);
                    },
              style: ElevatedButton.styleFrom(backgroundColor: PharcoColors.success),
              child: _isApproving
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Approve Selected (${_selectedIds.length})'),
            ),
          ),
      ],
    );
  }
}
