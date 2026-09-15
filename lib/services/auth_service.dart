import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';

/// Employees sign in with their employee *code*, not a real email address —
/// same as the original app. Supabase Auth still needs an email-shaped
/// identifier under the hood, so each code is mapped to a fixed synthetic
/// address on this fake domain. This mapping must stay in sync with however
/// employee accounts get provisioned (see supabase/functions/provision-employee).
const _authEmailDomain = 'pharco.local';

String employeeCodeToAuthEmail(String code) => '${code.trim().toLowerCase()}@$_authEmailDomain';

class AuthService {
  final SupabaseClient _client;
  AuthService([SupabaseClient? client]) : _client = client ?? supabase;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> signInWithCode({required String employeeCode, required String password}) {
    return _client.auth.signInWithPassword(
      email: employeeCodeToAuthEmail(employeeCode),
      password: password,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Mirrors the original "reset password" button: it doesn't email a reset
  /// link (these accounts don't have real inboxes) — it unconditionally sets
  /// the account's password to a fixed default ("Ph@123"), like the original
  /// admin-reset action. Implemented as a Supabase Edge Function
  /// (`reset-password`) since changing another user's password requires the
  /// service-role key, which must never live in the client app.
  /// See supabase/functions/reset-password/index.ts.
  Future<void> resetPasswordToDefault(String employeeCode) async {
    final res = await _client.functions.invoke(
      'reset-password',
      body: {'code': employeeCode.trim()},
    );
    if (res.status != 200) {
      final message = (res.data is Map) ? res.data['error'] : null;
      throw Exception(message ?? 'Could not reset password (status ${res.status})');
    }
  }

  /// Self-service password change from the Profile screen. Doesn't ask for
  /// the current password — someone using this screen has often just reset
  /// to a default they don't consider "theirs" and may not remember it — so
  /// it relies on the existing signed-in session alone. Unlike
  /// [resetPasswordToDefault], this only ever touches the caller's own
  /// account, so it can call Supabase Auth directly — no Edge Function needed.
  Future<void> changePassword(String newPassword) {
    return _client.auth.updateUser(UserAttributes(password: newPassword));
  }
}
