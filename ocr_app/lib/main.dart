import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'receipt_review_screen.dart'; // استدعاء شاشة المراجعة
import 'settings_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'pdf_viewer_screen.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Receipt Scanner',
      theme: ThemeData(primarySwatch: Colors.teal),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _selectedImage;
  bool _isLoading = false;
  AppSettings? _settings;


  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _pickAndOpenDocument() async {
    try {
      // 1. فتح مدير الملفات
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String fileName = result.files.single.name;
        String? extension = result.files.single.extension?.toLowerCase();

        // 2. التحقق من نوع الملف
        if (extension == 'pdf') {
          // إذا كان PDF، افتحه داخل التطبيق
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PdfViewerScreen(file: file, fileName: fileName),
            ),
          );
        } else {
          // إذا كان Word أو PPT، افتحه بتطبيق الهاتف الافتراضي
          final openResult = await OpenFilex.open(file.path);
          if (openResult.type != ResultType.done) {
            _showError('لا يوجد تطبيق مثبت على هاتفك لفتح هذا النوع من الملفات.');
          }
        }
      }
    } catch (e) {
      _showError('تعذر فتح الملف: $e');
    }
  }

  Future<void> _loadSettings() async {
    final loaded = await AppSettings.load();
    if (!mounted) return;
    setState(() => _settings = loaded);
    // أول مرة: افتح الإعدادات تلقائياً
    if (!loaded.isConfigured) {
      await _openSettings();
    }
  }

  Future<void> _openSettings() async {
    final updated = await Navigator.push<AppSettings>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          initial: _settings ?? const AppSettings(apiBase: '', token: ''),
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _settings = updated);
    }
  }

  // 1. دالة المسح الضوئي (الكاميرا)
  Future<void> _scanWithScanner() async {
    try {
      final pics = await CunningDocumentScanner.getPictures(noOfPages: 1);
      if (pics == null || pics.isEmpty) return;
      await _processImage(File(pics.first));
    } catch (e) {
      debugPrint('scanner failed: $e');
      _showError('الماسح الذكي ما يشتغل على جهازك، فتحت الكاميرا العادية بدله');
      await _takePhoto();
    }
  }

  // كاميرا عادية (بديل إذا الماسح الذكي ما اشتغل)
  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
      if (image == null) return;
      await _processImage(File(image.path));
    } catch (e) {
      debugPrint('camera failed: $e');
      _showError('تعذر فتح الكاميرا');
    }
  }

  // 2. دالة اختيار صورة من المعرض
  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (image == null) return;
    await _processImage(File(image.path));
  }

  // 3. الدالة المسؤولة عن إرسال الصورة للسيرفر
  Future<void> _processImage(File file) async {
    final settings = _settings ?? await AppSettings.load();
    if (!settings.isConfigured) {
      _showError('حدد عنوان السيرفر والتوكن من الإعدادات أولاً');
      await _openSettings();
      return;
    }

    setState(() {
      _selectedImage = file;
      _isLoading = true;
    });

    try {
      final uri = Uri.parse('${settings.apiBase}/ocr');
      final request = http.MultipartRequest('POST', uri);
      request.headers['x-app-token'] = settings.token;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      // 90 ثانية: السيرفر المجاني ينام ويحتاج وقت يصحى عند أول طلب
      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 90));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        
        if (!mounted) return;
        setState(() => _isLoading = false);
        // فتح شاشة المراجعة
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(builder: (_) => ReceiptReviewScreen(data: data)),
        );

        if (result != null) {
          // هنا يمكنك حفظ النتيجة المعدلة في قاعدة بيانات
          debugPrint('البيانات المحفوظة: $result');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حفظ الإيصال بنجاح!'), backgroundColor: Colors.green),
          );
        }
      } else {
        String detail = '';
        try {
          detail = jsonDecode(utf8.decode(response.bodyBytes))['detail']?.toString() ?? '';
        } catch (_) {}
        _showError('خطأ من السيرفر (${response.statusCode}) $detail');
      }
    } on TimeoutException {
      _showError('انتهت مهلة الاتصال، السيرفر مشغول أو لسه يصحى. جرب مرة ثانية.');
    } on SocketException {
      _showError('ماكو اتصال بالإنترنت أو عنوان السيرفر غلط.');
    } catch (e) {
      _showError('حدث خطأ أثناء الاتصال: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ماسح الإيصالات', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'الإعدادات',
            onPressed: _openSettings,
          ),
          if (_selectedImage != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: () => setState(() => _selectedImage = null),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_selectedImage != null)
                Container(
                  height: 250,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.teal, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_selectedImage!, fit: BoxFit.cover),
                  ),
                ),

              // زر الماسح الضوئي الذكي
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _scanWithScanner,
                icon: const Icon(Icons.document_scanner, color: Colors.white),
                label: const Text('مسح ضوئي ذكي (اقتصاص تلقائي)', style: TextStyle(fontSize: 16, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              
              const SizedBox(height: 10),

              // زر الكاميرا العادية
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _takePhoto,
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                label: const Text('تصوير بالكاميرا', style: TextStyle(fontSize: 16, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),

              const SizedBox(height: 10),

              // زر المعرض
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _pickFromGallery,
                icon: const Icon(Icons.photo_library, color: Colors.white),
                label: const Text('اختيار من المعرض', style: TextStyle(fontSize: 16, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
                            const SizedBox(height: 10),
              // زر قارئ الملفات
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _pickAndOpenDocument,
                icon: const Icon(Icons.menu_book, color: Colors.white),
                label: const Text('قارئ الملفات (PDF, Word, PPT)', style: TextStyle(fontSize: 16, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple, // لون مميز للقارئ
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(30.0),
                  child: Center(child: CircularProgressIndicator(color: Colors.teal)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}