// medicine_view.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'medicine_detail_page.dart';

class Medicine {
  final int id;
  final String name;
  final String genericName;
  final String imageUrl;
  final double price;
  final String category;

  Medicine({
    required this.id,
    required this.name,
    required this.genericName,
    required this.imageUrl,
    required this.price,
    required this.category,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id'],
      name: json['name'],
      genericName: json['generic_name'] ?? '',
      imageUrl: json['image'] ?? '',
      price: double.parse(json['price']),
      category: json['category'] ?? '',
    );
  }
}

class MedicineView extends StatefulWidget {
  final int customerId;
  final String selectedCategory;
  final String searchQuery; // <--- Added this line for working search bar

  const MedicineView({
    super.key,
    required this.customerId,
    this.selectedCategory = 'all',
    this.searchQuery = '', // <--- Added this line for working search bar
  });

  @override
  State<MedicineView> createState() => _MedicineViewState();
}

class _MedicineViewState extends State<MedicineView> {
  List<Medicine> _medicines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchMedicines();
  }

  @override
  void didUpdateWidget(covariant MedicineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCategory != oldWidget.selectedCategory) {
      fetchMedicines();
    }
  }

  Future<void> fetchMedicines() async {
    setState(() {
      _isLoading = true;
    });
    
    String url = 'http://10.0.2.2:8000/api/customer/medicines/';
    if (widget.selectedCategory != 'all') {
      url += '?category=${widget.selectedCategory}';
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _medicines = data.map((json) => Medicine.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load medicines: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching medicines: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildMedicineCard(Medicine med) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MedicineDetailPage(
              medicineId: med.id,
              customerId: widget.customerId,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: med.imageUrl.isNotEmpty
                    ? Image.network(
                        med.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Image.asset('assets/placeholder.png', fit: BoxFit.cover),
                      )
                    : Image.asset('assets/placeholder.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              med.name,
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
              med.genericName,
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
              '₱${med.price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.end,
            ),
          ],
        ),
      ),
    );
  }

@override
Widget build(BuildContext context) {
  final filteredMedicines = _medicines.where((medicine) {
    final nameLower = medicine.name.toLowerCase();
    final genericNameLower = medicine.genericName.toLowerCase();
    final searchLower = widget.searchQuery.toLowerCase();

    return nameLower.contains(searchLower) || genericNameLower.contains(searchLower);
  }).toList();
    
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredMedicines.isEmpty // <-- Change `_medicines` to `filteredMedicines`
              ? Center(
                  child: Text(
                    (widget.searchQuery.isNotEmpty) // <-- This checks if a search was performed
                    ? "No medicines found for '${widget.searchQuery}'"
                    : "No medicines available for the category: ${widget.selectedCategory}",
                  ),
               )
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: GridView.builder(
                    itemCount: filteredMedicines.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.7,
                    ),
                    itemBuilder: (context, index) =>
                        _buildMedicineCard(filteredMedicines[index]),
                  ),
                ),
    );
  }
}