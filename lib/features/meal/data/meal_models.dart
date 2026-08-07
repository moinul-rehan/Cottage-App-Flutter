/// A single day's meal count for one member.
class DailyMeal {
  final String? id;
  final String userId;
  final String monthKey;
  final String date; // 'YYYY-MM-DD'
  final double count;
  final String? memberName;

  const DailyMeal({
    this.id,
    required this.userId,
    required this.monthKey,
    required this.date,
    required this.count,
    this.memberName,
  });

  factory DailyMeal.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    final firstName = profile?['first_name'] as String? ?? '';
    final lastName = profile?['last_name'] as String? ?? '';
    final displayName = lastName.isNotEmpty
        ? lastName
        : (firstName.isNotEmpty ? firstName : 'Member');

    return DailyMeal(
      id: map['id'] as String?,
      userId: map['user_id'] as String,
      monthKey: map['month_key'] as String,
      date: map['meal_date'] as String,
      count: (map['count'] as num).toDouble(),
      memberName: displayName,
    );
  }
}

/// A bazaar (grocery purchase) entry.
class BazaarEntry {
  final String id;
  final String? userId;
  final String monthKey;
  final double amount;
  final String? description;
  final String date; // 'YYYY-MM-DD'
  final String? memberName;
  final String? avatarUrl;

  const BazaarEntry({
    required this.id,
    this.userId,
    required this.monthKey,
    required this.amount,
    this.description,
    required this.date,
    this.memberName,
    this.avatarUrl,
  });

  factory BazaarEntry.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    final firstName = profile?['first_name'] as String? ?? '';
    final lastName = profile?['last_name'] as String? ?? '';
    final displayName = lastName.isNotEmpty
        ? lastName
        : (firstName.isNotEmpty ? firstName : 'Member');

    return BazaarEntry(
      id: map['id'] as String,
      userId: map['spent_by'] as String?,
      monthKey: map['month_key'] as String,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String?,
      date: map['entry_date'] as String? ?? map['created_at']?.toString().substring(0, 10) ?? '',
      memberName: displayName,
      avatarUrl: profile?['avatar_url'] as String?,
    );
  }
}

/// A meal deposit entry.
class MealDeposit {
  final String id;
  final String userId;
  final String monthKey;
  final double amount;
  final String date; // 'YYYY-MM-DD'
  final String? note;
  final String? memberName;
  final String? avatarUrl;

  const MealDeposit({
    required this.id,
    required this.userId,
    required this.monthKey,
    required this.amount,
    required this.date,
    this.note,
    this.memberName,
    this.avatarUrl,
  });

  factory MealDeposit.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    final firstName = profile?['first_name'] as String? ?? '';
    final lastName = profile?['last_name'] as String? ?? '';
    final displayName = lastName.isNotEmpty
        ? lastName
        : (firstName.isNotEmpty ? firstName : 'Member');
    final avatarUrl = profile?['avatar_url'] as String?;

    return MealDeposit(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      monthKey: map['month_key'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: map['deposit_date'] as String? ?? '',
      note: map['note'] as String?,
      memberName: displayName,
      avatarUrl: avatarUrl,
    );
  }
}

