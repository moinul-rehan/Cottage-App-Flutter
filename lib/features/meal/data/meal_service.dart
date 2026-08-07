import 'meal_models.dart';
import 'package:cottage/helpers/supabase_service.dart';

/// Data layer for the Meal tab — daily meal counts and bazaar entries.
class MealService {
  final _client = SupabaseService.client;

  /// Fetch all daily meal entries for the given month, with member names.
  Future<List<DailyMeal>> getDailyMeals(String monthKey) async {
    final rows = await _client
        .from('daily_meals')
        .select('*, profiles!daily_meals_user_id_fkey(first_name, last_name)')
        .eq('month_key', monthKey)
        .order('meal_date', ascending: false);

    return (rows as List)
        .map((r) => DailyMeal.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Add or update a meal count for a member on a specific date.
  Future<void> upsertMeal({
    required String userId,
    required String monthKey,
    required String date,
    required double count,
    required String cottageId,
  }) async {
    await _client.from('daily_meals').upsert(
      {
        'user_id': userId,
        'month_key': monthKey,
        'meal_date': date,
        'count': count,
        'cottage_id': cottageId,
      },
      onConflict: 'user_id,meal_date',
    );
  }

  /// Fetch all bazaar entries for the given month, with shopper names and avatars.
  Future<List<BazaarEntry>> getBazaarEntries(String monthKey) async {
    final rows = await _client
        .from('bazaar_entries')
        .select('*, profiles!bazaar_entries_spent_by_fkey(first_name, last_name, avatar_url)')
        .eq('month_key', monthKey)
        .order('entry_date', ascending: false);

    return (rows as List)
        .map((r) => BazaarEntry.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Add a new bazaar entry, optionally crediting the member's meal deposit.
  Future<void> addBazaarEntry({
    required String userId,
    required String monthKey,
    required double amount,
    required String date,
    required String cottageId,
    String? description,
    bool creditDeposit = false,
  }) async {
    await _client.from('bazaar_entries').insert({
      'spent_by': userId,
      'month_key': monthKey,
      'amount': amount,
      'entry_date': date,
      'cottage_id': cottageId,
      if (description != null && description.isNotEmpty) 'description': description,
    });

    if (creditDeposit) {
      await _client.from('meal_deposits').insert({
        'user_id': userId,
        'month_key': monthKey,
        'amount': amount,
        'deposit_date': date,
        'cottage_id': cottageId,
        'note': 'Auto-credited from bazaar entry',
        'created_by': userId, // using the member's ID as creator for standard tracking
      });
    }
  }

  /// Update an existing bazaar entry.
  Future<void> updateBazaarEntry({
    required String id,
    required double amount,
    required String date,
    String? description,
  }) async {
    await _client.from('bazaar_entries').update({
      'amount': amount,
      'entry_date': date,
      'description': description ?? '',
    }).eq('id', id);
  }

  /// Delete a bazaar entry.
  Future<void> deleteBazaarEntry(String id) async {
    await _client.from('bazaar_entries').delete().eq('id', id);
  }

  /// Fetch all meal deposits for the given month, with shopper names and avatars.
  Future<List<MealDeposit>> getMealDeposits(String monthKey) async {
    final rows = await _client
        .from('meal_deposits')
        .select('*, profiles!meal_deposits_user_id_fkey(first_name, last_name, avatar_url)')
        .eq('month_key', monthKey)
        .order('deposit_date', ascending: false);

    return (rows as List)
        .map((r) => MealDeposit.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Add a new meal deposit.
  Future<void> addMealDeposit({
    required String userId,
    required String monthKey,
    required double amount,
    required String date,
    required String cottageId,
    String? note,
  }) async {
    await _client.from('meal_deposits').insert({
      'user_id': userId,
      'month_key': monthKey,
      'amount': amount,
      'deposit_date': date,
      'cottage_id': cottageId,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  /// Update an existing meal deposit.
  Future<void> updateMealDeposit({
    required String id,
    required double amount,
    required String date,
    String? note,
  }) async {
    await _client.from('meal_deposits').update({
      'amount': amount,
      'deposit_date': date,
      'note': note ?? '',
    }).eq('id', id);
  }

  /// Delete a meal deposit.
  Future<void> deleteMealDeposit(String id) async {
    await _client.from('meal_deposits').delete().eq('id', id);
  }
}
