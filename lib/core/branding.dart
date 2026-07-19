import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

const _kColorHex = 'school_branding_color';
const _kTagline = 'school_branding_tagline';
const _kLogoBase64 = 'school_branding_logo';

class SchoolBranding {
  final Color primaryColor;
  final String? tagline;
  final String? logoBase64;

  const SchoolBranding({
    required this.primaryColor,
    this.tagline,
    this.logoBase64,
  });

  static SchoolBranding defaults() => const SchoolBranding(primaryColor: Color(0xFFF97316));
}

class BrandingProvider extends ChangeNotifier {
  SchoolBranding _branding = SchoolBranding.defaults();

  Color get primaryColor => _branding.primaryColor;
  String? get tagline => _branding.tagline;
  String? get logoBase64 => _branding.logoBase64;

  BrandingProvider() {
    _restoreFromCache();
  }

  Future<void> _restoreFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final hex = prefs.getString(_kColorHex);
    if (hex == null) return;
    try {
      final color = Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
      _branding = SchoolBranding(
        primaryColor: color,
        tagline: prefs.getString(_kTagline),
        logoBase64: prefs.getString(_kLogoBase64),
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> load() async {
    try {
      final data = await ApiClient.getBranding();
      await _apply(data);
    } catch (_) {}
  }

  Future<void> _apply(Map<String, dynamic> data) async {
    final colorThemeEnabled = data['color_theme_enabled'] as bool? ?? true;
    Color color = const Color(0xFFF97316);
    String? colorHex;
    if (colorThemeEnabled && data['primary_color'] != null) {
      colorHex = data['primary_color'] as String;
      try {
        color = Color(int.parse('FF${colorHex.replaceFirst('#', '')}', radix: 16));
      } catch (_) {}
    }
    final tagline = data['tagline'] as String?;
    final logoBase64 = data['logo_base64'] as String?;

    _branding = SchoolBranding(primaryColor: color, tagline: tagline, logoBase64: logoBase64);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (colorHex != null) {
      await prefs.setString(_kColorHex, colorHex);
    } else {
      await prefs.remove(_kColorHex);
    }
    if (tagline != null) {
      await prefs.setString(_kTagline, tagline);
    } else {
      await prefs.remove(_kTagline);
    }
    if (logoBase64 != null) {
      await prefs.setString(_kLogoBase64, logoBase64);
    } else {
      await prefs.remove(_kLogoBase64);
    }
  }

  Future<void> reset() async {
    _branding = SchoolBranding.defaults();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kColorHex);
    await prefs.remove(_kTagline);
    await prefs.remove(_kLogoBase64);
  }
}
