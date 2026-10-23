import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// إعدادات الاتصال بالسيرفر، تنحفظ داخل الموبايل.
class AppSettings {
  final String apiBase;
  final String token;

  const AppSettings({required this.apiBase, required this.token});

  static const _kBase = 'api_base';
  static const _kToken = 'app_token';

  // قيم اختيارية وقت البناء (--dart-define)، تنستخدم فقط إذا ما انحفظ شي
  static const _defaultBase = String.fromEnvironment('API_BASE', defaultValue: '');
  static const _defaultToken = String.fromEnvironment('APP_TOKEN', defaultValue: '');

  bool get isConfigured => apiBase.isNotEmpty && token.isNotEmpty;

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      apiBase: prefs.getString(_kBase) ?? _defaultBase,
      token: prefs.getString(_kToken) ?? _defaultToken,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBase, apiBase);
    await prefs.setString(_kToken, token);
  }

  /// ينظف العنوان: يضيف https:// إذا ناقص، ويشيل / و /ocr من الآخر
  static String normalizeBase(String input) {
    var s = input.trim();
    if (s.isEmpty) return '';
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'https://$s';
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('/ocr')) {
      s = s.substring(0, s.length - 4);
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }
}

class SettingsScreen extends StatefulWidget {
  final AppSettings initial;

  const SettingsScreen({super.key, required this.initial});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _baseCtrl;
  late final TextEditingController _tokenCtrl;
  bool _hideToken = true;
  bool _testing = false;
  bool _testOk = false;
  String? _testMessage;

  @override
  void initState() {
    super.initState();
    _baseCtrl = TextEditingController(text: widget.initial.apiBase);
    _tokenCtrl = TextEditingController(text: widget.initial.token);
  }

  @override
  void dispose() {
    _baseCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  void _setResult(bool ok, String message) {
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testOk = ok;
      _testMessage = message;
    });
  }

  Future<void> _test() async {
    final base = AppSettings.normalizeBase(_baseCtrl.text);
    final token = _tokenCtrl.text.trim();
    if (base.isEmpty || token.isEmpty) {
      _setResult(false, 'عبّي العنوان والتوكن أولاً.');
      return;
    }

    setState(() {
      _testing = true;
      _testMessage = null;
    });

    try {
      final res = await http
          .get(Uri.parse('$base/check'), headers: {'x-app-token': token})
          .timeout(const Duration(seconds: 60));

      if (res.statusCode == 200) {
        _setResult(true, 'الاتصال شغال والتوكن صحيح ✅');
      } else if (res.statusCode == 401) {
        _setResult(false, 'السيرفر شغال لكن التوكن غلط.');
      } else if (res.statusCode == 404) {
        _setResult(false,
            'السيرفر ما عنده /check. حدّث ملف main.py بالنسخة الجديدة وأعد تشغيل السيرفر.');
      } else {
        _setResult(false, 'السيرفر رد بخطأ (${res.statusCode}).');
      }
    } on TimeoutException {
      _setResult(false, 'انتهت المهلة. تأكد أن السيرفر والنفق (cloudflared) شغالين.');
    } on SocketException {
      _setResult(false, 'ما أقدر أوصل للعنوان. تأكد من العنوان ومن الإنترنت.');
    } on FormatException {
      _setResult(false, 'العنوان مكتوب بشكل غلط.');
    } catch (e) {
      _setResult(false, 'خطأ: $e');
    }
  }

  Future<void> _save() async {
    final settings = AppSettings(
      apiBase: AppSettings.normalizeBase(_baseCtrl.text),
      token: _tokenCtrl.text.trim(),
    );
    await settings.save();
    if (!mounted) return;
    Navigator.pop(context, settings);
  }

  @override
  Widget build(BuildContext context) {
    final isHttp = _baseCtrl.text.trim().startsWith('http://');

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات السيرفر', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _baseCtrl,
              keyboardType: TextInputType.url,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              autocorrect: false,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'عنوان السيرفر',
                hintText: 'https://xxxx.trycloudflare.com',
                border: const OutlineInputBorder(),
                helperText: isHttp
                    ? 'تنبيه: أندرويد يمنع عناوين http، استخدم https'
                    : 'الصق العنوان اللي طلع من cloudflared',
                helperStyle: TextStyle(color: isHttp ? Colors.orange : null),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tokenCtrl,
              obscureText: _hideToken,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'التوكن (APP_TOKEN)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_hideToken ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _hideToken = !_hideToken),
                ),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _testing ? null : _test,
              icon: _testing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering),
              label: Text(_testing ? 'جاري الاختبار...' : 'اختبار الاتصال'),
            ),
            if (_testMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _testMessage!,
                  style: TextStyle(
                    color: _testOk ? Colors.green[700] : Colors.red[700],
                    fontSize: 15,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text('حفظ', style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
