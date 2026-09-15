import '../core/enums.dart';

class Employee {
  final String id; // auth user id
  final String code;
  final String fullName;
  final String? email; // real contact email, optional — not the login identifier
  final String? phone;
  final int? titleId;
  final String? titleName;
  final double? mealCost;
  final int? territoryId;
  final int? governorateId;
  final String? managerId;
  final ManagerType managerType;
  final double? homeLatitude;
  final double? homeLongitude;
  final bool isActive;
  final String? avatarPath; // storage object path in the "avatars" bucket

  Employee({
    required this.id,
    required this.code,
    required this.fullName,
    this.email,
    this.phone,
    this.titleId,
    this.titleName,
    this.mealCost,
    this.territoryId,
    this.governorateId,
    this.managerId,
    this.managerType = ManagerType.none,
    this.homeLatitude,
    this.homeLongitude,
    this.isActive = true,
    this.avatarPath,
  });

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
        id: j['id'] as String,
        code: j['code'] as String,
        fullName: j['full_name'] as String,
        email: j['email'] as String?,
        phone: j['phone'] as String?,
        titleId: j['title_id'] as int?,
        titleName: (j['titles'] as Map<String, dynamic>?)?['name'] as String?,
        mealCost: ((j['titles'] as Map<String, dynamic>?)?['meal_cost'] as num?)?.toDouble(),
        territoryId: j['territory_id'] as int?,
        governorateId: j['governorate_id'] as int?,
        managerId: j['manager_id'] as String?,
        managerType: ManagerType.fromCode(j['manager_type'] as int?),
        homeLatitude: (j['home_latitude'] as num?)?.toDouble(),
        homeLongitude: (j['home_longitude'] as num?)?.toDouble(),
        isActive: j['is_active'] as bool? ?? true,
        avatarPath: j['avatar_path'] as String?,
      );
}
