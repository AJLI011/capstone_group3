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
    const String url = 'http://10.0.2.2:8000/api/medicines/expiring-soon/';
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

  Future<void> markAsPromo(int inventoryId, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: const Text('Mark as a promo?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text('Yes'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Add your promo marking logic here, e.g., API call if needed
    // For now, just remove it visually and show success
    setState(() {
      promoMedicines.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Transferred Successfully.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Promo Medicines')),
      body: promoMedicines.isEmpty
          ? const Center(child: Text('No promo medicines available.'))
          : ListView.builder(
              itemCount: promoMedicines.length,
              itemBuilder: (context, index) {
                final medicine = promoMedicines[index];
                final inventoryId = medicine['id'];

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 255, 245, 204), // Light yellow
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color.fromARGB(255, 255, 213, 79)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left side
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              medicine['medicine_name'] ?? 'No Name',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('${medicine['generic_name'] ?? 'N/A'}'),
                            Text('${medicine['batch_num'] ?? 'N/A'}'),
                            Text('${medicine['supplier_name'] ?? 'N/A'}'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Right side
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${medicine['quantity'] ?? '0'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            medicine['exp_date'] ?? '',
                            style: const TextStyle(color: Colors.orange),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFD600),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () => markAsPromo(inventoryId, index),
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
