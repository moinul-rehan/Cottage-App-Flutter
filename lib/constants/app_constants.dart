/// App-wide constants that don't belong to theming. Mirrors the template's
/// constants/app_constants.dart.
class AppConstants {
  AppConstants._();

  static const appName = 'Cottage';

  /// Shown on the splash screen. Keep in sync with pubspec.yaml's
  /// `version:` line (no package_info_plus dependency, to avoid pulling in
  /// a new package just for this).
  static const version = '1.0.0';
}
