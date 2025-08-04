import 'package:flutter/material.dart';
import 'order_summary.dart';

class SalesDetailsPage extends StatefulWidget {
  final List<dynamic> barcodeData;
  final List<Map<String, dynamic>> cartItems;
  final int? staffId;

  const SalesDetailsPage({
    super.key,
    required this.barcodeData,
    this.cartItems = const [],
    this.staffId,
  });

  @override
  State<SalesDetailsPage> createState() => _SalesDetailsPageState();
}

class _SalesDetailsPageState extends State<SalesDetailsPage> {
  late Map<String, dynamic> inventory;
  int _quantitySold = 0;
  int _freeQuantity = 0;
  bool isPromo = false;

  @override
  void initState() {
    super.initState();
    if (widget.barcodeData.isNotEmpty) {
      inventory = widget.barcodeData.first;
      final dynamic promoFlag = inventory['is_promo'];
      isPromo = promoFlag != null &&
          (promoFlag == true ||
              promoFlag.toString().toLowerCase() == 'true' ||
              promoFlag.toString() == '1');
    }
  }

  void _proceedToCheckout() {
    if (inventory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No inventory data to process.')),
      );
      return;
    }

    final int availableQuantity = inventory['quantity'] as int? ?? 0;
    final int totalItemsToDeduct = _quantitySold + _freeQuantity;

    if (_quantitySold <= 0 && _freeQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a quantity to sell or give as promo.')),
      );
      return;
    }

    if (totalItemsToDeduct > availableQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Total items ($_quantitySold + $_freeQuantity) exceed available stock ($availableQuantity).'),
        ),
      );
      return;
    }

    if (!isPromo && _freeQuantity > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This item is not under promo. Promo quantity must be 0.')),
      );
      return;
    }

    // Now correctly read medicine_id directly from the API response
    final int? medicineId = inventory['medicine_id'] as int?;

    if (medicineId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Medicine ID not found in API response.')),
      );
      return;
    }

    final updatedCart = List<Map<String, dynamic>>.from(widget.cartItems);

    int existingItemIndex = updatedCart.indexWhere(
      (item) => item['medicine_id'] == medicineId,
    );
    
    final Map<String, dynamic> cartItemPayload = {
      'inventory_id': inventory['id'],
      'medicine_id': medicineId,
      'name': inventory['name'],
      'quantity_sold': _quantitySold,
      'free_quantity_given': _freeQuantity,
      'price': inventory['price'],
      'is_promo': isPromo,
    };
    
    if (existingItemIndex != -1) {
      final existingItem = updatedCart[existingItemIndex];
      existingItem['quantity_sold'] = (existingItem['quantity_sold'] ?? 0) + _quantitySold;
      existingItem['free_quantity_given'] = (existingItem['free_quantity_given'] ?? 0) + _freeQuantity;
    } else {
      updatedCart.add(cartItemPayload);
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OrderSummaryPage(
          cartItems: updatedCart,
          staffId: widget.staffId,
        ),
      ),
    );
  }

  Widget _readonlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 15)),
          const Divider(height: 20),
        ],
      ),
    );
  }

  Widget _buildQuantityControl(String label, int value, ValueChanged<int> onChanged,
      {bool enabled = true, required int limit}) {
    final Color buttonColor = enabled ? Colors.blue : Colors.grey.shade400;
    final Color textColor = enabled ? Colors.black87 : Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 15)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
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
                  iconSize: 20,
                ),
                Text(value.toString(), style: TextStyle(fontSize: 16, color: textColor)),
                IconButton(
                  icon: Icon(Icons.add, color: buttonColor),
                  onPressed: enabled && value < limit ? () => onChanged(value + 1) : null,
                  iconSize: 20,
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
    if (inventory.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sales Details')),
        body: const Center(child: Text('No inventory data found.')),
      );
    }
    
    final String imageUrl = inventory['image']?.toString() ?? '';
    final int totalAvailableQuantity = inventory['quantity'] as int? ?? 0;
    final int remainingQuantity = totalAvailableQuantity - _quantitySold - _freeQuantity;
    final int soldControlLimit = totalAvailableQuantity - _freeQuantity;
    final int promoControlLimit = isPromo ? (totalAvailableQuantity - _quantitySold) : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Sales Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              Center(
                child: Image.network(
                  imageUrl,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 80),
                ),
              ),
            const SizedBox(height: 16),
            _readonlyField('Medicine Name', inventory['name'] ?? 'N/A'),
            _readonlyField('Price', '₱${inventory['price'].toString()}'),
            _readonlyField('Available Quantity', remainingQuantity.toString()),
            _readonlyField('Batch Number', inventory['batch_num'] ?? 'N/A'),
            _readonlyField('Expiration Date', inventory['exp_date'] ?? 'N/A'),
            const SizedBox(height: 20),
            _buildQuantityControl('Quantity Sold', _quantitySold, (val) {
              setState(() => _quantitySold = val);
            }, limit: soldControlLimit),
            _buildQuantityControl('Promo Quantity', _freeQuantity, (val) {
              setState(() => _freeQuantity = val);
            }, enabled: isPromo, limit: promoControlLimit),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _proceedToCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 45),
              ),
              child: const Text('Proceed to Checkout', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}