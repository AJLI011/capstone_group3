// medicine_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'cart_service.dart';

class MedicineDetailPage extends StatefulWidget {
  final int medicineId;
  final int customerId;
  const MedicineDetailPage({super.key, required this.medicineId, required this.customerId});

  @override
  State<MedicineDetailPage> createState() => _MedicineDetailPageState();
}

class _MedicineDetailPageState extends State<MedicineDetailPage> {
  Map<String, dynamic>? medicineData;
  bool isLoading = true;
  // CHANGE: Set initial quantity to 0
  int selectedQuantity = 0; 
  
  final TextEditingController _quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Start controller text at '0'
    _quantityController.text = selectedQuantity.toString();
    fetchMedicineDetail();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }
  
  void _updateQuantity(int newQuantity, int limit) {
    // CHANGE: Minimum quantity is 0
    if (newQuantity < 0) newQuantity = 0;
    if (newQuantity > limit) newQuantity = limit;

    if (mounted) {
      setState(() {
        selectedQuantity = newQuantity;
      });
      if (_quantityController.text != newQuantity.toString()) {
        _quantityController.text = newQuantity.toString();
        _quantityController.selection = TextSelection.fromPosition(
            TextPosition(offset: _quantityController.text.length));
      }
    }
  }
  
  void _handleQuantityInput(String text, int limit) {
    int value = int.tryParse(text) ?? 0;

    // CHANGE: Allow value to be 0
    if (value < 0) { 
      value = 0;
    }
    
    if (value > limit) {
      value = limit;
      if (text.isNotEmpty && int.tryParse(text)! > limit) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot exceed the available stock of $limit.'),
          ),
        );
      }
    }
    
    _updateQuantity(value, limit);
  }

  Future<void> fetchMedicineDetail() async {
    final url = 'http://192.168.1.4:8000/api/customer/medicines/${widget.medicineId}/';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          medicineData = json.decode(response.body);
          isLoading = false;
          
          final int availableQuantity = medicineData!['quantity'] ?? 0;
          // Ensure quantity is clamped to the new limit based on API data
          _updateQuantity(selectedQuantity, availableQuantity); 
        });
      } else {
        throw Exception('Failed to load medicine detail');
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (medicineData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Failed to load medicine details')),
      );
    }

    final String priceString = '₱${double.parse(medicineData!['price'].toString()).toStringAsFixed(2)}';
    final bool prescriptionRequired = medicineData!['requires_prescription'] ?? false;
    final int availableQuantity = medicineData!['quantity'] ?? 0;
    
    final int maxLimit = availableQuantity;


    Widget imageOrPlaceholder = medicineData!['image'].isNotEmpty
        ? Image.network(
            medicineData!['image'],
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.medication, size: 100, color: Colors.grey),
          )
        : const Icon(Icons.medication, size: 100, color: Colors.grey);

    return Scaffold(
      appBar: AppBar(
        title: Text(medicineData!['name']),
        backgroundColor: const Color.fromARGB(255, 10, 84, 182),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: Colors.white,
                  height: 300,
                  alignment: Alignment.center,
                  child: imageOrPlaceholder,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicineData!['name'],
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF003B63),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        medicineData!['generic_name'] ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        medicineData!['dosage_form'] ?? 'Dosage form not specified',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            priceString,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF003B63),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: maxLimit > 0 ? Colors.green.shade500 : Colors.red,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  maxLimit > 0 ? "In Stock ($maxLimit available)" : "Out of Stock",
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (prescriptionRequired)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            border: Border.all(color: Colors.red),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "Prescription Required",
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 200),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column( 
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Quantity Selector
                  Container(
                    width: double.infinity, 
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 20),
                          // CHANGE: Check for > 0
                          onPressed: selectedQuantity > 0
                              ? () => _updateQuantity(selectedQuantity - 1, maxLimit)
                              : null,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _quantityController,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 18),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (text) => _handleQuantityInput(text, maxLimit),
                            onEditingComplete: () {
                              if (_quantityController.text.isEmpty) {
                                // Default to 0 instead of 1 if cleared
                                _updateQuantity(0, maxLimit);
                              }
                              FocusScope.of(context).unfocus();
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 20),
                          onPressed: selectedQuantity < maxLimit
                              ? () => _updateQuantity(selectedQuantity + 1, maxLimit)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Add to Cart Button
                  SizedBox( 
                    width: double.infinity, 
                    child: ElevatedButton.icon(
                      // Requires quantity > 0
                      onPressed: selectedQuantity > 0 && selectedQuantity <= maxLimit
                          ? () {
                              CartService().addToCart(
                                CartItem(
                                  id: medicineData!['id'],
                                  name: medicineData!['name'],
                                  genericName: medicineData!['generic_name'],
                                  dosageForm: medicineData!['dosage_form'] ?? "Unknown",
                                  image: medicineData!['image'],
                                  price: double.parse(medicineData!['price'].toString()),
                                  quantity: selectedQuantity,
                                  isPromo: false,
                                  availableStock: maxLimit,
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Added to cart')),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.shopping_cart),
                      label: const Text('Add to cart'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: const Color(0xFF003B63),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}