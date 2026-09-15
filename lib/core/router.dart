import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/enums.dart';
import '../features/approvals/employee_requests_page.dart';
import '../features/approvals/team_page.dart';
import '../features/auth/login_page.dart';
import '../features/home/home_page.dart';
import '../features/profile/profile_page.dart';
import '../features/requests/create_request_page.dart';
import '../features/requests/my_requests_page.dart';
import '../features/requests/request_details_page.dart';
import '../features/approvals/approve_request_page.dart';
import 'providers.dart';

/// Notifies go_router to re-run `redirect` whenever the Supabase auth session
/// changes. This deliberately does NOT rebuild the `routerProvider` itself
/// (unlike a plain `ref.watch(authStateProvider)`, which would construct a
/// brand new GoRouter — resetting the whole navigation stack back to
/// `initialLocation` on every auth event, including ones that don't actually
/// change who's signed in, like re-verifying a password during a change).
class _AuthChangeNotifier extends ChangeNotifier {
  late final StreamSubscription _subscription;
  _AuthChangeNotifier(Ref ref) {
    _subscription = ref.read(authServiceProvider).onAuthStateChange.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authChangeNotifier = _AuthChangeNotifier(ref);
  ref.onDispose(authChangeNotifier.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: authChangeNotifier,
    redirect: (context, state) {
      final loggedIn = isSignedIn;
      final loggingIn = state.matchedLocation == '/login';
      if (!loggedIn) return loggingIn ? null : '/login';
      if (loggingIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
      GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
      GoRoute(
        path: '/requests',
        builder: (context, state) {
          final statusParam = state.uri.queryParameters['status'];
          final status = switch (statusParam) {
            'pending' => RequestStatus.pending,
            'approved' => RequestStatus.approved,
            'declined' => RequestStatus.declined,
            _ => null,
          };
          return MyRequestsPage(initialStatus: status);
        },
      ),
      GoRoute(path: '/requests/new', builder: (context, state) => const CreateRequestPage()),
      GoRoute(
        path: '/requests/:id',
        builder: (context, state) => RequestDetailsPage(requestId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: '/team', builder: (context, state) => const TeamPage()),
      GoRoute(
        path: '/team/:employeeId',
        builder: (context, state) => EmployeeRequestsPage(
          employeeId: state.pathParameters['employeeId']!,
          employeeName: state.extra as String? ?? '',
        ),
      ),
      GoRoute(
        path: '/team/:employeeId/requests/:requestId',
        builder: (context, state) => ApproveRequestPage(
          requestId: int.parse(state.pathParameters['requestId']!),
          employeeId: state.pathParameters['employeeId']!,
        ),
      ),
    ],
  );
});
