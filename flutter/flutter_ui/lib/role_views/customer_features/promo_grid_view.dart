import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'medicine_promo_detail_page.dart';

// Define the API_BASE constant here
const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://192.168.0.100:8000/',
);

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
  final int customerId;
  const PromoView({super.key, required this.customerId});

  @override
  State<PromoView> createState() => _PromoViewState();
}

class _PromoViewState extends State<PromoView> {
  List<PromoMedicine> promos = [];
  bool isLoading = false; // Flag to manage loading state
  bool hasMore = true; // Flag to check if there are more pages
  int page = 1; // Current page number
  String? errorMessage;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    fetchPromos();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Check if the user has scrolled to the bottom of the list
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (hasMore && !isLoading) {
        fetchPromos();
      }
    }
  }

  Future<void> fetchPromos() async {
    if (!hasMore || isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Use the API_BASE constant here and add the page query parameter
      final response = await http.get(Uri.parse('${API_BASE}api/medicine/promos/?page=$page'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> data = responseData['results'];
        
        setState(() {
          promos.addAll(data.map((item) => PromoMedicine.fromJson(item)).toList());
          // Check if there's a next page.
          hasMore = responseData['next'] != null;
          page++;
        });
      } else {
        setState(() {
          errorMessage = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to fetch promos: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // FIX: This is the crucial line to prevent the back button from appearing on a root tab screen
        automaticallyImplyLeading: false,
        title: const Text("Promos", style: TextStyle(color: Colors.white)),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF003B8D), Color(0xFF0050C8)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: errorMessage != null
          ? Center(child: Text(errorMessage!))
          : promos.isEmpty && !isLoading
              ? const Center(child: Text("No promo medicines available"))
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: GridView.builder(
                    controller: _scrollController, // Attach the scroll controller
                    itemCount: promos.length + (isLoading ? 1 : 0), // Add one for the loading indicator
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.7,
                    ),
                    itemBuilder: (context, index) {
                      // Show a loading indicator at the end of the list
                      if (index == promos.length) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final promo = promos[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PromoMedicineDetailPage(
                                medicineId: promo.id,
                                customerId: widget.customerId,
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
                                                const Icon(Icons.medication, size: 60, color: Colors.grey),
                                        )
                                      : const Icon(Icons.medication, size: 60, color: Colors.grey),
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
                                  color: Colors.orange,
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