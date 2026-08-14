import '../../bazaar_duty/data/bazaar_duty_models.dart';
import 'package:cottage/models/profile.dart';

/// One member's row in the "Member meal summary" grid. See
/// getMemberMealSummary in src/lib/data/meal.ts.
class MemberMealRow {
  final String id;
  final String firstName;
  final String? lastName;
  final String? avatarUrl;
  final double meals;
  final double deposit;
  final double cost;
  double get balance => deposit - cost;

  MemberMealRow({
    required this.id,
    required this.firstName,
    this.lastName,
    this.avatarUrl,
    required this.meals,
    required this.deposit,
    required this.cost,
  });

  String get displayName => (lastName?.isNotEmpty ?? false) ? lastName! : (firstName.isNotEmpty ? firstName : 'Member');
}

/// A member's utility due for the active month. See getMonthlyDues in
/// src/lib/data/finance.ts.
class MemberDue {
  final double rent;
  final double expenses;
  final double carryIn;
  final double paid;
  final double due;

  const MemberDue({
    required this.rent,
    required this.expenses,
    this.carryIn = 0,
    required this.paid,
    required this.due,
  });

  static const zero = MemberDue(rent: 0, expenses: 0, carryIn: 0, paid: 0, due: 0);
}

/// One carried-in balance from the previous closed month (utility_carry_ins
/// row). Label mirrors the `${monthLabel} ${kind} ${Due/Advanced/Balance}`
/// string built in src/app/(house)/dashboard/page.tsx.
class CarryInLine {
  final String id;
  final String label;
  final double amount;

  const CarryInLine({required this.id, required this.label, required this.amount});
}

/// One utility_adjustments row for the current user, kept individually (not
/// just summed) so the breakdown sheet / invoice can list them. See
/// UTILITY_CATEGORY_LABELS in src/lib/utility-categories.ts.
class AdjustmentLine {
  final String id;
  final DateTime date;
  final String label;
  final double amount;

  /// True when this row is the due-credit created by the member paying
  /// that category's expense out of their own pocket (linked via
  /// `related_expense_id` -- see UtilityService.addExpense's
  /// paymentSource == 'member' branch), as opposed to a cost actually
  /// assigned to them by the cottage. Kept as a separate row from whatever
  /// originally assigned this category's cost -- never a mutation of it --
  /// so the breakdown sheet can show the assigned amount unchanged and
  /// list this credit under "Paid" instead.
  final bool isMemberPaidCredit;

  const AdjustmentLine({
    required this.id,
    required this.date,
    required this.label,
    required this.amount,
    this.isMemberPaidCredit = false,
  });
}

/// One utility_deposits row (source_type == member) for the current user.
class DepositLine {
  final String id;
  final DateTime date;
  final String? note;
  final double amount;

  const DepositLine({required this.id, required this.date, this.note, required this.amount});
}

/// Everything the Dashboard screen renders, assembled by DashboardService.
class DashboardData {
  final String monthKey;
  final String cottageName;
  final double cottageBalance;
  final double totalUtilityExpense;
  final double outstandingFromMembers;
  final double collectedThisMonth;
  final MemberDue myDue;
  final double mealRate;
  final double totalMeals;
  final double totalBazaar;
  final List<MemberMealRow> memberMealRows;
  final List<CarryInLine> myCarryInLines;
  final List<AdjustmentLine> myAdjustmentLines;
  final List<DepositLine> myDepositLines;
  final List<BazaarDuty> bazaarDuties;
  final Map<String, Profile> membersById;

  const DashboardData({
    required this.monthKey,
    this.cottageName = '',
    required this.cottageBalance,
    required this.totalUtilityExpense,
    required this.outstandingFromMembers,
    required this.collectedThisMonth,
    required this.myDue,
    required this.mealRate,
    required this.totalMeals,
    required this.totalBazaar,
    required this.memberMealRows,
    this.myCarryInLines = const [],
    this.myAdjustmentLines = const [],
    this.myDepositLines = const [],
    this.bazaarDuties = const [],
    this.membersById = const {},
  });

  double get myAssignedCost => myDue.rent + myDue.expenses + myDue.carryIn;
}
