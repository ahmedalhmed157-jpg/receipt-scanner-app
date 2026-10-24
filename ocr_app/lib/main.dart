import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'receipt_review_screen.dart';
import 'settings_screen.dart';
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
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
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

  Future<void> _loadSettings() async {
    final loaded = await AppSettings.load();
    if (!mounted) return;
    setState(() => _settings = loaded);
    if (!loaded.isConfigured) await _openSettings();
  }

  Future<void> _openSettings() async {
    final updated = await Navigator.push<AppSettings>(
      context, MaterialPageRoute(builder: (_) => SettingsScreen(initial: _settings ?? const AppSettings(apiBase: '', token: ''))),
    );
    if (updated != null && mounted) setState(() => _settings = updated);
  }

  Future<void> _scanWithScanner() async {
    try {
      final pics = await CunningDocumentScanner.getPictures(noOfPages: 1);
      if (pics != null && pics.isNotEmpty) await _processImage(File(pics.first));
    } catch (e) {
      _showError('الماسح الذكي لا يعمل، افتح الكاميرا العادية');
      await _takePhoto();
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (image != null) await _processImage(File(image.path));
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (image != null) await _processImage(File(image.path));
  }

  Future<void> _pickAndOpenDocument() async {
  try {
    // الإصدار 13: pickFiles تُستدعى مباشرة وتُرجع List<PlatformFile> مباشرة
    List<PlatformFile> files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx'],
    );

    // التحقق من أن المستخدم اختار ملفاً ولم يلغِ العملية
    if (files.isEmpty) return;
    final pickedFile = files.first;

    // التحقق من وجود مسار (قد يكون null على بعض المنصات)
    if (pickedFile.path == null) {
      _showError('لا يمكن الوصول لمسار الملف');
      return;
    }

    File file = File(pickedFile.path!);
    String fileName = pickedFile.name;
    String? extension = pickedFile.extension?.toLowerCase();

    if (extension == 'pdf') {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(file: file, fileName: fileName),
        ),
      );
    } else {
      final openResult = await OpenFilex.open(file.path);
      if (openResult.type != ResultType.done) {
        _showError('لا يوجد تطبيق لفتح هذا الملف');
      }
    }
  } catch (e) {
    _showError('تعذر فتح الملف: $e');
  }
}

  Future<void> _processImage(File file) async {
    final settings = _settings ?? await AppSettings.load();
    if (!settings.isConfigured) {
      _showError('حدد إعدادات السيرفر أولاً');
      await _openSettings();
      return;
    }

    setState(() { _selectedImage = file; _isLoading = true; });

    try {
      final uri = Uri.parse('${settings.apiBase}/ocr');
      final request = http.MultipartRequest('POST', uri);
      request.headers['x-app-token'] = settings.token;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 90));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (!mounted) return;
        setState(() => _isLoading = false);
        await Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptReviewScreen(data: data)));
      } else {
        _showError('خطأ من السيرفر (${response.statusCode})');
      }
    } catch (e) {
      _showError('حدث خطأ: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ماسح الإيصالات', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(icon: const Icon(Icons.settings, color: Colors.white), onPressed: _openSettings),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selectedImage != null)
              Container(
                height: 200, margin: const EdgeInsets.only(bottom: 20),
                child: Image.file(_selectedImage!, fit: BoxFit.cover),
              ),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _scanWithScanner,
              icon: const Icon(Icons.document_scanner, color: Colors.white),
              label: const Text('مسح ضوئي ذكي', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _takePhoto,
              icon: const Icon(Icons.camera_alt, color: Colors.white),
              label: const Text('الكاميرا العادية', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickFromGallery,
              icon: const Icon(Icons.photo_library, color: Colors.white),
              label: const Text('المعرض', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickAndOpenDocument,
              icon: const Icon(Icons.menu_book, color: Colors.white),
              label: const Text('قارئ الملفات (PDF, Word)', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            ),
            if (_isLoading) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }
}