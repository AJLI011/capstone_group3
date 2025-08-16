// promo_grid_view.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'medicine_promo_detail_page.dart';

// ===================== MODEL: PromoMedicine =====================
class PromoMedicine {
  final int id;
  final String name;
  final String genericName;
  final String image;
  final double price;

  PromoMedicine({
    required this.id,
    required this.name,
    required this.genericName,
    required this.image,
    required this.price,
  });

  factory PromoMedicine.fromJson(Map<String, dynamic> json) {
    final dynamic priceValue = json['price'];
    double parsedPrice;

    if (priceValue is num) {
      parsedPrice = priceValue.toDouble();
    } else if (priceValue is String) {
      parsedPrice = double.tryParse(priceValue) ?? 0.0;
    } else {
      parsedPrice = 0.0;
    }

    return PromoMedicine(
      id: json['id'],
      name: json['name'] ?? '',
      genericName: json['generic_name'] ?? '',
      image: json['image'] ?? '',
      price: parsedPrice,
    );
  }
}

// ===================== PROMO VIEW =====================
class PromoView extends StatefulWidget {
  final int customerId; // <--- ADDED: customerId
  const PromoView({super.key, required this.customerId}); // <--- ADDED: customerId to constructor

  @override
  State<PromoView> createState() => _PromoViewState();
}

class _PromoViewState extends State<PromoView> {
  List<PromoMedicine> promos = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchPromos();
  }

  Future<void> fetchPromos() async {
    try {
      final response = await http.get(Uri.parse('http://10.0.2.2:8000/api/medicine/promos/'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          promos = data.map((item) => PromoMedicine.fromJson(item)).toList();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Server error: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to fetch promos: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Promos"),
        backgroundColor: const Color.fromARGB(255, 10, 84, 182), // added color to appbar
        foregroundColor: Colors.white, //changed font color
        automaticallyImplyLeading: false, 
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : promos.isEmpty
                  ? const Center(child: Text("No promo medicines available"))
                  : Padding(
                      padding: const EdgeInsets.all(12),
                      child: GridView.builder(
                        itemCount: promos.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.7, // Adjusted to match the new style
                        ),
                        itemBuilder: (context, index) {
                          final promo = promos[index];
                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PromoMedicineDetailPage(
                                    medicineId: promo.id,
                                    customerId: widget.customerId, // <--- MODIFIED: Passed customerId
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F2FF),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: promo.image.isNotEmpty
                                          ? Image.network(
                                              promo.image,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  Image.asset('assets/placeholder.png', fit: BoxFit.cover),
                                            )
                                          : Image.asset('assets/placeholder.png', fit: BoxFit.cover),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    promo.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.start,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    promo.genericName,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.start,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₱${promo.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange, // Use a distinct color for promos
                                    ),
                                    textAlign: TextAlign.end,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}