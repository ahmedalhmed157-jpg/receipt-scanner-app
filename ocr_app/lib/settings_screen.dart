import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final String apiBase;
  final String token;
  const AppSettings({required this.apiBase, required this.token});

  static const _kBase = 'api_base';
  static const _kToken = 'app_token';

  bool get isConfigured => apiBase.isNotEmpty && token.isNotEmpty;

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      apiBase: prefs.getString(_kBase) ?? '',
      token: prefs.getString(_kToken) ?? '',
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBase, apiBase);
    await prefs.setString(_kToken, token);
  }

  static String normalizeBase(String input) {
    var s = input.trim();
    if (s.isEmpty) return '';
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'http://$s'; // نستخدم http للسيرفر المحلي
    }
    while (s.endsWith('/')) { s = s.substring(0, s.length - 1); }
    if (s.endsWith('/ocr')) { s = s.substring(0, s.length - 4); }
    while (s.endsWith('/')) { s = s.substring(0, s.length - 1); }
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
  bool _testing = false;
  bool _testOk = false;
  String? _testMessage;

  @override
  void initState() {
    super.initState();
    _baseCtrl = TextEditingController(text: widget.initial.apiBase);
    _tokenCtrl = TextEditingController(text: widget.initial.token);
  }

  Future<void> _test() async {
    final base = AppSettings.normalizeBase(_baseCtrl.text);
    final token = _tokenCtrl.text.trim();
    if (base.isEmpty || token.isEmpty) {
      setState(() { _testOk = false; _testMessage = 'عبّي العنوان والتوكن أولاً.'; });
      return;
    }
    setState(() { _testing = true; _testMessage = null; });
    try {
      final res = await http.get(Uri.parse('$base/check'), headers: {'x-app-token': token}).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        setState(() { _testOk = true; _testMessage = 'الاتصال شغال والتوكن صحيح ✅'; });
      } else if (res.statusCode == 401) {
        setState(() { _testOk = false; _testMessage = 'السيرفر شغال لكن التوكن غلط.'; });
      } else {
        setState(() { _testOk = false; _testMessage = 'خطأ من السيرفر (${res.statusCode})'; });
      }
    } catch (e) {
      setState(() { _testOk = false; _testMessage = 'فشل الاتصال. تأكد من الـ IP والواي فاي.'; });
    } finally {
      setState(() { _testing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات', style: TextStyle(color: Colors.white)), backgroundColor: Colors.teal),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _baseCtrl,
              decoration: const InputDecoration(labelText: 'عنوان السيرفر (IP)', hintText: 'http://192.168.1.x:8000', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tokenCtrl,
              decoration: const InputDecoration(labelText: 'التوكن', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _testing ? null : _test,
              child: Text(_testing ? 'جاري الاختبار...' : 'اختبار الاتصال'),
            ),
            if (_testMessage != null) ...[
              const SizedBox(height: 10),
              Text(_testMessage!, style: TextStyle(color: _testOk ? Colors.green : Colors.red)),
            ],
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: Colors.teal),
              onPressed: () async {
                final s = AppSettings(apiBase: AppSettings.normalizeBase(_baseCtrl.text), token: _tokenCtrl.text.trim());
                await s.save();
                if (context.mounted) Navigator.pop(context, s);
              },
              child: const Text('حفظ', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}