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
  late TextEditingController _currencyController;
  late TextEditingController _totalController;
  List<Map<String, dynamic>> _items = [];
  List<String> _uncertain = [];

  @override
  void initState() {
    super.initState();
    _vendorController = TextEditingController(text: _str(widget.data['vendor']));
    _dateController = TextEditingController(text: _str(widget.data['date']));
    _currencyController = TextEditingController(text: _str(widget.data['currency']));
    _totalController = TextEditingController(text: _str(widget.data['total']));

    // تحويل آمن: حتى لو السيرفر رجّع شي غريب ما ينهار التطبيق
    final rawItems = widget.data['items'];
    if (rawItems is List) {
      _items = rawItems.whereType<Map>().map((e) {
        return <String, dynamic>{
          'name': _str(e['name']),
          'quantity': _str(e['quantity']),
          'price': _str(e['price']),
        };
      }).toList();
    }

    final rawUncertain = widget.data['uncertain'];
    if (rawUncertain is List) {
      _uncertain = rawUncertain.map((e) => e.toString()).toList();
    }
  }

  @override
  void dispose() {
    _vendorController.dispose();
    _dateController.dispose();
    _currencyController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  String _str(dynamic v) => v == null ? '' : v.toString();

  bool _isUncertain(String fieldName) => _uncertain.contains(fieldName);

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String fieldName,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final uncertain = _isUncertain(fieldName);
    final borderColor = uncertain ? Colors.orange : Colors.grey;
    final borderWidth = uncertain ? 2.0 : 1.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderSide: BorderSide(color: borderColor, width: borderWidth),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: borderColor, width: borderWidth),
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
              final result = <String, dynamic>{
                'vendor': _vendorController.text,
                'date': _dateController.text,
                'currency': _currencyController.text,
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
            _buildTextField(label: 'العملة', controller: _currencyController, fieldName: 'currency'),
            _buildTextField(
              label: 'المجموع',
              controller: _totalController,
              fieldName: 'total',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),

            const Divider(height: 30, thickness: 1.5),
            const Text('الأصناف:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            for (int index = 0; index < _items.length; index++)
              _buildItemCard(index),

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
              child: SelectableText(
                _str(widget.data['full_text']).isEmpty
                    ? 'لا يوجد نص خام.'
                    : _str(widget.data['full_text']),
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    final uncertain = _isUncertain('items.$index');
    return Card(
      // ObjectKey: حتى لو انحذف صنف، كل بطاقة تحافظ على قيمتها الصحيحة
      key: ObjectKey(item),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: uncertain
            ? const BorderSide(color: Colors.orange, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            if (uncertain)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                    SizedBox(width: 6),
                    Text('الذكاء الاصطناعي غير متأكد من هذا الصنف',
                        style: TextStyle(color: Colors.orange, fontSize: 12)),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _str(item['name']),
                    decoration: const InputDecoration(labelText: 'اسم الصنف'),
                    onChanged: (val) => item['name'] = val,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'حذف الصنف',
                  onPressed: () => setState(() => _items.removeAt(index)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _str(item['quantity']),
                    decoration: const InputDecoration(labelText: 'الكمية'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (val) => item['quantity'] = val,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: _str(item['price']),
                    decoration: const InputDecoration(labelText: 'السعر'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (val) => item['price'] = val,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
