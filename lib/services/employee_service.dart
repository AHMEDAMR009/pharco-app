import 'package:supabase_flutter/supabase_flutter.dart';
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
  /// indirectly via a first-line manager who reports to them.
  Future<List<Employee>> getDirectReports(String managerId) async {
    final rows = await _client
        .from('employees')
        .select(_selectWithTitle)
        .eq('manager_id', managerId)
        .order('full_name');
    return (rows as List<dynamic>).map((e) => Employee.fromJson(e as Map<String, dynamic>)).toList();
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
