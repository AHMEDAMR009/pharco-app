import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/enums.dart';
import '../core/supabase_client.dart';
import '../models/employee.dart';

class EmployeeService {
  final SupabaseClient _client;
  EmployeeService([SupabaseClient? client]) : _client = client ?? supabase;

  static const _selectWithTitle = '*, titles ( id, name, meal_cost )';

  Future<Employee> getMyProfile() async {
    final userId = _client.auth.currentUser!.id;
    final row = await _client
        .from('employees')
        .select(_selectWithTitle)
        .eq('id', userId)
        .single();
    return Employee.fromJson(row);
  }

  Future<Employee?> getById(String employeeId) async {
    final row = await _client
        .from('employees')
        .select(_selectWithTitle)
        .eq('id', employeeId)
        .maybeSingle();
    return row == null ? null : Employee.fromJson(row);
  }

  /// Employees who report to [managerId], directly or (for tier-2 managers)
  /// indirectly via a first-line manager who reports to them — matching the
  /// same two-level visibility `is_manager_of()` grants on `requests`.
  Future<List<Employee>> getDirectReports(String managerId) async {
    final directRows = await _client
        .from('employees')
        .select(_selectWithTitle)
        .eq('manager_id', managerId)
        .order('full_name');
    final direct = (directRows as List<dynamic>).map((e) => Employee.fromJson(e as Map<String, dynamic>)).toList();

    final firstLineIds = direct.where((e) => e.managerType == ManagerType.firstLine).map((e) => e.id).toList();
    if (firstLineIds.isEmpty) return direct;

    final indirectRows = await _client
        .from('employees')
        .select(_selectWithTitle)
        .inFilter('manager_id', firstLineIds)
        .order('full_name');
    final indirect = (indirectRows as List<dynamic>).map((e) => Employee.fromJson(e as Map<String, dynamic>)).toList();

    return [...direct, ...indirect];
  }

  /// The manager tier of [employeeId]'s own direct manager — null if they
  /// have no manager on file. A `firstLine` result means this employee's
  /// requests always pass through a second, tier-2 approval stage.
  ///
  /// Two plain lookups rather than a self-join embed: `employees.manager_id`
  /// references `employees.id`, and PostgREST can't disambiguate the join
  /// direction for a self-referencing FK from the column name alone.
  Future<ManagerType?> getManagerTierOf(String employeeId) async {
    final row = await _client.from('employees').select('manager_id').eq('id', employeeId).maybeSingle();
    final managerId = row?['manager_id'] as String?;
    if (managerId == null) return null;

    final managerRow = await _client.from('employees').select('manager_type').eq('id', managerId).maybeSingle();
    final code = managerRow?['manager_type'] as int?;
    return code == null ? null : ManagerType.fromCode(code);
  }

  Future<List<Employee>> searchTeam(String managerId, {String? query}) async {
    var q = _client.from('employees').select(_selectWithTitle).eq('manager_id', managerId);
    if (query != null && query.isNotEmpty) {
      q = q.ilike('full_name', '%$query%');
    }
    final rows = await q.order('full_name');
    return (rows as List<dynamic>).map((e) => Employee.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> updateAvatarPath(String employeeId, String avatarPath) async {
    await _client.from('employees').update({'avatar_path': avatarPath}).eq('id', employeeId);
  }
}
