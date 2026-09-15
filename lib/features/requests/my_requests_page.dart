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

class MyRequestsPage extends ConsumerStatefulWidget {
  final RequestStatus? initialStatus;
  const MyRequestsPage({super.key, this.initialStatus});

  @override
  ConsumerState<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends ConsumerState<MyRequestsPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  static const _statuses = <RequestStatus?>[null, RequestStatus.pending, RequestStatus.approved, RequestStatus.declined];
  static const _labels = ['All', 'Pending', 'Approved', 'Declined'];

  @override
  void initState() {
    super.initState();
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
