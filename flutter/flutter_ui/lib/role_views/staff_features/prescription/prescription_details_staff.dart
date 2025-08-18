// In your prescription_details_staff.dart file

import 'package:flutter/material.dart';

class PrescriptionDetailsStaff extends StatelessWidget {
  final Map<String, dynamic> prescription;

  const PrescriptionDetailsStaff({super.key, required this.prescription});

  @override
  Widget build(BuildContext context) {
    // Access the new combined data from the passed 'prescription' object
    final orderId = prescription['order_id'];
    final orderType = prescription['order_type'];
    final name = prescription['staff_or_customer_name'];
    final date = prescription['date_uploaded'];
    final isPwd = prescription['is_pwd'];
    final subtotal = prescription['total_amount_before_discount'];
    final discount = prescription['discount_amount'];
    final total = prescription['total_amount_after_discount'];
    final orderItems = prescription['order_items'] as List;

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

                const Text('Order Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...orderItems.map((item) {
                  // This line was updated to handle online order item names
                  // We use the top-level 'orderType' variable, which is correct.
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
                }).toList(),
                const Divider(height: 32),

                const Text('Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Subtotal: ₱$subtotal', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 4),
                Text('PWD Discount (20%): ₱$discount', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 4),
                Text('Total: ₱$total', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}