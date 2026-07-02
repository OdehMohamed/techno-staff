class AppUser {
  final String id;
  final String email;
  final String name;
  final String role;
  final bool isActive;
  // Collector-only: agorot; null = no limit. CF-maintained on user doc.
  final int? maxCashOnHand;
  // Collector-only: cumulative agorot owed to the company from unresolved
  // handover discrepancies. CF-maintained; admin clears when collector pays back.
  final int discrepancyBalance;

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.isActive,
    this.maxCashOnHand,
    this.discrepancyBalance = 0,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, String documentId) {
    return AppUser(
      id: documentId,
      email: map['email'] as String? ?? '',
      name: map['name'] as String? ?? '',
      role: map['role'] as String? ?? 'employee',
      isActive: map['isActive'] as bool? ?? false,
      maxCashOnHand: (map['maxCashOnHand'] as num?)?.toInt(),
      discrepancyBalance: (map['discrepancyBalance'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {'email': email, 'name': name, 'role': role, 'isActive': isActive};
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? name,
    String? role,
    bool? isActive,
    int? maxCashOnHand,
    bool clearMaxCashOnHand = false,
    int? discrepancyBalance,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      maxCashOnHand:
          clearMaxCashOnHand ? null : (maxCashOnHand ?? this.maxCashOnHand),
      discrepancyBalance: discrepancyBalance ?? this.discrepancyBalance,
    );
  }
}
