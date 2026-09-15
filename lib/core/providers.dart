import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/employee.dart';
import '../services/auth_service.dart';
import '../services/employee_service.dart';
import '../services/lookup_service.dart';
import '../services/request_service.dart';
import '../services/storage_service.dart';
import 'supabase_client.dart';

final authServiceProvider = Provider((ref) => AuthService());
final employeeServiceProvider = Provider((ref) => EmployeeService());
final lookupServiceProvider = Provider((ref) => LookupService());
final requestServiceProvider = Provider((ref) => RequestService());
final storageServiceProvider = Provider((ref) => StorageService());

/// Emits whenever the Supabase auth session changes (sign in/out).
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).onAuthStateChange;
});

/// The signed-in employee's profile (drives role-based navigation).
final myProfileProvider = FutureProvider<Employee>((ref) async {
  ref.watch(authStateProvider);
  return ref.watch(employeeServiceProvider).getMyProfile();
});

final requestCountsProvider = FutureProvider((ref) {
  ref.watch(authStateProvider);
  return ref.watch(requestServiceProvider).getRequestCountsByStatus();
});

bool get isSignedIn => supabase.auth.currentSession != null;
