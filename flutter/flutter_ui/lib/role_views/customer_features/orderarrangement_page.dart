// orderarrangement_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // ADDED: Import for Provider
import 'success_page.dart';
import 'cart_service.dart';
import 'my_orders_page.dart';

class OrderArrangementPage extends StatelessWidget {
  final DateTime pickupSchedule;
  final int customerId;
  final bool isPwd; // ADDED: Now a required parameter

  const OrderArrangementPage({
    super.key,
    required this.pickupSchedule,
    required this.customerId,
    required this.isPwd, // ADDED: Require isPwd in the constructor
  });

  Future<void> _placeOrder(BuildContext context) async {
    // CORRECTION: Get the existing CartService instance from the Provider
    // instead of creating a new one.
    final cartService = Provider.of<CartService>(context, listen: false);
    final items = cartService.items;

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty!')),
      );
      return;
    }

    // FIX: Convert the local pickupSchedule to UTC before sending to the backend
    final String pickupScheduleString = pickupSchedule.toUtc().toIso8601String();

    final List<Map<String, dynamic>> orderItems = items.map((item) => {
      'medicine_id': item.id,
      'quantity_sold': item.quantity,
      'free_quantity_given': item.promoQuantity,
      'is_promo': item.isPromo,
    }).toList();

    final Map<String, dynamic> requestBody = {
      'customer_id': customerId, // Using the constructor value
      'is_pwd': isPwd, // Using the constructor value
      'items': orderItems,
      'pickup_schedule': pickupScheduleString,
    };

    print('Sending JSON body to API: ${jsonEncode(requestBody)}');

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/api/customer/online-orders/create/'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201) {
        cartService.clearCart();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SuccessPage()),
        );
      } else {
        String errorMessage = 'Failed to place order: ${response.statusCode} - ${response.reasonPhrase}';
        try {
          final Map<String, dynamic> errorBody = jsonDecode(response.body);
          if (errorBody.isNotEmpty) {
            errorMessage = 'Validation Error:\n';
            errorBody.forEach((key, value) {
              errorMessage += '$key: ${value.toString()}\n';
            });
          }
        } catch (e) {
          // If the response body is not a JSON, use the default message
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Order Arrangement"),
      backgroundColor: const Color.fromARGB(255, 10, 84, 182), // added color to appbar
      foregroundColor: Colors.white, //changed font color
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      """
By placing an order with the pharmacy, the customer agrees with the following terms:

(A) Pickup Only:
    All orders must be picked up at the pharmacy. Delivery
    services are not offered.

(B) Pickup Schedule:
    The customer agrees to collect their order on the
    selected date and time. If the order is still not collected
    on that day during pharmacy hours, it will be canceled.
    Orders scheduled outside of operating hours will also
    be canceled.

(C) Cancellation & Product Availability
    If an order is canceled due to non-pickup, the
    customer acknowledges that the pharmacy will
    not hold the product for the customer and will
    not be held accountable if the product is not
    available on their next order request.

(D) Prescription & Discount Requirement
    For medicines requiring a prescription and for
    discount, the customer must present a valid
    prescription or ID at the pharmacy during the
    scheduled pickup time. If not provided, prescription
    required items will be not released. Discounts will
    also not be applied without proof.

By pressing “I Agree” the customer confirms they have read, understood, and agree to the terms above.
                      """,
                      style: TextStyle(fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Selected Pickup Date and Time:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('MMMM d, yyyy - h:mm a').format(pickupSchedule),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _placeOrder(context),
                child: const Text("I Agree"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}