import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  Future<void> setPromo(int inventoryId, String startDate, String endDate) async {
    final url = Uri.parse('http://10.0.2.2:8000/api/inventory/$inventoryId/set-promo/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'start_date': startDate, 'end_date': endDate}),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promo set!')),
      );
      fetchExpiringSoonMedicines();
    } else {
      print('Failed to set promo: ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error setting promo')),
      );
    }
  }

  Future<void> removePromo(int inventoryId) async {
    final url = Uri.parse('http://10.0.2.2:8000/api/inventory/$inventoryId/remove-promo/');
    final response = await http.delete(url);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promo removed')),
      );
      fetchExpiringSoonMedicines();
    } else {
      print('Failed to remove promo: ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error removing promo')),
      );
    }
  }

  void showPromoDialog(int inventoryId) {
    DateTime? selectedStartDate;
    DateTime? selectedEndDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Set Promo Dates'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  selectedStartDate != null
                      ? 'Start: ${selectedStartDate!.toIso8601String().split('T').first}'
                      : 'Choose Start Date',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      selectedStartDate = picked;
                    });
                  }
                },
              ),
              ListTile(
                title: Text(
                  selectedEndDate != null
                      ? 'End: ${selectedEndDate!.toIso8601String().split('T').first}'
                      : 'Choose End Date',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedStartDate ?? DateTime.now(),
                    firstDate: selectedStartDate ?? DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      selectedEndDate = picked;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedStartDate != null && selectedEndDate != null) {
                  Navigator.pop(context);
                  setPromo(
                    inventoryId,
                    selectedStartDate!.toIso8601String().split('T').first,
                    selectedEndDate!.toIso8601String().split('T').first,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please choose both dates')),
                  );
                }
              },
              child: const Text('Set Promo'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Promo Medicines')),
      body: promoMedicines.isEmpty
          ? const Center(child: Text('No medicines eligible for promo.'))
          : ListView.builder(
              itemCount: promoMedicines.length,
              itemBuilder: (context, index) {
                final item = promoMedicines[index];
                final isPromo = item['is_promo'] == true || item['is_promo'] == 1;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9C4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFEE58)),
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
                              item['medicine_name'] ?? 'No Name',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('${item['generic_name'] ?? 'N/A'}'),
                            Text('Batch: ${item['batch_num'] ?? 'N/A'}'),
                            Text('Supplier: ${item['supplier_name'] ?? 'N/A'}'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Right side
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            item['quantity']?.toString() ?? '0',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Exp: ${item['exp_date'] ?? 'N/A'}',
                            style: const TextStyle(color: Colors.orange),
                          ),
                          const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: isPromo
                              ? null
                              : () {
                                  if (!isPromo) showPromoDialog(item['id']);
                                },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isPromo ? Colors.grey : Colors.yellow[700],
                                foregroundColor: isPromo ? Colors.black45 : Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text(isPromo ? 'Promo Set' : 'Promo'),
                            ),
                            if (isPromo)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: ElevatedButton(
                                  onPressed: () => removePromo(item['id']),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: const Text('Remove Promo'),
                                ),
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