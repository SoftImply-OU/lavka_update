import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// What the app knows about its own version and Lavka's latest build.
@immutable
class LavkaUpdateStatus {
  const LavkaUpdateStatus({
    required this.versionName,
    required this.versionCode,
    this.latestVersionName,
    this.latestVersionCode,
    this.updateAvailable = false,
    this.pageUrl,
  });

  /// This build, e.g. `1.0.0` and `45`.
  final String versionName;
  final int versionCode;

  /// Lavka's newest build; null until a check has answered.
  final String? latestVersionName;
  final int? latestVersionCode;

  final bool updateAvailable;

  /// The app's page in Lavka, where the user installs the update.
  final String? pageUrl;

  /// `1.0.47` when the version already ends in the build number (CI builds
  /// `major.minor.<build>`), otherwise `1.0.0 (45)`.
  String get label => versionLabel(versionName, versionCode);
  String? get latestLabel =>
      latestVersionCode == null ? null : versionLabel(latestVersionName ?? '$latestVersionCode', latestVersionCode!);
}

/// `1.0.47`, or `1.0.0 (45)` for builds whose name doesn't carry the build
/// number. Kept in step with Lavka's `versionLabel` (src/lib/format.ts).
String versionLabel(String name, int code) =>
    name.split('.').last == '$code' ? name : '$name ($code)';

/// Talks to Lavka's public `/api/updates/<appId>` endpoint. It sends this
/// build's version, the signed-in user's email (if set) and a random install
/// id, and gets back the latest version numbers. Nothing else leaves the app.
class LavkaUpdate {
  LavkaUpdate._();

  static String? _appId;
  static String _baseUrl = 'https://lavka.softimply.tech';
  static String? _email;
  static Duration _minInterval = const Duration(hours: 1);
  static DateTime? _lastCheck;
  static Future<LavkaUpdateStatus?>? _inFlight;
  static bool _identityChanged = false;

  /// Test hooks: pretend to be Android, and replace the HTTP call.
  @visibleForTesting
  static bool? debugIsAndroid;
  @visibleForTesting
  static Future<Map<String, dynamic>> Function(String url, Map<String, Object?> body)? debugPost;

  static bool get _isAndroid => debugIsAndroid ?? (!kIsWeb && Platform.isAndroid);

  /// The latest known status; widgets rebuild from it. Null until the app's
  /// own version has been read.
  static final ValueNotifier<LavkaUpdateStatus?> status = ValueNotifier(null);

  /// Call once, before `runApp`. [appId] is the app's id in Lavka
  /// (`potik`, `soft-hr`, ...).
  static void configure({
    required String appId,
    String baseUrl = 'https://lavka.softimply.tech',
    Duration minInterval = const Duration(hours: 1),
  }) {
    _appId = appId;
    _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
    _minInterval = minInterval;
  }

  /// Who's using the app, so Lavka can show who runs which build. Call after
  /// sign-in, and with null after sign-out. Reports the new identity right
  /// away, bypassing the throttle.
  static void setUser(String? email) {
    final next = (email == null || email.trim().isEmpty) ? null : email.trim();
    if (next == _email) return;
    _email = next;
    if (_inFlight != null) {
      // A check started before sign-in finished (the usual cold start) and
      // may already have sent its body without the email. Report again as
      // soon as it completes instead of folding into it.
      _identityChanged = true;
    } else {
      unawaited(check(force: true));
    }
  }

  /// Asks Lavka whether a newer build exists. Throttled to [minInterval]
  /// unless [force]; never throws (an offline phone just keeps the old
  /// status). Only Android builds are distributed through Lavka, so on other
  /// platforms this only reads the local version.
  static Future<LavkaUpdateStatus?> check({bool force = false}) {
    return _inFlight ??= _check(force).whenComplete(() {
      _inFlight = null;
      if (_identityChanged) {
        _identityChanged = false;
        unawaited(check(force: true));
      }
    });
  }

  static Future<LavkaUpdateStatus?> _check(bool force) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final code = int.tryParse(info.buildNumber) ?? 0;
      final local = status.value;
      if (local == null || local.versionCode != code) {
        status.value = LavkaUpdateStatus(versionName: info.version, versionCode: code);
      }

      final appId = _appId;
      if (appId == null || !_isAndroid) return status.value;
      final now = DateTime.now();
      if (!force && _lastCheck != null && now.difference(_lastCheck!) < _minInterval) {
        return status.value;
      }
      _lastCheck = now;

      final body = await _post('$_baseUrl/api/updates/$appId', {
        'versionCode': code,
        'versionName': info.version,
        if (_email != null) 'email': _email,
        'device': await _installId(),
      });
      final latest = body['latest'] as Map<String, dynamic>?;
      status.value = LavkaUpdateStatus(
        versionName: info.version,
        versionCode: code,
        latestVersionName: latest?['versionName'] as String?,
        latestVersionCode: (latest?['versionCode'] as num?)?.toInt(),
        updateAvailable: body['updateAvailable'] == true,
        pageUrl: body['pageUrl'] as String?,
      );
    } catch (e) {
      debugPrint('lavka_update: check failed: $e');
    }
    return status.value;
  }

  /// Opens the app's Lavka page in the browser, where the user signs in and
  /// taps Install.
  static Future<void> openStore() async {
    final url = status.value?.pageUrl ?? (_appId == null ? _baseUrl : '$_baseUrl/apps/$_appId');
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  static Future<Map<String, dynamic>> _post(String url, Map<String, Object?> json) async {
    final fake = debugPost;
    if (fake != null) return fake(url, json);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.postUrl(Uri.parse(url));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(json));
      final res = await req.close().timeout(const Duration(seconds: 10));
      final text = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}', uri: Uri.parse(url));
      return jsonDecode(text) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  /// A random id per install, so a phone that hasn't signed in yet still
  /// counts once. Not tied to the hardware; reinstalling makes a new one.
  static Future<String> _installId() async {
    const key = 'lavka_update.install_id';
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(key);
    if (id == null) {
      final r = Random.secure();
      id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      await prefs.setString(key, id);
    }
    return id;
  }

  @visibleForTesting
  static void resetForTest() {
    _appId = null;
    _email = null;
    _lastCheck = null;
    _inFlight = null;
    _identityChanged = false;
    debugIsAndroid = null;
    debugPost = null;
    status.value = null;
  }
}
