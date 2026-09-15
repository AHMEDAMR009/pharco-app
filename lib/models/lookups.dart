class Governorate {
  final int id;
  final String nameEn;
  final String? nameAr;

  Governorate({required this.id, required this.nameEn, this.nameAr});

  factory Governorate.fromJson(Map<String, dynamic> j) => Governorate(
        id: j['id'] as int,
        nameEn: j['name_en'] as String,
        nameAr: j['name_ar'] as String?,
      );
}

class City {
  final int id;
  final int governorateId;
  final String nameEn;
  final String? nameAr;
  final double latitude;
  final double longitude;

  City({
    required this.id,
    required this.governorateId,
    required this.nameEn,
    this.nameAr,
    required this.latitude,
    required this.longitude,
  });

  factory City.fromJson(Map<String, dynamic> j) => City(
        id: j['id'] as int,
        governorateId: j['governorate_id'] as int,
        nameEn: j['name_en'] as String,
        nameAr: j['name_ar'] as String?,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
      );
}

class Title {
  final int id;
  final String name;
  final double mealCost;

  Title({required this.id, required this.name, required this.mealCost});

  factory Title.fromJson(Map<String, dynamic> j) => Title(
        id: j['id'] as int,
        name: j['name'] as String,
        mealCost: (j['meal_cost'] as num).toDouble(),
      );
}

class ReimbursementPolicy {
  final double minimumKm;
  final double pricePerKm;

  ReimbursementPolicy({required this.minimumKm, required this.pricePerKm});

  factory ReimbursementPolicy.fromJson(Map<String, dynamic> j) => ReimbursementPolicy(
        minimumKm: (j['minimum_km'] as num).toDouble(),
        pricePerKm: (j['price_per_km'] as num).toDouble(),
      );

  static ReimbursementPolicy fallback() => ReimbursementPolicy(minimumKm: 27, pricePerKm: 2.75);
}
