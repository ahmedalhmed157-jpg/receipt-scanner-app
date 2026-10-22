import 'package:flutter/material.dart';

class ReceiptReviewScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const ReceiptReviewScreen({super.key, required this.data});

  @override
  State<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends State<ReceiptReviewScreen> {
  late TextEditingController _vendorController;
  late TextEditingController _dateController;
  late TextEditingController _totalController;
  List<dynamic> _items = [];
  List<dynamic> _uncertain = [];

  @override
  void initState() {
    super.initState();
    _vendorController = TextEditingController(text: widget.data['vendor'] ?? '');
    _dateController = TextEditingController(text: widget.data['date'] ?? '');
    _totalController = TextEditingController(text: widget.data['total'] ?? '');
    _items = List.from(widget.data['items'] ?? []);
    _uncertain = List.from(widget.data['uncertain'] ?? []);
  }

  @override
  void dispose() {
    _vendorController.dispose();
    _dateController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  // دالة لمعرفة ما إذا كان الحقل غير مؤكد (للتلوين)
  bool _isUncertain(String fieldName) {
    return _uncertain.contains(fieldName);
  }

  // تصميم حقل نصي مع إمكانية إظهار تحذير
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String fieldName,
    TextInputType keyboardType = TextInputType.text,
  }) {
    bool uncertain = _isUncertain(fieldName);
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderSide: BorderSide(
              color: uncertain ? Colors.orange : Colors.grey,
              width: uncertain ? 2 : 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: uncertain ? Colors.orange : Colors.grey,
              width: uncertain ? 2 : 1,
            ),
          ),
          suffixIcon: uncertain
              ? const Icon(Icons.warning_amber_rounded, color: Colors.orange)
              : null,
          helperText: uncertain ? 'الذكاء الاصطناعي غير متأكد من هذه القيمة' : null,
          helperStyle: const TextStyle(color: Colors.orange),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مراجعة الإيصال', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: () {
              // إرجاع البيانات المعدلة إلى الشاشة السابقة
              final result = {
                'vendor': _vendorController.text,
                'date': _dateController.text,
                'total': _totalController.text,
                'items': _items,
                'uncertain': _uncertain,
                'full_text': widget.data['full_text'],
              };
              Navigator.pop(context, result);
            },
            tooltip: 'حفظ',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(label: 'اسم المتجر / البائع', controller: _vendorController, fieldName: 'vendor'),
            _buildTextField(label: 'التاريخ', controller: _dateController, fieldName: 'date'),
            _buildTextField(label: 'المجموع', controller: _totalController, fieldName: 'total', keyboardType: TextInputType.number),
            
            const Divider(height: 30, thickness: 1.5),
            const Text('الأصناف:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            // عرض الأصناف
            ..._items.asMap().entries.map((entry) {
              int index = entry.key;
              Map<String, dynamic> item = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    children: [
                      TextFormField(
                        initialValue: item['name']?.toString() ?? '',
                        decoration: const InputDecoration(labelText: 'اسم الصنف'),
                        onChanged: (val) => _items[index]['name'] = val,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: item['quantity']?.toString() ?? '',
                              decoration: const InputDecoration(labelText: 'الكمية'),
                              keyboardType: TextInputType.number,
                              onChanged: (val) => _items[index]['quantity'] = val,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              initialValue: item['price']?.toString() ?? '',
                              decoration: const InputDecoration(labelText: 'السعر'),
                              keyboardType: TextInputType.number,
                              onChanged: (val) => _items[index]['price'] = val,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            
            // زر إضافة صنف جديد
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _items.add({'name': '', 'quantity': '', 'price': ''});
                });
              },
              icon: const Icon(Icons.add, color: Colors.teal),
              label: const Text('إضافة صنف جديد', style: TextStyle(color: Colors.teal)),
            ),
            
            const Divider(height: 30, thickness: 1.5),
            const Text('النص الخام:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.data['full_text'] ?? 'لا يوجد نص خام.',
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}