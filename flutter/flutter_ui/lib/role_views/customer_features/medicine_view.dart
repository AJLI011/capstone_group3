import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'medicine_detail_page.dart'; // Make sure you have this import

class Medicine {
  final int id;
  final String name;
  final String genericName;
  final String imageUrl;
  final double price;

  Medicine({
    required this.id,
    required this.name,
    required this.genericName,
    required this.imageUrl,
    required this.price,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id'],
      name: json['name'],
      genericName: json['generic_name'] ?? '',
      imageUrl: json['image'] ?? '',
      price: double.parse(json['price']),
    );
  }
}

class MedicineView extends StatefulWidget {
  const MedicineView({super.key});

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

  Future<void> fetchMedicines() async {
    const url = 'http://10.0.2.2:8000/api/customer/medicines/';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _medicines = data.map((json) => Medicine.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load medicines');
      }
    } catch (e) {
      debugPrint('Error fetching medicines: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildMedicineCard(Medicine med) {
    return InkWell( // Added InkWell here
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        // Navigate to the medicine detail page, passing the medicine's ID
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MedicineDetailPage(medicineId: med.id),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.white, Color.fromARGB(255, 206, 231, 249)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.3, 0.7],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: med.imageUrl.isNotEmpty
                    ? Image.network(
                        med.imageUrl,
                        height: 110,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Image.asset('assets/placeholder.png', height: 110, fit: BoxFit.cover),
                      )
                    : Image.asset('assets/placeholder.png', height: 110, fit: BoxFit.cover),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      med.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      med.genericName,
                      style: const TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '₱${med.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _medicines.isEmpty
              ? const Center(child: Text("No medicines available"))
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: GridView.builder(
                    itemCount: _medicines.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    itemBuilder: (context, index) =>
                        _buildMedicineCard(_medicines[index]),
                  ),
                ),
    );
  }
}