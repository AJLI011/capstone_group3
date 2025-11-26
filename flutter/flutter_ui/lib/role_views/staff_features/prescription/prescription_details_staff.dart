// In your prescription_details_staff.dart file

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class PrescriptionDetailsStaff extends StatefulWidget {
  final Map<String, dynamic> prescription;

  const PrescriptionDetailsStaff({super.key, required this.prescription});

  @override
  State<PrescriptionDetailsStaff> createState() => _PrescriptionDetailsStaffState();
}

class _PrescriptionDetailsStaffState extends State<PrescriptionDetailsStaff> {
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  // Function to pick images
  Future<void> _pickImages() async {
    final List<XFile> selected = await _picker.pickMultiImage();
    if (selected != null && selected.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(selected);
      });
    }
  }

  // Function to upload images to the backend
  Future<void> _uploadImages() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one image to upload.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    final prescriptionId = widget.prescription['id'];
    // Use the base URL of your backend API. Make sure to update the IP address if it's different.
    final url = Uri.parse('http://192.168.1.6:8000/api/prescriptions/$prescriptionId/upload-images/');
    var request = http.MultipartRequest('POST', url);

    // Add each selected image to the request
    for (var image in _selectedImages) {
      request.files.add(
        await http.MultipartFile.fromPath('images', image.path),
      );
    }

    try {
      final response = await request.send();
      if (response.statusCode == 201) {
        // Handle successful upload
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Images uploaded successfully!')),
        );
        
        // Pop the current screen to go back to the list of pending prescriptions.
        // This will trigger the list refresh on the previous screen.
        Navigator.pop(context);
        
      } else {
        // Handle upload failure
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload images. Status code: ${response.statusCode}')),
        );
      }
    } catch (e) {
      // Handle network or other errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access the new combined data from the passed 'prescription' object
    final prescriptionData = widget.prescription;
    final orderId = prescriptionData['order_id'];
    final orderType = prescriptionData['order_type'];
    final name = prescriptionData['staff_or_customer_name'];
    final date = prescriptionData['date_uploaded'];
    final subtotal = prescriptionData['total_amount_before_discount'];
    final discount = prescriptionData['discount_amount'];
    final total = prescriptionData['total_amount_after_discount'];
    final orderItems = prescriptionData['order_items'] as List;
    final existingImages = prescriptionData['images'] as List; // New field for existing images

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

                // Prescription Images Section
                const Text('Prescription Images', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                // Displaying existing images from the backend
                if (existingImages.isNotEmpty)
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: existingImages.map((image) {
                      // Construct the full image URL. Adjust the IP and port to your server.
                      final imageUrl = 'http://192.168.1.6:8000${image['image']}';
                      return Container(
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(imageUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                if (existingImages.isEmpty)
                  const Text('No prescription images uploaded yet.', style: TextStyle(fontStyle: FontStyle.italic)),
                
                const Divider(height: 16),

                // Section for new images to upload
                const Text('Upload New Images', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                
                // New layout with both buttons on the same row
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(Icons.add_a_photo),
                        label: const Text('Add Images'),
                      ),
                    ),
                    const SizedBox(width: 8), // Add some spacing between the buttons
                    Expanded(
                      child: _isUploading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton.icon(
                              onPressed: _uploadImages,
                              icon: const Icon(Icons.upload),
                              label: const Text('Submit Images'),
                            ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Displaying images selected by the user
                if (_selectedImages.isNotEmpty)
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: _selectedImages.map((image) {
                      return Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Container(
                            height: 100,
                            width: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: FileImage(File(image.path)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _selectedImages.remove(image);
                              });
                            },
                          ),
                        ],
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 16),
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