import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static const _tokenKey = 'fcm_token_registered';

  static Future<void> init() async {
    // Placeholder: actual FCM token registration requires firebase_messaging package
    // which needs google-services.json from Firebase console.
    // For now, this is a stub that will be wired in when Firebase is added.
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyRegistered = prefs.getBool(_tokenKey) ?? false;
      if (!alreadyRegistered) {
        // TODO: get FCM token via FirebaseMessaging.instance.getToken()
        // final token = await FirebaseMessaging.instance.getToken();
        // if (token != null) {
        //   final deviceId = await _getDeviceId();
        //   await ApiClient.registerPushToken(token, deviceId);
        //   await prefs.setBool(_tokenKey, true);
        // }
      }
    } catch (_) {
      // Silently fail — notifications are non-critical
    }
  }
}
