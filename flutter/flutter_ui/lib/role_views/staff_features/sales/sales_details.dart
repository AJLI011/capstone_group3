// sales_details.dart
import 'package:flutter/material.dart';
import 'order_summary.dart';

// Enhanced Design Constants
const Color _primaryColor = Color(0xFF5C7C9A); // Dominant Blue
const Color _accentColor = Color(0xFF4CAF50); // Action Green
const Color _backgroundColor = Color(0xFFF5F7FA); // Light Background

class SalesDetailsPage extends StatefulWidget {
  final List<dynamic> barcodeData;
  // --- MODIFIED: Use the correct parameter name from BatchSelectionPage ---
  final List<Map<String, dynamic>> existingCartItems;
  final int? staffId;

  const SalesDetailsPage({
    super.key,
    required this.barcodeData,
    // --- MODIFIED: Use the correct parameter name ---
    this.existingCartItems = const [],
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
      // NOTE: Using a simple .first here is safe because BatchSelectionPage
      // passed a List containing only the single selected batch.
      inventory = widget.barcodeData.first;
      final dynamic promoFlag = inventory['is_promo'];
      isPromo = promoFlag != null &&
          (promoFlag == true ||
              promoFlag.toString().toLowerCase() == 'true' ||
              promoFlag.toString() == '1');
    } else {
      // Initialize to an empty map if no data to prevent late error
      inventory = {};
    }
  }

  // LOGIC (UNCHANGED)

  // Updated method to show a confirmation dialog before leaving the page,
  // regardless of whether there are changes.
  Future<bool> _onWillPop() async {
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Item?'),
        content: const Text('Are you sure you want to go back? This item will not be recorded.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton( // Enhanced button style for Discard
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    ) ?? false;
    return confirm;
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

    // Now correctly read medicine_id and inventory_id
    final int? medicineId = inventory['medicine_id'] as int?;
    final int? inventoryId = inventory['id'] as int?; // Assuming 'id' is the inventory ID

    if (medicineId == null || inventoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Medicine ID or Inventory ID not found in API response.')),
      );
      return;
    }

    // 1. Create a mutable copy of the existing cart
    final updatedCart = List<Map<String, dynamic>>.from(widget.existingCartItems);

    // 2. Check if this specific batch/inventory item already exists in the cart
    // It is safer to use inventory_id here because batches for the same medicine
    // might have different prices or promo flags.
    int existingItemIndex = updatedCart.indexWhere(
          (item) => item['inventory_id'] == inventoryId,
    );

    final Map<String, dynamic> cartItemPayload = {
      'inventory_id': inventoryId,
      'medicine_id': medicineId,
      'name': inventory['name'],
      'quantity_sold': _quantitySold,
      'free_quantity_given': _freeQuantity,
      'price': inventory['price'],
      'is_promo': isPromo,
    };

    if (existingItemIndex != -1) {
      // If the exact batch/inventory is already in the cart, update quantities
      final existingItem = updatedCart[existingItemIndex];
      existingItem['quantity_sold'] = (existingItem['quantity_sold'] ?? 0) + _quantitySold;
      existingItem['free_quantity_given'] = (existingItem['free_quantity_given'] ?? 0) + _freeQuantity;
    } else {
      // Add the new item to the cart
      updatedCart.add(cartItemPayload);
    }

    // --- CRITICAL FIX: Use push instead of pushReplacement ---
    // This pushes the OrderSummaryPage onto the stack and allows the calling
    // page (OrderSummaryPage's 'Add' button) to receive the result.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderSummaryPage(
          cartItems: updatedCart, // Pass the complete, updated list
          staffId: widget.staffId,
        ),
      ),
    );
  }

  // --- ENHANCED UI WIDGETS ---

  // Enhanced Read-Only Field Widget
  Widget _readonlyField(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _primaryColor.withOpacity(0.7), size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced Quantity Control Widget
  Widget _buildQuantityControl(String label, int value, ValueChanged<int> onChanged,
      {bool enabled = true, required int limit, required IconData icon}) {
    final Color buttonColor = enabled ? _primaryColor : Colors.grey.shade400;
    final Color textColor = enabled ? Colors.black87 : Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: buttonColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  fontSize: 16,
                ),
              ),
              if (!enabled)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    '(Promo Disabled)',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.red.shade400,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: enabled ? Colors.white : Colors.grey.shade100,
              border: Border.all(color: enabled ? _primaryColor.withOpacity(0.5) : Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                if (enabled)
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Decrement Button
                _QuantityControlButton(
                  icon: Icons.remove,
                  color: buttonColor,
                  onPressed: enabled && value > 0 ? () => onChanged(value - 1) : null,
                ),
                // Quantity Display
                Container(
                  width: 80,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    value.toString(),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                  ),
                ),
                // Increment Button
                _QuantityControlButton(
                  icon: Icons.add,
                  color: buttonColor,
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
    if (inventory.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Sales Details'),
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('No inventory data found.')),
      );
    }

    final String imageUrl = inventory['image']?.toString() ?? '';
    final int totalAvailableQuantity = inventory['quantity'] as int? ?? 0;
    final int remainingQuantity = totalAvailableQuantity - _quantitySold - _freeQuantity;
    final int soldControlLimit = totalAvailableQuantity - _freeQuantity;
    final int promoControlLimit = isPromo ? (totalAvailableQuantity - _quantitySold) : 0;

    // Use PopScope to handle the back button press
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) {
          return;
        }
        final bool shouldPop = await _onWillPop();
        if (shouldPop) {
          // If the user confirms 'Discard', pop this page and return nothing
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          title: const Text('Add Item to Order'),
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
          // Added custom back button to handle the confirmation dialog
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final bool shouldPop = await _onWillPop();
              if (shouldPop) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Header Card
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Image Display
                      Container(
                        height: 100,
                        width: 100,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: imageUrl.isNotEmpty
                              ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.medication, size: 50, color: _primaryColor),
                          )
                              : const Icon(Icons.medication, size: 50, color: _primaryColor),
                        ),
                      ),
                      // Medicine Name
                      Text(
                        inventory['name'] ?? 'N/A',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                      const Divider(height: 20),
                      // Price and Available Quantity (Inline)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatChip(
                            icon: Icons.attach_money,
                            label: 'Price',
                            value: '₱${inventory['price'].toString()}',
                            color: _accentColor,
                          ),
                          _StatChip(
                            icon: Icons.inventory_2_outlined,
                            label: 'Available',
                            value: remainingQuantity.toString(),
                            color: Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Batch Details Section
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Batch & Inventory Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor),
                ),
              ),
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _readonlyField('Batch Number', inventory['batch_num'] ?? 'N/A', Icons.confirmation_number_outlined),
                      _readonlyField('Expiration Date', inventory['exp_date'] ?? 'N/A', Icons.calendar_today),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Quantity Selection Section
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Select Quantities',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor),
                ),
              ),
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildQuantityControl(
                        'Quantity Sold',
                        _quantitySold,
                            (val) {
                          setState(() => _quantitySold = val);
                        },
                        limit: soldControlLimit,
                        icon: Icons.shopping_bag_outlined,
                      ),
                      _buildQuantityControl(
                        'Promo/Free Quantity',
                        _freeQuantity,
                            (val) {
                          setState(() => _freeQuantity = val);
                        },
                        enabled: isPromo,
                        limit: promoControlLimit,
                        icon: Icons.local_offer_outlined,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Submit button
              ElevatedButton.icon(
                onPressed: _proceedToCheckout,
                icon: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 24),
                label: const Text(
                  'ADD TO ORDER',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 8,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper widget for quantity control buttons
class _QuantityControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _QuantityControlButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      color: color,
      iconSize: 28,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(50, 50),
      ),
    );
  }
}

// Helper widget for stat chips
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}