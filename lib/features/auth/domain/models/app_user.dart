class AppUser {
  final String id;
  final String email;
  final String name;
  final String role;
  final bool isActive;

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.isActive,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, String documentId) {
    return AppUser(
      id: documentId,
      email: map['email'] as String? ?? '',
      name: map['name'] as String? ?? '',
      role: map['role'] as String? ?? 'employee',
      isActive: map['isActive'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {'email': email, 'name': name, 'role': role, 'isActive': isActive};
  }

  AppUser copyWith({String? id, String? email, String? name, String? role, bool? isActive}) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
    );
  }
}
