import 'request_models.dart';
import 'package:cottage/helpers/supabase_service.dart';

const _memberSelect = 'profiles!user_id(first_name, last_name)';

/// Data layer for the meal/bazaar request-approval workflow -- mirrors
/// meal_requests (0027) and meal_cost_requests (0028): a member without
/// can_add_meals/can_add_bazaar submits a request instead of writing
/// directly; a manager (can_add_meals/can_add_bazaar) or the super admin
/// approves (which writes the real daily_meals/bazaar_entries row) or
/// rejects it. RLS on both tables already scopes every read/write to the
/// caller's own cottage and role, so these queries don't filter by
/// cottageId themselves beyond what's needed for `.insert()`.
class RequestService {
  final _client = SupabaseService.client;

  Future<List<MealRequest>> getMealRequests() async {
    final rows = await _client
        .from('meal_requests')
        .select(
          'id, user_id, request_date, lunch, dinner, status, created_at, $_memberSelect',
        )
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => MealRequest.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<MealCostRequest>> getMealCostRequests() async {
    final rows = await _client
        .from('meal_cost_requests')
        .select(
          'id, user_id, entry_date, amount, description, status, created_at, $_memberSelect',
        )
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => MealCostRequest.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Count of pending requests across both tables -- drives the badge on
  /// the bottom nav's Request tab. RLS already limits `select` to rows a
  /// manager/super admin is allowed to review (or the requester's own), so
  /// for a manager this is exactly "awaiting my review".
  Future<int> getPendingCount() async {
    final mealRows = await _client
        .from('meal_requests')
        .select('id')
        .eq('status', 'pending');
    final costRows = await _client
        .from('meal_cost_requests')
        .select('id')
        .eq('status', 'pending');
    return (mealRows as List).length + (costRows as List).length;
  }

  Future<void> createMealRequest({
    required String cottageId,
    required String userId,
    required String requestDate,
    required double lunch,
    required double dinner,
  }) async {
    await _client.from('meal_requests').insert({
      'cottage_id': cottageId,
      'user_id': userId,
      'request_date': requestDate,
      'lunch': lunch,
      'dinner': dinner,
    });
  }

  Future<void> createMealCostRequest({
    required String cottageId,
    required String userId,
    required String entryDate,
    required double amount,
    String? description,
  }) async {
    await _client.from('meal_cost_requests').insert({
      'cottage_id': cottageId,
      'user_id': userId,
      'entry_date': entryDate,
      'amount': amount,
      if (description != null && description.isNotEmpty)
        'description': description,
    });
  }

  String _monthKeyOf(String isoDate) => isoDate.substring(0, 7);

  /// Approving writes straight into `daily_meals` (mirrors what a manager's
  /// own "Add Meal" does), then marks the request reviewed.
  Future<void> approveMealRequest(
    MealRequest request, {
    required String cottageId,
    required String reviewerId,
  }) async {
    await _client.from('daily_meals').upsert({
      'user_id': request.userId,
      'cottage_id': cottageId,
      'month_key': _monthKeyOf(request.requestDate),
      'meal_date': request.requestDate,
      'count': request.total,
      'created_by': reviewerId,
    }, onConflict: 'user_id,meal_date');

    await _client
        .from('meal_requests')
        .update({
          'status': 'approved',
          'reviewed_by': reviewerId,
          'reviewed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', request.id);
  }

  Future<void> rejectMealRequest(
    String id, {
    required String reviewerId,
  }) async {
    await _client
        .from('meal_requests')
        .update({
          'status': 'rejected',
          'reviewed_by': reviewerId,
          'reviewed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  /// Approving reuses the same `add_bazaar_entry` RPC a manager's own "Add
  /// Bazar Cost" uses (credits the requester's meal deposit for the same
  /// amount in the same atomic call), then marks the request reviewed.
  Future<void> approveMealCostRequest(
    MealCostRequest request, {
    required String reviewerId,
  }) async {
    await _client.rpc(
      'add_bazaar_entry',
      params: {
        'p_month_key': _monthKeyOf(request.entryDate),
        'p_spent_by': request.userId,
        'p_amount': request.amount,
        'p_description': request.description,
        'p_entry_date': request.entryDate,
        'p_credit_deposit': true,
      },
    );

    await _client
        .from('meal_cost_requests')
        .update({
          'status': 'approved',
          'reviewed_by': reviewerId,
          'reviewed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', request.id);
  }

  Future<void> rejectMealCostRequest(
    String id, {
    required String reviewerId,
  }) async {
    await _client
        .from('meal_cost_requests')
        .update({
          'status': 'rejected',
          'reviewed_by': reviewerId,
          'reviewed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }
}
