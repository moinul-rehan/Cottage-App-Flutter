import 'package:cottage/models/profile.dart';
import 'utility_models.dart';
import 'package:cottage/helpers/supabase_service.dart';
import 'package:cottage/helpers/utility_categories.dart';

/// Data layer for the Utilities tab — expenses, deposits, and member dues.
class UtilityService {
  final _client = SupabaseService.client;

  /// [start, end) date bounds for a "YYYY-MM" month key.
  (String start, String end) _monthRange(String monthKey) {
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final start = DateTime.utc(year, month, 1);
    final end = DateTime.utc(year, month + 1, 1);
    String iso(DateTime d) => d.toIso8601String().substring(0, 10);
    return (iso(start), iso(end));
  }

  /// Fetch all expenses for the given month.
  Future<List<Expense>> getExpenses(String monthKey) async {
    final (start, end) = _monthRange(monthKey);
    final rows = await _client
        .from('expenses')
        .select(
          '*, payer:profiles!expenses_paid_by_fkey(first_name, last_name)',
        )
        .gte('expense_date', start)
        .lt('expense_date', end)
        .order('expense_date', ascending: false);

    return (rows as List)
        .map((r) => Expense.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Add a new utility expense, plus the exact side effects the web app's
  /// `addExpense` server action applies for the chosen [paymentSource] (see
  /// src/app/(house)/utilities/actions.ts): `'cottage_balance'` debits the
  /// shared fund (a `cottage_balance_transactions` row), `'member'` credits
  /// [paidByMemberId]'s utility due directly (a negative `utility_adjustments`
  /// row, since they already paid the vendor out of pocket -- this is what
  /// `paid_by` also reflects), `'none'` just records the expense with no
  /// other effect. Previously this only wrote a free-text `payment_source`
  /// string onto the expense row and skipped these side effects entirely.
  Future<void> addExpense({
    required String cottageId,
    required String createdBy,
    required String monthKey,
    required double amount,
    required String expenseDate,
    String? description,
    required String category,
    required String paymentSource,
    String? paidByMemberId,
  }) async {
    assert(
      paymentSource == 'member' ||
          paymentSource == 'cottage_balance' ||
          paymentSource == 'none',
    );
    assert(paymentSource != 'member' || paidByMemberId != null);

    final paidBy = paymentSource == 'member' ? paidByMemberId! : createdBy;
    final expenseRow = await _client
        .from('expenses')
        .insert({
          'cottage_id': cottageId,
          'category': category,
          'amount': amount,
          if (description != null && description.isNotEmpty)
            'description': description,
          'paid_by': paidBy,
          'expense_date': expenseDate,
          'split_type': 'custom',
          'payment_source': paymentSource,
          'created_by': createdBy,
        })
        .select('id')
        .single();
    final expenseId = expenseRow['id'] as String;

    if (paymentSource == 'cottage_balance') {
      await _client.from('cottage_balance_transactions').insert({
        'cottage_id': cottageId,
        'amount': amount,
        'direction': 'out',
        'reason': (description != null && description.isNotEmpty)
            ? description
            : category,
        'related_expense_id': expenseId,
        'created_by': createdBy,
      });
    } else if (paymentSource == 'member') {
      await _client.from('utility_adjustments').insert({
        'cottage_id': cottageId,
        'month_key': monthKey,
        'user_id': paidByMemberId,
        'category': category,
        'amount': -amount,
        'payment_source': 'none',
        'payment_member_id': null,
        'related_expense_id': expenseId,
        'created_by': createdBy,
      });
    }
  }

  /// Edits an existing expense in place -- mirrors `updateExpense` in
  /// src/app/(house)/utilities/actions.ts. Any linked
  /// `cottage_balance_transactions`/`utility_adjustments` row (written by
  /// [addExpense] for the 'cottage_balance'/'member' payment sources) is
  /// kept in sync the same way the web action does; if this expense's
  /// payment source never created one of those rows (e.g. 'none'), the
  /// matching `.update()` here just affects zero rows, which Supabase
  /// doesn't treat as an error.
  Future<void> updateExpense({
    required String id,
    required String category,
    required double amount,
    String? description,
    required String expenseDate,
  }) async {
    await _client
        .from('expenses')
        .update({
          'category': category,
          'amount': amount,
          'description': description,
          'expense_date': expenseDate,
        })
        .eq('id', id);

    await _client
        .from('cottage_balance_transactions')
        .update({
          'amount': amount,
          'reason': description ?? utilityCategoryLabel(category),
        })
        .eq('related_expense_id', id);

    await _client
        .from('utility_adjustments')
        .update({'amount': -amount, 'category': category})
        .eq('related_expense_id', id);
  }

  /// Deletes an expense; migration 0051_editable_utility_records.sql put
  /// `ON DELETE CASCADE` on both `cottage_balance_transactions
  /// .related_expense_id` and `utility_adjustments.related_expense_id`, so
  /// the linked balance transaction or member due-credit (if either exists
  /// for this expense) is removed automatically -- mirrors `deleteExpense`.
  Future<void> deleteExpense(String id) async {
    await _client.from('expenses').delete().eq('id', id);
  }

  /// Edits an existing deposit (member or cottage) in place -- mirrors
  /// `updateMemberUtilityDeposit`/`updateCottageDeposit`.
  Future<void> updateDeposit({
    required String id,
    required double amount,
    required String depositDate,
    String? note,
    required String defaultReason,
  }) async {
    await _client
        .from('utility_deposits')
        .update({
          'amount': amount,
          'deposit_date': depositDate,
          'note': note,
        })
        .eq('id', id);

    await _client
        .from('cottage_balance_transactions')
        .update({'amount': amount, 'reason': note ?? defaultReason})
        .eq('related_deposit_id', id);
  }

  /// Deletes a deposit (member or cottage); the linked
  /// `cottage_balance_transactions` row cascades away automatically (see
  /// [deleteExpense]'s doc comment) -- mirrors
  /// `deleteMemberUtilityDeposit`/`deleteCottageDeposit`.
  Future<void> deleteDeposit(String id) async {
    await _client.from('utility_deposits').delete().eq('id', id);
  }

  /// Fetch all utility deposits for the given month, with member names.
  Future<List<UtilityDeposit>> getDeposits(
    String cottageId,
    String monthKey,
  ) async {
    final rows = await _client
        .from('utility_deposits')
        .select(
          '*, profiles!utility_deposits_user_id_fkey(first_name, last_name, avatar_url)',
        )
        .eq('cottage_id', cottageId)
        .eq('month_key', monthKey)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) => UtilityDeposit.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Add a utility deposit -- either `'member'` (a roommate's personal
  /// contribution toward their own due, requires [userId]) or `'addition'`
  /// (the cottage's own money entering the fund directly, no member
  /// account changes -- [userId] must be omitted/null for this one). Ports
  /// `addMemberUtilityDeposit`/`addCottageDeposit` in
  /// src/app/(house)/utilities/actions.ts exactly, including their shared
  /// side effect this used to skip entirely: both credit
  /// `cottage_balance_transactions` (`direction: 'in'`) for the same
  /// amount, linked via `related_deposit_id` -- without that insert,
  /// Cottage Balance permanently under-counted every deposit ever
  /// recorded, member or cottage. The `source_type` value itself used to
  /// be the literal `'cottage'`, which isn't a value the DB's check
  /// constraint (`source_type in ('member','addition')`, see migration
  /// 0016) allows -- every "Add Cottage Deposit" was silently failing to
  /// insert at all.
  Future<void> addDeposit({
    required String cottageId,
    required String monthKey,
    required double amount,
    required String createdBy,
    required String depositDate,
    String? userId,
    String sourceType = 'member',
    String? note,
  }) async {
    assert(sourceType == 'member' || sourceType == 'addition');
    assert(sourceType != 'member' || userId != null);
    assert(sourceType != 'addition' || userId == null);

    final depositRow = await _client
        .from('utility_deposits')
        .insert({
          'cottage_id': cottageId,
          'month_key': monthKey,
          'user_id': userId,
          'source_type': sourceType,
          'amount': amount,
          'deposit_date': depositDate,
          if (note != null && note.isNotEmpty) 'note': note,
          'created_by': createdBy,
        })
        .select('id')
        .single();
    final depositId = depositRow['id'] as String;

    await _client.from('cottage_balance_transactions').insert({
      'cottage_id': cottageId,
      'amount': amount,
      'direction': 'in',
      'reason': (note != null && note.isNotEmpty)
          ? note
          : (sourceType == 'member'
                ? 'Member Utility Deposit'
                : 'Cottage Deposit'),
      'related_deposit_id': depositId,
      'created_by': createdBy,
    });
  }

  /// Compute every active member's utility due for the month.
  Future<List<MemberUtilityDue>> getMemberDues(
    String cottageId,
    String monthKey,
    List<Profile> members,
  ) async {
    final adjustments = await _client
        .from('utility_adjustments')
        .select('user_id, category, amount')
        .eq('cottage_id', cottageId)
        .eq('month_key', monthKey);

    final deposits = await _client
        .from('utility_deposits')
        .select('user_id, amount')
        .eq('cottage_id', cottageId)
        .eq('month_key', monthKey)
        .eq('source_type', 'member');

    final rentByUser = <String, double>{};
    final expenseByUser = <String, double>{};
    for (final row in adjustments as List) {
      final userId = row['user_id'] as String;
      final amount = (row['amount'] as num).toDouble();
      if (row['category'] == 'house_rent') {
        rentByUser[userId] = (rentByUser[userId] ?? 0) + amount;
      } else {
        expenseByUser[userId] = (expenseByUser[userId] ?? 0) + amount;
      }
    }

    final paidByUser = <String, double>{};
    for (final row in deposits as List) {
      final userId = row['user_id'] as String;
      final amount = (row['amount'] as num).toDouble();
      paidByUser[userId] = (paidByUser[userId] ?? 0) + amount;
    }

    return members.map((m) {
      return MemberUtilityDue(
        userId: m.id,
        memberName: m.displayName,
        avatarUrl: m.avatarUrl,
        rent: rentByUser[m.id] ?? 0,
        expenses: expenseByUser[m.id] ?? 0,
        paid: paidByUser[m.id] ?? 0,
      );
    }).toList();
  }
}
