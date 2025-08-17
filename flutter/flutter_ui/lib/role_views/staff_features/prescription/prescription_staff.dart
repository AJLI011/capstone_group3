import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class PrescriptionStaffPage extends StatefulWidget {
  const PrescriptionStaffPage({Key? key}) : super(key: key);

  @override
  State<PrescriptionStaffPage> createState() => _PrescriptionStaffPageState();
}

class _PrescriptionStaffPageState extends State<PrescriptionStaffPage> {
  bool isLoading = true;
  List<dynamic> prescriptions = [];

  @override
  void initState() {
    super.initState();
    fetchPrescriptions();
  }

  Future<void> fetchPrescriptions() async {
    setState(() => isLoading = true);
    final url = Uri.parse('http://10.0.2.2:8000/api/prescriptions/');
    final resp = await http.get(url);

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as List;
      setState(() {
        // show only those with no uploaded images
        prescriptions = data.where((p) => (p['images'] as List).isEmpty).toList();
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to fetch prescriptions")),
      );
    }
  }

  void _openDetail(Map<String, dynamic> prescription) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrescriptionDetailPage(prescription: prescription),
      ),
    );
    fetchPrescriptions(); // refresh list after returning
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pending Prescriptions")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : prescriptions.isEmpty
              ? const Center(child: Text("No pending prescriptions"))
              : ListView.builder(
                  itemCount: prescriptions.length,
                  itemBuilder: (context, index) {
                    final pres = prescriptions[index];
                    final order = pres['in_store_order_details'];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text("Order #${order?['id'] ?? 'N/A'}"),
                        subtitle: Text("Staff: ${order?['staff_name'] ?? 'N/A'}"),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _openDetail(pres),
                      ),
                    );
                  },
                ),
    );
  }
}

class PrescriptionDetailPage extends StatefulWidget {
  final Map<String, dynamic> prescription;
  const PrescriptionDetailPage({Key? key, required this.prescription})
      : super(key: key);

  @override
  State<PrescriptionDetailPage> createState() => _PrescriptionDetailPageState();
}

class _PrescriptionDetailPageState extends State<PrescriptionDetailPage> {
  bool uploading = false;

  Future<void> uploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => uploading = true);

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
          'http://10.0.2.2:8000/api/prescriptions/${widget.prescription['id']}/upload-image/'),
    );
    request.files.add(await http.MultipartFile.fromPath('image', pickedFile.path));

    final response = await request.send();
    setState(() => uploading = false);

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image uploaded successfully")),
      );
      Navigator.pop(context); // go back to list, it will refresh
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to upload image")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.prescription['in_store_order_details'];

    return Scaffold(
      appBar: AppBar(title: const Text("Prescription Detail")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Order #${order?['id'] ?? 'N/A'}",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("Staff: ${order?['staff_name'] ?? 'N/A'}"),
                    const SizedBox(height: 8),
                    const Text("Items:",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    ...List.generate(
                      (order?['items'] ?? []).length,
                      (index) {
                        final item = order['items'][index];
                        return Text(
                            "${item['medicine_name']} x${item['quantity_sold']} ₱${item['price_at_sale']}");
                      },
                    ),
                    const SizedBox(height: 8),
                    Text("Subtotal: ₱${order?['total_amount_before_discount'] ?? '0.00'}"),
                    Text("Total: ₱${order?['total_amount_after_discount'] ?? '0.00'}"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: uploading ? null : uploadImage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: uploading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("UPLOAD IMAGE",
                      style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
