import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';

class LatLng {
  final double lat;
  final double lng;
  const LatLng(this.lat, this.lng);
}

/// Resolves and caches the driving distance (km) between two points, mirroring
/// the original `Distance` cache table + Google Directions lookup.
class DistanceService {
  final SupabaseClient _client;
  DistanceService([SupabaseClient? client]) : _client = client ?? supabase;

  /// Straight-line fallback so the app still works without a Maps API key.
  static double haversineKm(LatLng a, LatLng b) {
    const earthRadiusKm = 6371.0;
    final dLat = _deg2rad(b.lat - a.lat);
    final dLng = _deg2rad(b.lng - a.lng);
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(a.lat)) * cos(_deg2rad(b.lat)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(h), sqrt(1 - h));
    return earthRadiusKm * c;
  }

  static double _deg2rad(double deg) => deg * (pi / 180);

  Future<double> _fetchFromGoogle(LatLng origin, LatLng destination, String apiKey) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': '${origin.lat},${origin.lng}',
      'destination': '${destination.lat},${destination.lng}',
      'alternatives': 'true',
      'units': 'metric',
      'key': apiKey,
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      return haversineKm(origin, destination);
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final routes = data['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      return haversineKm(origin, destination);
    }
    double? minKm;
    for (final route in routes) {
      final legs = (route as Map<String, dynamic>)['legs'] as List<dynamic>?;
      if (legs == null || legs.isEmpty) continue;
      final distanceMeters = (legs.first as Map<String, dynamic>)['distance']?['value'] as int?;
      if (distanceMeters == null) continue;
      final km = distanceMeters / 1000.0;
      if (minKm == null || km < minKm) minKm = km;
    }
    return minKm ?? haversineKm(origin, destination);
  }

  /// Resolves the distance for a leg identified either by a (fromCityId,
  /// toCityId) city pair, or by (employeeId, cityId) when one endpoint is the
  /// employee's home address (cityId null on that side). Results are cached
  /// in `distances` exactly like the original `Distance` table.
  Future<double> resolveLeg({
    required int? fromCityId,
    required int? toCityId,
    required String employeeId,
    required LatLng fromCoord,
    required LatLng toCoord,
    String? googleApiKey,
  }) async {
    if (fromCityId == null && toCityId == null) return 0;

    var query = _client.from('distances').select();
    if (fromCityId != null) {
      query = query.eq('from_city_id', fromCityId);
    } else {
      query = query.isFilter('from_city_id', null).eq('employee_id', employeeId);
    }
    if (toCityId != null) {
      query = query.eq('to_city_id', toCityId);
    } else {
      query = query.isFilter('to_city_id', null).eq('employee_id', employeeId);
    }

    final cached = await query.maybeSingle();
    if (cached != null) {
      return (cached['kms'] as num).toDouble();
    }

    final km = (googleApiKey != null && googleApiKey.isNotEmpty)
        ? await _fetchFromGoogle(fromCoord, toCoord, googleApiKey)
        : haversineKm(fromCoord, toCoord);

    await _client.from('distances').insert({
      'from_city_id': fromCityId,
      'to_city_id': toCityId,
      'employee_id': (fromCityId == null || toCityId == null) ? employeeId : null,
      'kms': km,
    });

    return km;
  }
}
