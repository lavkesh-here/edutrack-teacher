import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

const _kAdminColorHex  = 'school_branding_color';
const _kUserColorHex   = 'school_branding_user_color'; // survives admin changes
const _kTagline        = 'school_branding_tagline';
const _kLogoBase64     = 'school_branding_logo';

// Colour presets shown in the in-app picker.
const kBrandingPresets = [
  Color(0xFFF97316), // Orange  (teacher default)
  Color(0xFF14B8A6), // Teal
  Color(0xFF3B82F6), // Blue
  Color(0xFF6366F1), // Indigo
  Color(0xFF8B5CF6), // Violet
  Color(0xFF22C55E), // Green
  Color(0xFFF43F5E), // Rose
  Color(0xFFF59E0B), // Amber
  Color(0xFF0EA5E9), // Sky
];

class SchoolBranding {
  final Color primaryColor;
  final String? tagline;
  final String? logoBase64;

  const SchoolBranding({
    required this.primaryColor,
    this.tagline,
    this.logoBase64,
  });

  static SchoolBranding defaults() =>
      const SchoolBranding(primaryColor: Color(0xFFF97316));
}

class BrandingProvider extends ChangeNotifier {
  // Admin color fetched from server and cached locally.
  Color _adminColor = const Color(0xFFF97316);
  // User's personal choice — local-only, never overwritten by server.
  Color? _userOverrideColor;

  String? _tagline;
  String? _logoBase64;

  /// The colour that should be used everywhere in the UI.
  Color get primaryColor => _userOverrideColor ?? _adminColor;

  /// The raw admin colour (shown as "school default" in the picker).
  Color get adminColor => _adminColor;

  /// True when the user has picked their own colour.
  bool get hasUserOverride => _userOverrideColor != null;

  String? get tagline  => _tagline;
  String? get logoBase64 => _logoBase64;

  BrandingProvider() {
    _restoreFromCache();
  }

  // ── Restore on startup ───────────────────────────────────────────────────────

  Future<void> _restoreFromCache() async {
    final prefs = await SharedPreferences.getInstance();

    final adminHex = prefs.getString(_kAdminColorHex);
    if (adminHex != null) {
      try {
        _adminColor =
            Color(int.parse('FF${adminHex.replaceFirst('#', '')}', radix: 16));
      } catch (_) {}
    }

    final userHex = prefs.getString(_kUserColorHex);
    if (userHex != null) {
      try {
        _userOverrideColor =
            Color(int.parse('FF${userHex.replaceFirst('#', '')}', radix: 16));
      } catch (_) {}
    }

    _tagline    = prefs.getString(_kTagline);
    _logoBase64 = prefs.getString(_kLogoBase64);
    notifyListeners();
  }

  // ── Load from server ─────────────────────────────────────────────────────────

  Future<void> load() async {
    try {
      final data = await ApiClient.getBranding();
      await _applyAdmin(data);
    } catch (_) {}
  }

  Future<void> _applyAdmin(Map<String, dynamic> data) async {
    final colorThemeEnabled = data['color_theme_enabled'] as bool? ?? true;
    Color color = const Color(0xFFF97316);
    String? colorHex;

    if (colorThemeEnabled && data['primary_color'] != null) {
      colorHex = data['primary_color'] as String;
      try {
        color =
            Color(int.parse('FF${colorHex.replaceFirst('#', '')}', radix: 16));
      } catch (_) {}
    }

    _adminColor = color;
    _tagline    = data['tagline'] as String?;
    _logoBase64 = data['logo_base64'] as String?;
    // NOTE: _userOverrideColor is intentionally left untouched here.
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (colorHex != null) {
      await prefs.setString(_kAdminColorHex, colorHex);
    } else {
      await prefs.remove(_kAdminColorHex);
    }
    if (_tagline != null) {
      await prefs.setString(_kTagline, _tagline!);
    } else {
      await prefs.remove(_kTagline);
    }
    if (_logoBase64 != null) {
      await prefs.setString(_kLogoBase64, _logoBase64!);
    } else {
      await prefs.remove(_kLogoBase64);
    }
  }

  // ── User override ────────────────────────────────────────────────────────────

  Future<void> setUserOverride(Color color) async {
    _userOverrideColor = color;
    notifyListeners();
    final hex = '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserColorHex, hex);
  }

  Future<void> clearUserOverride() async {
    _userOverrideColor = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserColorHex);
  }

  // ── Full reset (on logout) ───────────────────────────────────────────────────

  Future<void> reset() async {
    _adminColor        = const Color(0xFFF97316);
    _userOverrideColor = null;
    _tagline           = null;
    _logoBase64        = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    for (final k in [_kAdminColorHex, _kUserColorHex, _kTagline, _kLogoBase64]) {
      await prefs.remove(k);
    }
  }
}
