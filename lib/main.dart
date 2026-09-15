import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'core/supabase_client.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  runApp(const ProviderScope(child: PharcoApp()));
}

class PharcoApp extends ConsumerWidget {
  const PharcoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Pharco Expenses',
      debugShowCheckedModeBanner: false,
      theme: PharcoTheme.light(),
      routerConfig: router,
    );
  }
}
