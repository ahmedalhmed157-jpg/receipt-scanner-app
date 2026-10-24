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
  List<Map<String, dynamic>> _items = [];
  List<String> _uncertain = [];

  @override
  void initState() {
    super.initState();
    _vendorController = TextEditingController(text: widget.data['vendor'] ?? '');
    _dateController = TextEditingController(text: widget.data['date'] ?? '');
    _totalController = TextEditingController(text: widget.data['total'] ?? '');
    
    if (widget.data['items'] is List) {
      _items = (widget.data['items'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (widget.data['uncertain'] is List) {
      _uncertain = (widget.data['uncertain'] as List).map((e) => e.toString()).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مراجعة الإيصال', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              final result = {
                'vendor': _vendorController.text,
                'date': _dateController.text,
                'total': _totalController.text,
                'items': _items,
              };
              Navigator.pop(context, result);
            },
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildField('اسم المتجر', _vendorController, 'vendor'),
          _buildField('التاريخ', _dateController, 'date'),
          _buildField('المجموع', _totalController, 'total'),
          const Divider(),
          const Text('الأصناف:', style: TextStyle(fontWeight: FontWeight.bold)),
          ..._items.asMap().entries.map((e) {
            int i = e.key;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: e.value['name'],
                      decoration: const InputDecoration(labelText: 'الصنف'),
                      onChanged: (v) => _items[i]['name'] = v,
                    ),
                    Row(
                      children: [
                        Expanded(child: TextFormField(initialValue: e.value['quantity'], decoration: const InputDecoration(labelText: 'الكمية'), onChanged: (v) => _items[i]['quantity'] = v)),
                        Expanded(child: TextFormField(initialValue: e.value['price'], decoration: const InputDecoration(labelText: 'السعر'), onChanged: (v) => _items[i]['price'] = v)),
                      ],
                    )
                  ],
                ),
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => setState(() => _items.add({'name':'', 'quantity':'', 'price':''})),
            icon: const Icon(Icons.add),
            label: const Text('إضافة صنف'),
          )
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, String key) {
    bool isUncertain = _uncertain.contains(key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderSide: BorderSide(color: isUncertain ? Colors.orange : Colors.grey, width: isUncertain ? 2 : 1)
          ),
          suffixIcon: isUncertain ? const Icon(Icons.warning, color: Colors.orange) : null,
        ),
      ),
    );
  }
}