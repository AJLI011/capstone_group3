import 'package:flutter/material.dart';
import 'package:flutter_ui/role_views/customer_view.dart';
import 'cart_service.dart';
class SuccessPage extends StatelessWidget {
  const SuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 100),
              const SizedBox(height: 20),
              const Text(
                "Order Request Successfully Placed!",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                "Please head to the pharmacy on the designated place and time.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Clear the cart first
                    CartService().clearCart();

                    // Go straight to home, no cart logic needed
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => CustomerView()),
                      (route) => false,
                    );
                  },
                  child: Text("Continue"),
                ),

              ),
            ],
          ),
        ),
      ),
    );
  }
}