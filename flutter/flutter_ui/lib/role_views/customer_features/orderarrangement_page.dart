import 'package:flutter/material.dart';
import 'success_page.dart';
import 'cart_service.dart';

class OrderArrangementPage extends StatelessWidget {
  const OrderArrangementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Order Arrangement")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Text(
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
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ),
            ),

            // I Agree button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Clear the cart right after agreeing
                  CartService().clearCart();

                  // Then navigate to success page
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => SuccessPage()),
                  );
                },
                child: Text("I Agree"),
              ),

            ),
          ],
        ),
      ),
    );
  }
}