import 'package:flutter/material.dart';

class PrescriptionDetailsStaff extends StatelessWidget {
  final Map<String, dynamic> order;

  const PrescriptionDetailsStaff({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    // Access all the necessary data from the passed 'order' object
    final orderId = order['order_id'];
    final staffName = order['staff_name'];
    final date = order['date_uploaded'];
    final isPwd = order['is_pwd'];
    final subtotal = order['total_amount_before_discount'];
    final discount = order['discount_amount'];
    final total = order['total_amount_after_discount'];
    final orderItems = order['order_items'] as List;

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #$orderId Details'),
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
                // Staff Details
                const Text('Staff Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Staff Name: $staffName', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 4),
                Text('Date: ${date.substring(0, 10)}', style: const TextStyle(fontSize: 16)),
                const Divider(height: 32),

                // Order Items
                const Text('Order Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...orderItems.map((item) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item['medicine_name'] ?? 'N/A'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quantity: ${item['quantity_sold']} | Price: ₱${item['price_at_sale']}'),
                        if (item['free_quantity_given'] > 0)
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
                }).toList(),
                const Divider(height: 32),

                // Computations
                const Text('Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Subtotal: ₱$subtotal', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 4),
                Text('PWD Discount (20%): ₱$discount', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 4),
                Text('Total: ₱$total', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),

                const SizedBox(height: 16),

                // TODO: Add a button to view the prescription image here.
              ],
            ),
          ),
        ),
      ),
    );
  }
}