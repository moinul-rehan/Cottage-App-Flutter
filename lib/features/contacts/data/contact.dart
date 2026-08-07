/// A cottage contact -- landlord, electrician, and other necessary people
/// for the house. Mirrors the `contacts` table. [label] is the role/tag
/// shown as a badge next to the name (e.g. "Landlord", "Electrician") --
/// the underlying column is named `level`, not `label`.
class Contact {
  final String id;
  final String cottageId;
  final String name;
  final String? label;
  final String? email;
  final String? mobileNumber;
  final String createdBy;
  final DateTime createdAt;

  const Contact({
    required this.id,
    required this.cottageId,
    required this.name,
    this.label,
    this.email,
    this.mobileNumber,
    required this.createdBy,
    required this.createdAt,
  });

  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'] as String,
      cottageId: map['cottage_id'] as String,
      name: map['name'] as String? ?? '',
      label: map['level'] as String?,
      email: map['email'] as String?,
      mobileNumber: map['mobile_number'] as String?,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
