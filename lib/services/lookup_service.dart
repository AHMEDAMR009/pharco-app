import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import '../models/lookups.dart';

class LookupService {
  final SupabaseClient _client;
  LookupService([SupabaseClient? client]) : _client = client ?? supabase;

  Future<List<Governorate>> getGovernorates() async {
    final rows = await _client.from('governorates').select().order('name_en');
    return (rows as List<dynamic>).map((e) => Governorate.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<City>> getCities({int? governorateId}) async {
    var q = _client.from('cities').select();
    if (governorateId != null) {
      q = q.eq('governorate_id', governorateId);
    }
    final rows = await q.order('name_en');
    return (rows as List<dynamic>).map((e) => City.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ReimbursementPolicy> getPolicy() async {
    final row = await _client.from('reimbursement_policy').select().limit(1).maybeSingle();
    return row == null ? ReimbursementPolicy.fallback() : ReimbursementPolicy.fromJson(row);
  }

  /// Monthly request quota for an employee = MIN(brick.monthly_limitation)
  /// across all bricks tied to their territory; defaults to 14 if none.
  Future<int> getMonthlyQuota(int? territoryId) async {
    if (territoryId == null) return 14;
    final rows = await _client
        .from('territory_bricks')
        .select('bricks ( monthly_limitation )')
        .eq('territory_id', territoryId);
    final limits = (rows as List<dynamic>)
        .map((e) => (e['bricks'] as Map<String, dynamic>)['monthly_limitation'] as int)
        .toList();
    if (limits.isEmpty) return 14;
    return limits.reduce((a, b) => a < b ? a : b);
  }
}
