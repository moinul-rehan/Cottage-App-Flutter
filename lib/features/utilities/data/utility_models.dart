/// A shared cottage expense (electricity, gas, internet, etc.).
class Expense {
  final String id;
  final String? cottageId;
  final double amount;
  final String? description;
  final String? category;
  final String expenseDate; // 'YYYY-MM-DD'
  final String? payerName;
  final String? paymentSource;

  const Expense({
    required this.id,
    this.cottageId,
    required this.amount,
    this.description,
    this.category,
    required this.expenseDate,
    this.payerName,
    this.paymentSource,
  });

  factory Expense.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>? ?? map['payer'] as Map<String, dynamic>?;
    final firstName = profile?['first_name'] as String? ?? '';
    final lastName = profile?['last_name'] as String? ?? '';
    final displayName = lastName.isNotEmpty
        ? lastName
        : (firstName.isNotEmpty ? firstName : null);

    return Expense(
      id: map['id'] as String,
      cottageId: map['cottage_id'] as String?,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String?,
      category: map['category'] as String?,
      expenseDate: map['expense_date'] as String,
      payerName: displayName,
      paymentSource: map['payment_source'] as String?,
    );
  }
}

/// A member's utility deposit for a given month.
class UtilityDeposit {
  final String id;
  final String userId;
  final String cottageId;
  final String monthKey;
  final double amount;
  final String sourceType;
  final String? memberName;
  final String? avatarUrl;
  final String? note;
  final DateTime? createdAt;

  const UtilityDeposit({
    required this.id,
    required this.userId,
    required this.cottageId,
    required this.monthKey,
    required this.amount,
    required this.sourceType,
    this.memberName,
    this.avatarUrl,
    this.note,
    this.createdAt,
  });

  bool get isMemberDeposit => sourceType == 'member';

  factory UtilityDeposit.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    final firstName = profile?['first_name'] as String? ?? '';
    final lastName = profile?['last_name'] as String? ?? '';
    final displayName = lastName.isNotEmpty
        ? lastName
        : (firstName.isNotEmpty ? firstName : 'Member');

    return UtilityDeposit(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      cottageId: map['cottage_id'] as String,
      monthKey: map['month_key'] as String,
      amount: (map['amount'] as num).toDouble(),
      sourceType: map['source_type'] as String? ?? 'member',
      memberName: displayName,
      avatarUrl: profile?['avatar_url'] as String?,
      note: map['note'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }
}

/// A member's full utility breakdown for the month.
class MemberUtilityDue {
  final String userId;
  final String memberName;
  final String? avatarUrl;
  final double rent;
  final double expenses;
  final double paid;
  double get total => rent + expenses;
  double get due => total - paid;

  const MemberUtilityDue({
    required this.userId,
    required this.memberName,
    this.avatarUrl,
    required this.rent,
    required this.expenses,
    required this.paid,
  });
}
