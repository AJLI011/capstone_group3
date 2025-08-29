import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PromoMedicinePage extends StatefulWidget {
  const PromoMedicinePage({Key? key}) : super(key: key);

  @override
  State<PromoMedicinePage> createState() => _PromoMedicinePageState();
}

class _PromoMedicinePageState extends State<PromoMedicinePage> {
  List<dynamic> promoMedicines = [];
  List<dynamic> filteredMedicines = [];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchExpiringSoonMedicines();
    searchController.addListener(filterMedicines);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void filterMedicines() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredMedicines = promoMedicines.where((item) {
        final name = item['medicine_name']?.toLowerCase() ?? '';
        final generic = item['generic_name']?.toLowerCase() ?? '';
        return name.contains(query) || generic.contains(query);
      }).toList();
    });
  }

  Future<void> fetchExpiringSoonMedicines() async {
    const String url = 'http://jallybee.pythonanywhere.com/api/medicines/expiring-soon/';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);

        // FEFO sorting by expiration date
        data.sort((a, b) => DateTime.parse(a['exp_date']).compareTo(DateTime.parse(b['exp_date'])));

        setState(() {
          promoMedicines = data;
          filteredMedicines = data;
        });
      } else {
        print('Failed to load promo medicines. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching promo medicines: $e');
    }
  }

  Future<void> setPromo(int inventoryId, String startDate, String endDate) async {
    final prefs = await SharedPreferences.getInstance();
    final staffId = prefs.getInt('staff_id');

    if (staffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff ID not found. Please log in again.')),
      );
      return;
    }

    final url = Uri.parse('http://jallybee.pythonanywhere.com/api/inventory/$inventoryId/set-promo/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'start_date': startDate,
        'end_date': endDate,
        'staff_id': staffId,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promo set!')),
      );
      fetchExpiringSoonMedicines(); // Refresh list
    } else {
      print('Failed to set promo: ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error setting promo')),
      );
    }
  }

  Future<void> removePromo(int inventoryId) async {
    final prefs = await SharedPreferences.getInstance();
    final staffId = prefs.getInt('staff_id');

    if (staffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff ID not found. Please log in again.')),
      );
      return;
    }

    final url = Uri.parse('http://jallybee.pythonanywhere.com/api/inventory/remove-promo/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'inventory_id': inventoryId,
          'staff_id': staffId,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Promo removed successfully')),
        );
        fetchExpiringSoonMedicines(); // Refresh list
      } else {
        throw Exception('Failed to remove promo: ${response.body}');
      }
    } catch (e) {
      print('Error removing promo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove promo')),
      );
    }
  }

  void showPromoDialog(int inventoryId, bool isPromoAlready) {
    if (isPromoAlready) return;

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

void showRemovePromoConfirmationDialog(int inventoryId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Removal'),
        content: const Text('Are you sure you want to remove the promo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
        ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              removePromo(inventoryId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Promo Medicines'),
        backgroundColor: const Color(0xFF5C7C9A), // Updated color
        foregroundColor: Colors.white, // Updated color for font and icon
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Search medicine...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          Expanded(
            child: filteredMedicines.isEmpty
                ? const Center(child: Text('No medicines eligible for promo.'))
                : ListView.builder(
                    itemCount: filteredMedicines.length,
                    itemBuilder: (context, index) {
                      final item = filteredMedicines[index];
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
                                  Text('${item['batch_num'] ?? 'N/A'}'),
                                  Text('${item['supplier_name'] ?? 'N/A'}'),
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
                                  '${item['exp_date'] ?? 'N/A'}',
                                  style: const TextStyle(color: Colors.orange),
                                ),
                                const SizedBox(height: 8),
                                if (!isPromo)
                                  ElevatedButton(
                                    onPressed: () => showPromoDialog(item['id'], isPromo),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.yellow[700],
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: const Text('Promo'),
                                  )
                                  // Find this section in your ListView.builder:
                                  else
                                    ElevatedButton(
                                      onPressed: () => showRemovePromoConfirmationDialog(item['id']), // Change this line
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
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}