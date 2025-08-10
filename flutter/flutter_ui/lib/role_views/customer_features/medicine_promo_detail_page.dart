// promo_medicine_detail_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'cart_service.dart'; // your existing service


class PromoMedicineDetailPage extends StatefulWidget {
  final int medicineId;
  const PromoMedicineDetailPage({super.key, required this.medicineId});

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
    final url = 'http://10.0.2.2:8000/api/medicine/promos/${widget.medicineId}/';
    // Use your actual IP or localhost as needed

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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (medicineData == null) {
      return const Scaffold(body: Center(child: Text('Failed to load medicine')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(medicineData!['name']),
      ),
      body: Column(
        children: [
          // Top Half: Image
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              color: Colors.white,
              child: medicineData!['image'] != ""
                  ? Image.network(
                      medicineData!['image'],
                      fit: BoxFit.contain,
                    )
                  : Image.asset('assets/placeholder.png', fit: BoxFit.contain),
            ),
          ),

          // Bottom Half: Info
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${medicineData!['name']} (${medicineData!['generic_name']})",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      "₱${medicineData!['price']}",
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Prescription tag
                    if (medicineData!['requires_prescription'])
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "Prescription Required",
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),

                    const SizedBox(height: 8),

                    // Stock status and Quantity
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          decoration: BoxDecoration(
                            color: medicineData!['stock_status'] == "In Stock" ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            medicineData!['stock_status'],
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text("Quantity: ${medicineData!['quantity']}"),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Promo start and end date display
                    if (medicineData!['start_date'] != null && medicineData!['end_date'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "Promo: Buy 1 Take 1!",
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Quantity selector
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: selectedQuantity > 1
                              ? () => setState(() => selectedQuantity--)
                              : null,
                        ),
                        Text(
                          "$selectedQuantity",
                          style: const TextStyle(fontSize: 18),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: selectedQuantity < medicineData!['quantity']
                              ? () => setState(() => selectedQuantity++)
                              : null,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Add to cart button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: medicineData!['quantity'] > 0
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
                                    isPromo: true, // This is the key line
                                  ),
                                );

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Added to cart')),
                                );
                              }
                            : null,
                        child: const Text("Add to Cart"),
                      ),
                    ),

                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}