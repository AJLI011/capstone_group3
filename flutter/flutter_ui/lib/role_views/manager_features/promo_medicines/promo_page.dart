import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PromoMedicinePage extends StatefulWidget {
  const PromoMedicinePage({Key? key}) : super(key: key);

  @override
  State<PromoMedicinePage> createState() => _PromoMedicinePageState();
}

class _PromoMedicinePageState extends State<PromoMedicinePage> {
  List<dynamic> promoMedicines = [];

  @override
  void initState() {
    super.initState();
    fetchExpiringSoonMedicines();
  }

  Future<void> fetchExpiringSoonMedicines() async {
    final String url = 'http://10.0.2.2:8000/api/medicines/expiring-soon/';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          promoMedicines = json.decode(response.body);
        });
      } else {
        print('Failed to load promo medicines. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching promo medicines: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Promo Medicines')),
      body: promoMedicines.isEmpty
          ? const Center(child: Text('No promo medicines available'))
          : ListView.builder(
              itemCount: promoMedicines.length,
              itemBuilder: (context, index) {
                final medicine = promoMedicines[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              medicine['medicine_name'] ?? 'No Name',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('Generic: ${medicine['generic_name'] ?? 'N/A'}'),
                            Text('Batch: ${medicine['batch_num'] ?? 'N/A'}'),
                            Text('Quantity: ${medicine['quantity'] ?? '0'}'),
                            Text(
                              'Expires: ${medicine['exp_date'] ?? 'N/A'}',
                              style: const TextStyle(color: Colors.red),
                            ),
                            Text('Supplier: ${medicine['supplier_name'] ?? 'N/A'}'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              // You can add logic here to apply promo, e.g., navigate or update
                              print('Promo button tapped for ${medicine['medicine_name']}');
                            },
                            child: const Text('Promo'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
