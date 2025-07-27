import 'package:flutter/material.dart';
import 'models/total_quantity.dart';
import 'models/inventory_api_service.dart';
import 'inventory_detail_screen.dart';

class InventoryGridScreen extends StatefulWidget {
  const InventoryGridScreen({super.key});

  @override
  State<InventoryGridScreen> createState() => _InventoryGridScreenState();
}

class _InventoryGridScreenState extends State<InventoryGridScreen> {
  List<TotalQuantity> _items = [];
  String _selectedCategory = '';
  bool _sortAZ = true;

  final List<Map<String, String>> _categoryChoices = [
    {'value': '', 'label': 'Categories'},
    {'value': 'analgesics', 'label': 'Analgesics'},
    {'value': 'antibiotics', 'label': 'Antibiotics'},
    {'value': 'antivirals', 'label': 'Antivirals'},
    {'value': 'antihypertensives', 'label': 'Antihypertensives'},
    {'value': 'antidiabetics', 'label': 'Antidiabetics'},
    {'value': 'gastrointestinal_medicines', 'label': 'Gastrointestinal Medicines'},
    {'value': 'antihistamines', 'label': 'Antihistamines'},
    {'value': 'cough_and_cold_medicines', 'label': 'Cough and Cold Medicines'},
    {'value': 'vitamins_and_supplements', 'label': 'Vitamins and Supplements'},
    {'value': 'cardiovascular_medicines', 'label': 'Cardiovascular Medicines'},
    {'value': 'anti_asthma_and_respiratory_medicines', 'label': 'Anti-asthma and Respiratory Medicines'},
    {'value': 'antimalarials', 'label': 'Antimalarials'},
    {'value': 'antiparasitics', 'label': 'Antiparasitics'},
  ];

  @override
  void initState() {
    super.initState();
    loadInventory();
  }

  Future<void> loadInventory() async {
    try {
      final fetchedItems = await InventoryApiService.fetchInventoryItems();
      setState(() => _items = fetchedItems);
    } catch (e) {
      print("Error loading inventory: $e");
    }
  }

  List<TotalQuantity> get _filteredItems {
    final filtered = _items.where((item) {
      return _selectedCategory.isEmpty || item.category == _selectedCategory;
    }).toList();

    filtered.sort((a, b) =>
        _sortAZ ? a.name.compareTo(b.name) : b.name.compareTo(a.name));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        backgroundColor: const Color(0xFF396AAB),
        actions: [
          IconButton(
            icon: Icon(_sortAZ ? Icons.sort_by_alpha : Icons.sort),
            onPressed: () {
              setState(() {
                _sortAZ = !_sortAZ;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    isDense: true,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: _categoryChoices.map((choice) {
                      return DropdownMenuItem<String>(
                        value: choice['value'],
                        child: Text(choice['label']!),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value ?? '';
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Navigate to promo screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF396AAB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  child: const Text('Promo'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];

                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        elevation: 2,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InventoryDetailScreen(item: item),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item.image.isNotEmpty)
                                  Center(
                                    child: Image.network(
                                      item.image,
                                      height: 60,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.image_not_supported, size: 48),
                                    ),
                                  )
                                else
                                  const Center(
                                    child: Icon(Icons.medication, size: 48),
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  item.genericName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.name,
                                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                                const Spacer(),
                                Text(
                                  "Qty: ${item.totalQuantity}",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
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
