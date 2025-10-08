import 'package:flutter/material.dart';
import 'sales_details.dart'; // Make sure this path is correct

class BatchSelectionPage extends StatelessWidget {
  final List<dynamic> batches;
  final int? staffId;

  const BatchSelectionPage({
    super.key,
    required this.batches,
    this.staffId,
  });

  @override
  Widget build(BuildContext context) {
    // Find the FEFO batch (first in the list, assuming backend sorts by expiry)
    final Map<String, dynamic>? fefoBatch = batches.cast<Map<String, dynamic>?>().firstWhere(
      (batch) => batch != null && (batch['is_promo'] == false || batch['is_promo'] == 0),
      orElse: () => null,
    );
    
    // Find a promo batch
    final Map<String, dynamic>? promoBatch = batches.cast<Map<String, dynamic>?>().firstWhere(
      (batch) => batch != null && (batch['is_promo'] == true || batch['is_promo'] == 1),
      orElse: () => null,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a Batch'),
        backgroundColor: const Color(0xFF5C7C9A),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select a batch for ${fefoBatch?['name'] ?? 'this medicine'}:',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (fefoBatch != null)
              _buildBatchCard(
                context,
                'Standard Batch (FEFO)',
                'Exp: ${fefoBatch['exp_date']}',
                'Quantity: ${fefoBatch['quantity']}',
                fefoBatch,
              ),
            if (promoBatch != null)
              _buildBatchCard(
                context,
                'Promo Batch',
                'Exp: ${promoBatch['exp_date']}',
                'Quantity: ${promoBatch['quantity']}',
                promoBatch,
                isPromo: true,
              ),
            if (fefoBatch == null && promoBatch == null)
              const Center(child: Text('No batches available for this medicine.')),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchCard(
    BuildContext context,
    String title,
    String subtitle1,
    String subtitle2,
    Map<String, dynamic> batch, {
    bool isPromo = false,
  }) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isPromo ? const BorderSide(color: Colors.orange, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SalesDetailsPage(
                barcodeData: [batch], // Pass the single, selected batch
                staffId: staffId,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              Text(subtitle1),
              Text(subtitle2),
            ],
          ),
        ),
      ),
    );
  }
}