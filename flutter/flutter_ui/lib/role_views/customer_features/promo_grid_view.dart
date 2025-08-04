import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ===================== MODEL: PromoMedicine =====================
class PromoMedicine {
  final String name;
  final String genericName;
  final String image;
  final double price;

  PromoMedicine({
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
      name: json['name'] ?? '',
      genericName: json['generic_name'] ?? '',
      image: json['image'] ?? '',
      price: parsedPrice,
    );
  }
}

// ===================== PROMO VIEW =====================
class PromoView extends StatefulWidget {
  const PromoView({super.key});

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
        backgroundColor: const Color(0xFF003B63),
        automaticallyImplyLeading: false, // Removes the back button
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
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.65,
                        ),
                        itemBuilder: (context, index) {
                          final promo = promos[index];
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: const Color(0xFFE6F2FF),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  child: promo.image.isNotEmpty
                                      ? Image.network(
                                          promo.image,
                                          height: 120,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Image.asset(
                                              'assets/placeholder.png',
                                              height: 120,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                            );
                                          },
                                        )
                                      : Image.asset(
                                          'assets/placeholder.png',
                                          height: 120,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        promo.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 16),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        promo.genericName,
                                        style: const TextStyle(color: Colors.grey),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '₱${promo.price.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            color: Colors.green, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}