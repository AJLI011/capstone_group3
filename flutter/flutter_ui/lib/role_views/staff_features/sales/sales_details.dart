import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'order_summary.dart';

class SalesDetailsPage extends StatefulWidget {
  final Map<String, dynamic> barcodeData;
  // Add a parameter to hold existing cart items
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
  late TextEditingController quantitySoldController;
  late TextEditingController freeQuantityController;

  @override
  void initState() {
    super.initState();
    inventory = widget.barcodeData;
    medicineDetails = inventory['medicine_details'] as Map<String, dynamic>? ?? {}; 
    quantitySoldController = TextEditingController();
    freeQuantityController = TextEditingController();
  }

  @override
  void dispose() {
    quantitySoldController.dispose();
    freeQuantityController.dispose();
    super.dispose();
  }

  void _proceedToCheckout() {
    final int quantitySold = int.tryParse(quantitySoldController.text) ?? 0;
    final int freeQuantity = int.tryParse(freeQuantityController.text) ?? 0;

    // Basic validation
    if (quantitySold <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity to sell.')),
      );
      return;
    }

    // Create the new item to be added to the cart
    // UPDATED: Changed key names to match what OrderSummaryPage expects
    final Map<String, dynamic> newItem = {
      'id': medicineDetails['id'],
      'name': medicineDetails['name'],
      'price': medicineDetails['price'],
      'quantity_sold': quantitySold, // Corrected key name
      'free_quantity_given': freeQuantity, // Corrected key name
      'inventory_id': inventory['id'], // Added inventory_id for processSale
    };

    // Create a new list with the old items and the new item
    final updatedCart = List<Map<String, dynamic>>.from(widget.cartItems)
      ..add(newItem);

    // Navigate to the OrderSummaryPage with the updated cart
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => OrderSummaryPage(cartItems: updatedCart),
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

    // Construct image URL from medicine.image
    final String imagePath = medicineDetails['image']?.toString() ?? '';
    final String imageUrl = imagePath.isNotEmpty ? 'http://10.0.2.2:8000$imagePath' : '';

    // Check if item is a promo
    final bool isPromo = inventory['is_promo'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Medicine Image
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

            // Non-editable fields
            _readonlyField('Medicine Name', medicineDetails['name']?.toString() ?? 'N/A'),
            _readonlyField('Generic Name', medicineDetails['generic_name']?.toString() ?? 'N/A'),
            _readonlyField('Price', '₱${medicineDetails['price']?.toString() ?? 'N/A'}'),
            _readonlyField('Available Quantity', inventory['quantity']?.toString() ?? 'N/A'),
            _readonlyField('Batch Number', inventory['batch_num']?.toString() ?? 'N/A'),

            const SizedBox(height: 30),

            // Editable fields
            _inputField('Quantity Sold', quantitySoldController, TextInputType.number),
            _inputField(
              'Promo / Free Quantity',
              freeQuantityController,
              TextInputType.number,
              enabled: isPromo,
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

  Widget _inputField(String label, TextEditingController controller, TextInputType type, {bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: type,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}