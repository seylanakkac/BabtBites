// Mobil (AdMob) reklam cephesi. Web derlemesine google_mobile_ads GİRMEZ:
// koşullu export ile web → stub (no-op), mobil/masaüstü → io (gerçek AdMob).
export 'mobile_ads_stub.dart' if (dart.library.io) 'mobile_ads_io.dart';
