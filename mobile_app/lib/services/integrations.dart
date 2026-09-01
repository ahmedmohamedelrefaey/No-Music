class Integrations {
  static const revenueCatKey = String.fromEnvironment('REVENUECAT_API_KEY');
  static bool get revenueCatEnabled => revenueCatKey.isNotEmpty;
  static void track(String _) { /* compile-safe no-op until Firebase configuration is supplied */ }
}
