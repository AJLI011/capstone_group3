// In your prescription_details_cashier.dart file

import 'package:flutter/material.dart';

class PrescriptionDetailsCashier extends StatelessWidget {
  final Map<String, dynamic> prescription;

  const PrescriptionDetailsCashier({super.key, required this.prescription});

  @override
  Widget build(BuildContext context) {
    // Access the data from the passed 'prescription' object
    final prescriptionData = prescription;
    final orderId = prescriptionData['order_id'];
    final orderType = prescriptionData['order_type'];
    final name = prescriptionData['staff_or_customer_name'];
    final date = prescriptionData['date_uploaded'];
    final subtotal = prescriptionData['total_amount_before_discount'];
    final discount = prescriptionData['discount_amount'];
    final total = prescriptionData['total_amount_after_discount'];
    final orderItems = prescriptionData['order_items'] as List;
    final existingImages = prescriptionData['images'] as List;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          orderType == 'in_store'
              ? 'In-store Order #$orderId Details'
              : 'Online Order #$orderId Details',
        ),
        backgroundColor: const Color(0xFF5C7C9A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orderType == 'in_store' ? 'Staff Details' : 'Customer Details',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  orderType == 'in_store' ? 'Staff Name: $name' : 'Customer Name: $name',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text('Date: ${date.substring(0, 10)}', style: const TextStyle(fontSize: 16)),
                const Divider(height: 32),

                // Prescription Images Section (View Only)
                const Text(
                  'Prescription Images',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // Displaying images from the backend
                if (existingImages.isNotEmpty)
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: existingImages.map((image) {
                      // Construct the full image URL.
                      final imageUrl = 'http://192.168.1.12:8000${image['image']}';
                      return GestureDetector(
                        onTap: () {
                          // Navigate to the full-screen image view on tap
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FullScreenImageView(imageUrl: imageUrl),
                            ),
                          );
                        },
                        child: Hero(
                          tag: imageUrl, // Use a unique tag for the hero animation
                          child: Container(
                            height: 100,
                            width: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: NetworkImage(imageUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  )
                else
                  const Text('No prescription images found.', style: TextStyle(fontStyle: FontStyle.italic)),

                const Divider(height: 32),

                // Order Items Section
                const Text('Order Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...orderItems.map((item) {
                  final medicineName = orderType == 'online'
                      ? item['medicine']['name']
                      : item['medicine_name'];

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(medicineName ?? 'N/A'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quantity: ${item['quantity_sold']} | Price: ₱${item['price_at_sale']}'),
                        if ((item['free_quantity_given'] ?? 0) > 0)
                          Text(
                            'Free: ${item['free_quantity_given']}',
                            style: const TextStyle(color: Colors.green),
                          ),
                      ],
                    ),
                    trailing: Text(
                      '₱${double.parse(item['quantity_sold'].toString()) * double.parse(item['price_at_sale'].toString())}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                }),
                const Divider(height: 32),

                // Summary Section
                const Text('Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Subtotal: ₱$subtotal', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 4),
                Text('PWD Discount (20%): ₱$discount', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 4),
                Text('Total: ₱$total', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// NEW WIDGET FOR FULL-SCREEN IMAGE VIEW
// =========================================================================

class FullScreenImageView extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageView({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          Navigator.pop(context); // Pop the screen when tapped
        },
        child: Center(
          child: Hero(
            tag: imageUrl, // Must match the tag on the thumbnail
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}