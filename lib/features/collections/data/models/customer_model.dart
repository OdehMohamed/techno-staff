import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final String? phone2;
  final String? address;
  final String assignedCollectorId;
  final String assignedCollectorName;
  final String? guarantor;
  final String? guarantorPhone;
  final String? externalReference;
  final String accountStatus; // good_standing | at_risk | delinquent
  final String? notes;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final bool isActive;

  const CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    this.phone2,
    this.address,
    required this.assignedCollectorId,
    required this.assignedCollectorName,
    this.guarantor,
    this.guarantorPhone,
    this.externalReference,
    this.accountStatus = 'good_standing',
    this.notes,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    this.isActive = true,
  });

  factory CustomerModel.fromMap(Map<String, dynamic> map, String id) {
    return CustomerModel(
      id: id,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      phone2: map['phone2'] as String?,
      address: map['address'] as String?,
      assignedCollectorId: map['assignedCollectorId'] as String? ?? '',
      assignedCollectorName: map['assignedCollectorName'] as String? ?? '',
      guarantor: map['guarantor'] as String?,
      guarantorPhone: map['guarantorPhone'] as String?,
      externalReference: map['externalReference'] as String?,
      accountStatus: map['accountStatus'] as String? ?? 'good_standing',
      notes: map['notes'] as String?,
      createdBy: map['createdBy'] as String? ?? '',
      createdByName: map['createdByName'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'name': name,
      'phone': phone,
      if (phone2 != null && phone2!.isNotEmpty) 'phone2': phone2,
      if (address != null && address!.isNotEmpty) 'address': address,
      'assignedCollectorId': assignedCollectorId,
      'assignedCollectorName': assignedCollectorName,
      if (guarantor != null && guarantor!.isNotEmpty) 'guarantor': guarantor,
      if (guarantorPhone != null && guarantorPhone!.isNotEmpty) 'guarantorPhone': guarantorPhone,
      if (externalReference != null && externalReference!.isNotEmpty) 'externalReference': externalReference,
      'accountStatus': 'good_standing',
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'name': name,
      'phone': phone,
      'phone2': (phone2?.isNotEmpty == true) ? phone2 : null,
      'address': (address?.isNotEmpty == true) ? address : null,
      'assignedCollectorId': assignedCollectorId,
      'assignedCollectorName': assignedCollectorName,
      'guarantor': (guarantor?.isNotEmpty == true) ? guarantor : null,
      'guarantorPhone': (guarantorPhone?.isNotEmpty == true) ? guarantorPhone : null,
      'externalReference': (externalReference?.isNotEmpty == true) ? externalReference : null,
      'notes': (notes?.isNotEmpty == true) ? notes : null,
    };
  }

  CustomerModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? phone2,
    bool clearPhone2 = false,
    String? address,
    bool clearAddress = false,
    String? assignedCollectorId,
    String? assignedCollectorName,
    String? guarantor,
    bool clearGuarantor = false,
    String? guarantorPhone,
    bool clearGuarantorPhone = false,
    String? externalReference,
    bool clearExternalReference = false,
    String? accountStatus,
    String? notes,
    bool clearNotes = false,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      phone2: clearPhone2 ? null : (phone2 ?? this.phone2),
      address: clearAddress ? null : (address ?? this.address),
      assignedCollectorId: assignedCollectorId ?? this.assignedCollectorId,
      assignedCollectorName: assignedCollectorName ?? this.assignedCollectorName,
      guarantor: clearGuarantor ? null : (guarantor ?? this.guarantor),
      guarantorPhone: clearGuarantorPhone ? null : (guarantorPhone ?? this.guarantorPhone),
      externalReference: clearExternalReference ? null : (externalReference ?? this.externalReference),
      accountStatus: accountStatus ?? this.accountStatus,
      notes: clearNotes ? null : (notes ?? this.notes),
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
