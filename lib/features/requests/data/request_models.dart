/// Mirrors `meal_requests.status`/`meal_cost_requests.status` -- see
/// supabase/migrations/0027_meal_requests.sql, 0028_meal_cost_requests.sql.
enum RequestStatus { pending, approved, rejected, cancelled }

RequestStatus _statusFromString(String s) => RequestStatus.values.firstWhere(
  (v) => v.name == s,
  orElse: () => RequestStatus.pending,
);

/// A member's request to log a meal for themselves on a date, awaiting a
/// meal manager's (or the super admin's) approval -- mirrors the
/// `meal_requests` table.
class MealRequest {
  final String id;
  final String userId;
  final String? memberName;
  final String requestDate;
  final double lunch;
  final double dinner;
  final RequestStatus status;
  final DateTime createdAt;

  double get total => lunch + dinner;

  const MealRequest({
    required this.id,
    required this.userId,
    this.memberName,
    required this.requestDate,
    required this.lunch,
    required this.dinner,
    required this.status,
    required this.createdAt,
  });

  factory MealRequest.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    return MealRequest(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      memberName: profile == null
          ? null
          : [
              profile['first_name'],
              profile['last_name'],
            ].where((s) => s != null && (s as String).isNotEmpty).join(' '),
      requestDate: map['request_date'] as String,
      lunch: (map['lunch'] as num).toDouble(),
      dinner: (map['dinner'] as num).toDouble(),
      status: _statusFromString(map['status'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// A member's request to log a bazaar (grocery) cost they paid for,
/// awaiting a bazaar manager's (or the super admin's) approval -- mirrors
/// the `meal_cost_requests` table.
class MealCostRequest {
  final String id;
  final String userId;
  final String? memberName;
  final String entryDate;
  final double amount;
  final String? description;
  final RequestStatus status;
  final DateTime createdAt;

  const MealCostRequest({
    required this.id,
    required this.userId,
    this.memberName,
    required this.entryDate,
    required this.amount,
    this.description,
    required this.status,
    required this.createdAt,
  });

  factory MealCostRequest.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    return MealCostRequest(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      memberName: profile == null
          ? null
          : [
              profile['first_name'],
              profile['last_name'],
            ].where((s) => s != null && (s as String).isNotEmpty).join(' '),
      entryDate: map['entry_date'] as String,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String?,
      status: _statusFromString(map['status'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
