import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'order_summary.dart';

class SalesDetailsPage extends StatefulWidget {
  final Map<String, dynamic> barcodeData;
  final List<Map<String, dynamic>> cartItems;

  const SalesDetailsPage({
    super.key,
    required this.barcodeData,
    this.cartItems = const [],
  });

  @override
  State<SalesDetailsPage> createState() => _SalesDetailsPageState();
}

class _SalesDetailsPageState extends State<SalesDetailsPage> {
  late Map<String, dynamic> inventory;
  late Map<String, dynamic> medicineDetails;
  int _quantitySold = 0;
  int _freeQuantity = 0;
  bool isPromo = false;

  @override
  void initState() {
    super.initState();
    inventory = widget.barcodeData;

    print('Inventory data received: $inventory');

    medicineDetails = inventory['medicine_details'] as Map<String, dynamic>? ?? {};

    final dynamic promoFlag = inventory['is_promo'];
    isPromo = promoFlag != null &&
        (promoFlag == true ||
            promoFlag.toString().toLowerCase() == 'true' ||
            promoFlag.toString() == '1');

    print('isPromo is set to: $isPromo');
  }

  void _proceedToCheckout() {
    final int availableQuantity = inventory['quantity'] as int? ?? 0;
    final int totalItemsToDeduct = _quantitySold + _freeQuantity;

    if (_quantitySold <= 0 && _freeQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity to sell or give as promo.')),
      );
      return;
    }

    int promoLimit = 999;
    if (inventory.containsKey('promo') && inventory['promo'] is Map) {
      promoLimit = (inventory['promo']['quantity'] as int? ?? 999);
    }

    if (totalItemsToDeduct > availableQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Total items to deduct ($_quantitySold sold + $_freeQuantity promo) exceeds available stock. Only $availableQuantity available.'),
        ),
      );
      return;
    }

    if (isPromo && _freeQuantity > promoLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot give $_freeQuantity promo items. Only $promoLimit available.')),
      );
      return;
    }

    final Map<String, dynamic> newItem = {
      'id': medicineDetails['id'],
      'name': medicineDetails['name'],
      'price': medicineDetails['price'],
      'quantity_sold': _quantitySold,
      'free_quantity_given': _freeQuantity,
      'inventory_id': inventory['id'],
    };

    final updatedCart = List<Map<String, dynamic>>.from(widget.cartItems)..add(newItem);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => OrderSummaryPage(cartItems: updatedCart),
      ),
    );
  }

  Widget _buildQuantityControl(String label, int value, ValueChanged<int> onChanged,
      {bool enabled = true, required int limit}) {
    final Color buttonColor = enabled ? Colors.blue : Colors.grey.shade400;
    final Color textColor = enabled ? Colors.black87 : Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: textColor,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: enabled ? Colors.grey : Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.remove, color: buttonColor),
                  onPressed: enabled && value > 0 ? () => onChanged(value - 1) : null,
                ),
                Text(
                  value.toString(),
                  style: TextStyle(fontSize: 18, color: textColor),
                ),
                IconButton(
                  icon: Icon(Icons.add, color: buttonColor),
                  onPressed: enabled && value < limit ? () => onChanged(value + 1) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (medicineDetails.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sales Details')),
        body: const Center(
          child: Text(
            'No medicine data found for this barcode.',
            style: TextStyle(fontSize: 16, color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final String imagePath = medicineDetails['image']?.toString() ?? '';
    final String imageUrl = imagePath.isNotEmpty ? 'http://10.0.2.2:8000$imagePath' : '';
    final int totalAvailableQuantity = inventory['quantity'] as int? ?? 0;
    final int remainingQuantity = totalAvailableQuantity - _quantitySold - _freeQuantity;
    int promoLimit = (inventory['promo']?['quantity'] as int? ?? 999);
    final int promoControlLimit = isPromo ? promoLimit : 0;
    final int soldControlLimit = totalAvailableQuantity - _freeQuantity;
    final int freeControlLimit = isPromo ? promoLimit : 0;
    final int combinedFreeLimit =
        (totalAvailableQuantity - _quantitySold) > freeControlLimit ? freeControlLimit : (totalAvailableQuantity - _quantitySold);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              Center(
                child: Image.network(
                  imageUrl,
                  height: 150,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image, size: 100, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 24),
            _readonlyField('Medicine Name', medicineDetails['name']?.toString() ?? 'N/A'),
            _readonlyField('Generic Name', medicineDetails['generic_name']?.toString() ?? 'N/A'),
            _readonlyField('Price', '₱${medicineDetails['price']?.toString() ?? 'N/A'}'),
            _readonlyField('Available Quantity', remainingQuantity.toString()),
            _readonlyField('Batch Number', inventory['batch_num']?.toString() ?? 'N/A'),
            const SizedBox(height: 30),
            _buildQuantityControl(
              'Quantity Sold',
              _quantitySold,
              (newValue) {
                setState(() {
                  _quantitySold = newValue;
                });
              },
              limit: soldControlLimit,
            ),
            _buildQuantityControl(
              'Promo Quantity',
              _freeQuantity,
              (newValue) {
                setState(() {
                  _freeQuantity = newValue;
                });
              },
              enabled: isPromo,
              limit: combinedFreeLimit,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _proceedToCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text(
                'Proceed to Checkout',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readonlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 16, color: Colors.black54)),
          const Divider(height: 24),
        ],
      ),
    );
  }
}
