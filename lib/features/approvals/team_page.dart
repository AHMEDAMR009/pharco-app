import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

final _teamProvider = FutureProvider((ref) async {
  final me = await ref.watch(myProfileProvider.future);
  return ref.watch(employeeServiceProvider).getDirectReports(me.id);
});

class TeamPage extends ConsumerWidget {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(_teamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Team')),
      body: teamAsync.when(
        data: (team) {
          if (team.isEmpty) {
            return const Center(child: Text('No direct reports found'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: team.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final e = team[i];
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
    );
  }
}
