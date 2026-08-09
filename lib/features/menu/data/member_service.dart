import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cottage/models/profile.dart';
import 'package:cottage/helpers/supabase_service.dart';

/// Fetch and manage cottage members.
class MemberService {
  final _client = SupabaseService.client;

  /// Fetch all active members for the given cottage -- excludes soft-removed
  /// profiles (`removed_at is not null`) the same way every member query
  /// here does, so a removed member can never resurface in a meal count
  /// form, bazaar duty picker, or cost split just because they're still
  /// technically "active" from before they were removed.
  Future<List<Profile>> getActiveMembers(String cottageId) async {
    final rows = await _client
        .from('profiles')
        .select('id, cottage_id, first_name, last_name, email, avatar_url')
        .eq('cottage_id', cottageId)
        .eq('is_active', true)
        .isFilter('removed_at', null)
        .order('first_name');

    return (rows as List)
        .map((r) => Profile.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  static const _allMembersColumns =
      'id, cottage_id, first_name, last_name, email, avatar_url, mobile_number, address, room_label, hometown, '
      'role, is_active, removed_at, '
      'can_add_expenses, can_add_bazaar, can_add_meals, can_add_deposit, can_add_notice';

  /// Fetch every member of the cottage, active or inactive -- for the
  /// Members list screen, which shows an "Inactive" pill rather than
  /// hiding them. Still excludes soft-removed profiles: once removed, a
  /// member drops off this list entirely (their historical records stay
  /// intact -- only their spot on the roster disappears).
  Future<List<Profile>> getAllMembers(String cottageId) async {
    final rows = await _client
        .from('profiles')
        .select(_allMembersColumns)
        .eq('cottage_id', cottageId)
        .isFilter('removed_at', null)
        .order('is_active', ascending: false)
        .order('first_name');

    return (rows as List)
        .map((r) => Profile.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Activate/deactivate a member -- only meaningful for a super admin
  /// acting on someone else, enforced by RLS server-side.
  Future<void> setActive(String userId, bool active) async {
    await _client
        .from('profiles')
        .update({'is_active': active})
        .eq('id', userId);
  }

  /// Soft-removes a member from the cottage roster. The `profiles` row
  /// (and every expense/meal/deposit/statement that references it) is
  /// never deleted -- only `removed_at` is stamped, which every member
  /// query above already filters out.
  ///
  /// Mirrors the web app's three guardrails client-side (defense in depth
  /// -- `profiles_admin_write` RLS lets any super admin update any row in
  /// their own cottage, so it alone wouldn't stop these):
  /// - a super admin can't remove themselves
  /// - a super admin can't remove another super admin
  /// - a member must already be deactivated before they can be removed
  ///
  /// NOTE: this does NOT ban the member's auth account. Doing that needs
  /// `admin.auth.admin.updateUserById(..., { ban_duration })`, which only
  /// works with the Supabase service_role key -- that key must never be
  /// embedded in a distributable mobile app (it grants full admin access
  /// to every table, bypassing RLS entirely). A removed member is fully
  /// hidden from the roster and excluded from every active-member query,
  /// but their account isn't blocked from signing in until a trusted
  /// server-side endpoint (an Edge Function or a Next.js API route
  /// authenticated the same way, calling that Admin API) does the ban.
  /// That endpoint doesn't exist in this codebase yet.
  Future<void> removeMember({
    required Profile viewer,
    required Profile target,
  }) async {
    if (target.id == viewer.id) {
      throw Exception('You cannot remove yourself.');
    }
    if (target.isSuperAdmin) {
      throw Exception('Super admins cannot be removed.');
    }
    if (target.isActive) {
      throw Exception('Deactivate this member before removing them.');
    }
    await _client
        .from('profiles')
        .update({'removed_at': DateTime.now().toIso8601String()})
        .eq('id', target.id);
  }

  /// Grant/revoke a member's per-action permissions -- mirrors
  /// `profiles.can_add_*` (see supabase/migrations/0002, 0004, 0010, 0022),
  /// each independently enforced by RLS server-side. Only a super admin can
  /// actually change another member's row; RLS rejects anyone else's
  /// attempt.
  Future<void> updatePermissions({
    required String userId,
    required bool canAddExpenses,
    required bool canAddBazaar,
    required bool canAddMeals,
    required bool canAddDeposit,
    required bool canAddNotice,
  }) async {
    await _client
        .from('profiles')
        .update({
          'can_add_expenses': canAddExpenses,
          'can_add_bazaar': canAddBazaar,
          'can_add_meals': canAddMeals,
          'can_add_deposit': canAddDeposit,
          'can_add_notice': canAddNotice,
        })
        .eq('id', userId);
  }

  /// Get cottage name.
  Future<String> getCottageName(String cottageId) async {
    final row = await _client
        .from('cottages')
        .select('name')
        .eq('id', cottageId)
        .single();
    return row['name'] as String? ?? 'Cottage';
  }

  /// Invites or directly adds a member by email.
  /// If a user with [email] exists in `profiles`:
  /// - If they belong to this cottage already, returns [InviteMemberResult.alreadyInThisCottage].
  /// - If they belong to another cottage, returns [InviteMemberResult.alreadyInAnotherCottage].
  /// - If they have no cottage (or `cottage_id` is null/empty), directly updates their profile
  ///   to join [cottageId] with [role], [roomLabel], etc., and returns [InviteMemberResult.added].
  /// If no profile is found for [email], returns [InviteMemberResult.needsSignup].
  Future<InviteMemberResult> inviteOrAddMember({
    required String cottageId,
    required String email,
    required String firstName,
    required String lastName,
    required String role,
    String? roomLabel,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final rows = await _client
        .from('profiles')
        .select('id, cottage_id, email, first_name, last_name, removed_at, is_active')
        .ilike('email', cleanEmail);

    if (rows.isEmpty) {
      return InviteMemberResult.needsSignup;
    }

    final profileRow = (rows as List).first as Map<String, dynamic>;
    final existingCottageId = profileRow['cottage_id'] as String?;
    final removedAt = profileRow['removed_at'];

    // If profile belongs to another cottage, reject:
    if (existingCottageId != null &&
        existingCottageId.isNotEmpty &&
        existingCottageId != cottageId) {
      return InviteMemberResult.alreadyInAnotherCottage;
    }

    // If profile belongs to THIS cottage and is already active & not removed:
    if (existingCottageId == cottageId &&
        removedAt == null &&
        (profileRow['is_active'] == true)) {
      return InviteMemberResult.alreadyInThisCottage;
    }

    // Otherwise (no cottage assigned OR soft-removed/inactive in this cottage),
    // restore and activate their profile so they immediately appear in the member list!
    final updateData = <String, dynamic>{
      'cottage_id': cottageId,
      'role': role,
      'is_active': true,
      'removed_at': null,
    };

    final existingFirstName = profileRow['first_name'] as String?;
    if (firstName.isNotEmpty) {
      updateData['first_name'] = firstName;
    } else if (existingFirstName == null || existingFirstName.trim().isEmpty) {
      final emailPrefix = cleanEmail.split('@').first;
      updateData['first_name'] =
          emailPrefix[0].toUpperCase() + emailPrefix.substring(1);
    }

    if (lastName.isNotEmpty) updateData['last_name'] = lastName;
    if (roomLabel != null && roomLabel.isNotEmpty) {
      updateData['room_label'] = roomLabel;
    }

    await _client
        .from('profiles')
        .update(updateData)
        .eq('id', profileRow['id']);

    return InviteMemberResult.added;
  }

  /// Triggers a backend invitation email via Next.js serverless API route `/api/members/invite`.
  /// Authenticates using the caller's Supabase Access Token in the Authorization Bearer header.
  Future<bool> sendBackendInvite({
    required String cottageId,
    required String email,
    required String firstName,
    required String lastName,
    required String role,
    String? roomLabel,
  }) async {
    final token = SupabaseService.currentSession?.accessToken;
    if (token != null && token.isNotEmpty) {
      final baseUrl = const String.fromEnvironment(
        'BACKEND_URL',
        defaultValue: 'https://cottagee.me',
      );
      final url = Uri.parse('$baseUrl/api/members/invite');

      final bodyData = <String, dynamic>{
        'email': email.trim().toLowerCase(),
        'first_name': firstName,
        if (lastName.isNotEmpty) 'last_name': lastName,
        if (roomLabel != null && roomLabel.isNotEmpty) 'room_label': roomLabel,
        'role': role,
      };

      try {
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(bodyData),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          debugPrint('Next.js /api/members/invite succeeded: ${response.body}');
          return true;
        } else {
          debugPrint(
            'Next.js /api/members/invite returned error status ${response.statusCode}: ${response.body}',
          );
        }
      } catch (e) {
        debugPrint('Next.js /api/members/invite HTTP exception: $e');
      }
    } else {
      debugPrint('sendBackendInvite warning: Supabase access token is null.');
    }

    // Fallback: Try Supabase Edge Function endpoints if Next.js API route is not reachable
    final payload = {
      'email': email.trim().toLowerCase(),
      'cottage_id': cottageId,
      'first_name': firstName,
      'last_name': lastName,
      'role': role,
      'room_label': roomLabel,
    };

    final functionNames = ['send-invite', 'invite-user', 'invite'];
    for (final fnName in functionNames) {
      try {
        final res = await _client.functions.invoke(fnName, body: payload);
        if (res.status == 200 || res.status == 201) {
          debugPrint('Edge function $fnName succeeded.');
          return true;
        }
      } catch (e) {
        debugPrint('Edge function $fnName error: $e');
      }
    }

    return false;
  }
}

enum InviteMemberResult {
  added,
  alreadyInThisCottage,
  alreadyInAnotherCottage,
  needsSignup,
}
