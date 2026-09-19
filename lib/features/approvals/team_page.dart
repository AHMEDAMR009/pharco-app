import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/enums.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/employee.dart';

/// Direct (and, for tier-2 managers, flattened-in indirect) reports, sorted
/// so whoever needs attention most floats to the top: more of this month's
/// requests still Pending outranks more First Approved, which outranks more
/// Approved, which outranks more Declined. Employees with no requests this
/// month sort last, in name order.
final _teamProvider = FutureProvider((ref) async {
  final me = await ref.watch(myProfileProvider.future);
  final team = await ref.watch(employeeServiceProvider).getDirectReports(me.id);
  final counts = await ref.watch(requestServiceProvider).getMonthlyStatusCounts(team.map((e) => e.id).toList());

  int countFor(Employee e, RequestStatus s) => counts[e.id]?[s] ?? 0;
  final sorted = [...team]..sort((a, b) {
      for (final status in const [
        RequestStatus.pending,
        RequestStatus.pendingSecondApproval,
        RequestStatus.approved,
        RequestStatus.declined,
      ]) {
        final cmp = countFor(b, status).compareTo(countFor(a, status));
        if (cmp != 0) return cmp;
      }
      return a.fullName.compareTo(b.fullName);
    });
  return sorted;
});

class TeamPage extends ConsumerStatefulWidget {
  const TeamPage({super.key});

  @override
  ConsumerState<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends ConsumerState<TeamPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(_teamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Team')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or code',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() {
                          _searchController.clear();
                          _query = '';
                        }),
                      ),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: teamAsync.when(
              data: (team) {
                final filtered = _query.isEmpty
                    ? team
                    : team
                        .where((e) =>
                            e.fullName.toLowerCase().contains(_query) || e.code.toLowerCase().contains(_query))
                        .toList();
                if (filtered.isEmpty) {
                  return Center(child: Text(_query.isEmpty ? 'No direct reports found' : 'No matches for "$_query"'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final e = filtered[i];
                    final avatarUrl =
                        e.avatarPath != null ? ref.read(storageServiceProvider).avatarPublicUrl(e.avatarPath!) : null;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: PharcoColors.orange,
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null
                              ? Text(
                                  e.fullName.isNotEmpty ? e.fullName[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                )
                              : null,
                        ),
                        title: Text(e.fullName),
                        subtitle: Text('${e.code} • ${e.titleName ?? ''}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/team/${e.id}', extra: e.fullName),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load team: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
