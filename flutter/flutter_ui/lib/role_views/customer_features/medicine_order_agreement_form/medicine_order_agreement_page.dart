import 'package:flutter/material.dart';

class MedicineOrderAgreementPage extends StatelessWidget {
  const MedicineOrderAgreementPage({super.key});

  // Helper function to create a consistently formatted term section
  Widget _buildTermSection(String title, String content, {bool isLast = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title (e.g., (A) Pickup Only:)
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold, // Make the title stand out
            height: 1.5,
          ),
        ),
        const SizedBox(height: 4), // Small space after the title
        // Content
        Text(
          content,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
          ),
        ),
        // Add a vertical space between sections, but not after the last one
        if (!isLast) const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Medicine Order Agreement"),
        backgroundColor: const Color.fromARGB(255, 10, 84, 182),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'By placing an order with the pharmacy, the customer agrees with the following terms:',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 16),
              
              _buildTermSection(
                '(A) Pickup Only:',
                'All orders must be picked up at the pharmacy. Delivery services are not offered.',
              ),

              _buildTermSection(
                '(B) Pickup Schedule:',
                'The customer agrees to collect their order on the selected date and time. If the order is still not collected on that day during pharmacy hours, it will be canceled. Orders scheduled outside of operating hours will also be canceled.',
              ),

              _buildTermSection(
                '(C) Cancellation & Product Availability:',
                'If an order is canceled due to non-pickup, the customer acknowledges that the pharmacy will not hold the product for the customer and will not be held accountable if the product is not available on their next order request.',
              ),

              _buildTermSection(
                '(D) Prescription & Discount Requirement:',
                'For medicines requiring a prescription and for discount, the customer must present a valid prescription or ID at the pharmacy during the scheduled pickup time. If not provided, prescription required items will be not released. Discounts will also not be applied without proof.',
                isLast: true, // Mark this as the last term section
              ),

              const SizedBox(height: 24),
              
              // Final confirmation centered text
              Align(
                alignment: Alignment.center,
                child: const Text(
                  'By pressing "I Agree," the customer confirms they have read, understood, and agree to the terms above.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}