import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the first-launch onboarding carousel has already been
/// shown, persisted locally so it appears exactly once per install (not on
/// every app open). [load] must be awaited in `main()` before [CottageApp]
/// is built, mirroring [SupabaseService]'s synchronous-after-init pattern;
/// [completed] is a [ValueNotifier] so the root widget can react the
/// instant [markComplete] runs, without a full app restart.
class OnboardingService {
  OnboardingService._();

  static const _key = 'onboarding_complete';
  static final completed = ValueNotifier<bool>(false);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    completed.value = prefs.getBool(_key) ?? false;
  }

  static Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    completed.value = true;
  }
}
