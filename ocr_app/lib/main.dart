import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'receipt_review_screen.dart'; // استدعاء شاشة المراجعة

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

  // 1. دالة المسح الضوئي (الكاميرا)
  Future<void> _scanWithScanner() async {
    try {
      final pics = await CunningDocumentScanner.getPictures(noOfPages: 1);
      if (pics == null || pics.isEmpty) return;
      _processImage(File(pics.first));
    } catch (e) {
      _showError('حدث خطأ في الماسح: $e');
    }
  }

  // 2. دالة اختيار صورة من المعرض
  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (image == null) return;
    _processImage(File(image.path));
  }

  // 3. الدالة المسؤولة عن إرسال الصورة للسيرفر
  Future<void> _processImage(File file) async {
    setState(() {
      _selectedImage = file;
      _isLoading = true;
    });

    try {
      // ⚠️ ضع عنوان IP الخاص بجهاز الكمبيوتر هنا
      final uri = Uri.parse('http://192.168.0.109:8000/ocr');       
      var request = http.MultipartRequest('POST', uri);
      
      // ⚠️ ضع نفس التوكن الذي شغلت به السيرفر
      request.headers['x-app-token'] = 'my_secret_token_123'; 
      
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      var response = await http.Response.fromStream(streamedResponse);

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
        _showError('خطأ من السيرفر (${response.statusCode})');
      }
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