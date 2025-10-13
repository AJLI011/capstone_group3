// medicine_promo_detail_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'cart_service.dart';

// Define the API_BASE constant here
const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://192.168.1.11:8000/',
);

class PromoMedicineDetailPage extends StatefulWidget {
  final int medicineId;
  final int customerId;
  const PromoMedicineDetailPage({super.key, required this.medicineId, required this.customerId});

  @override
  State<PromoMedicineDetailPage> createState() => _PromoMedicineDetailPageState();
}

class _PromoMedicineDetailPageState extends State<PromoMedicineDetailPage> {
  Map<String, dynamic>? medicineData;
  bool isLoading = true;
  int selectedQuantity = 1;

  @override
  void initState() {
    super.initState();
    fetchMedicineDetail();
  }

  Future<void> fetchMedicineDetail() async {
    // Use the API_BASE constant here
    final url = '${API_BASE}api/medicine/promos/${widget.medicineId}/';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          medicineData = json.decode(response.body);
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load promo medicine detail');
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
        body: const Center(child: Text('Failed to load promo medicine details')),
      );
    }

    final String priceString = '₱${double.parse(medicineData!['price'].toString()).toStringAsFixed(2)}';
    final bool prescriptionRequired = medicineData!['requires_prescription'] ?? false;
    final int availableQuantity = medicineData!['quantity'] ?? 0;
    
    // Check for promo description and dates
    final String? promoDescription = medicineData!['promo_description'];
    final String? startDate = medicineData!['start_date'];
    final String? endDate = medicineData!['end_date'];

    return Scaffold(
      appBar: AppBar(
        title: Text(medicineData!['name']),
        backgroundColor: const Color.fromARGB(255, 10, 84, 182),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Scrollable Content
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image Section
                Container(
                  color: Colors.white,
                  height: 300,
                  alignment: Alignment.center,
                  child: medicineData!['image'].isNotEmpty
                      ? Image.network(
                          medicineData!['image'],
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.medication, size: 100, color: Colors.grey),
                        )
                      : const Icon(Icons.medication, size: 100, color: Colors.grey),
                ),
                // Information Section
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
                      const SizedBox(height: 4), // Add spacing for dosage form
                      Text(
                        medicineData!['dosage_form'] ?? 'Dosage form not specified',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // START OF FIX: This structure prevents the overflow
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Price and Stock Status in one Row (to be aligned to the right)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Price (Left side)
                              Text(
                                priceString,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF003B63),
                                ),
                              ),
                              // Stock Status (Right side)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: availableQuantity > 0 ? Colors.green.shade500 : Colors.red,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  availableQuantity > 0 ? "In Stock" : "Out of Stock",
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          
                          // Promo description (Below Price/Stock)
                          if (promoDescription != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                promoDescription,
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          
                          // Promo start and end dates (Below Price/Stock)
                          if (startDate != null && endDate != null)
                            Text(
                              "Promo valid from $startDate to $endDate",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                      // END OF FIX
                      
                      const SizedBox(height: 16),
                      // Prescription Required
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
                      const SizedBox(height: 200), // Placeholder to prevent bottom overlap
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Bottom fixed bar with Quantity Selector and Add to Cart button
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Quantity Selector
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 20),
                          onPressed: selectedQuantity > 1
                              ? () => setState(() => selectedQuantity--)
                              : null,
                        ),
                        Text(
                          "$selectedQuantity",
                          style: const TextStyle(fontSize: 18),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 20),
                          onPressed: (selectedQuantity * 2) < availableQuantity
                              ? () => setState(() => selectedQuantity++)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  // Add to Cart Button
                  ElevatedButton.icon(
                    onPressed: (selectedQuantity * 2) > availableQuantity
                        ? null // Disable the button if the total quantity exceeds stock
                        : () {
                            // You may want to add a final check here just in case, but the button should already be disabled.
                            CartService().addToCart(
                                CartItem(
                                  id: medicineData!['id'],
                                  name: medicineData!['name'],
                                  genericName: medicineData!['generic_name'],
                                  dosageForm: medicineData!['dosage_form'] ?? "Unknown",
                                  image: medicineData!['image'],
                                  price: double.parse(medicineData!['price'].toString()),
                                  quantity: selectedQuantity,
                                  isPromo: true,
                                  promoQuantity: selectedQuantity,
                                  availableStock: availableQuantity, // ADDED: Pass the availableQuantity
                                ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Added $selectedQuantity item(s) to cart with $selectedQuantity promo item(s)!')),
                            );
                          },
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}