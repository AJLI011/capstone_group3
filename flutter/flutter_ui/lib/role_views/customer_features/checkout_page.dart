// checkout_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'cart_service.dart';
import 'package:intl/intl.dart';
import 'orderarrangement_page.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  @override
  Widget build(BuildContext context) {
    // Use ChangeNotifierProvider to listen to CartService changes
    return ChangeNotifierProvider.value(
      value: CartService(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Check Out"),
          backgroundColor: Colors.blue,
        ),
        body: Consumer<CartService>(
          builder: (context, cartService, child) {
            final cartItems = cartService.items;

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white, // Changed background color for clarity
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              spreadRadius: 1,
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item.image,
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  Text(
                                    item.genericName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  Text(
                                    "₱${item.price.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Display Promo Quantity if applicable
                                  if (item.promoQuantity > 0)
                                    Text(
                                      "Promo: ${item.promoQuantity}",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.blue),
                                  onPressed: () {
                                    cartService.decreaseQuantity(index);
                                  },
                                ),
                                Text(
                                  "${item.quantity}",
                                  style: const TextStyle(color: Colors.black),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                                  onPressed: () {
                                    cartService.increaseQuantity(index);
                                  },
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                cartService.removeItem(index);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1565C0),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Order Summary",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Quantity", style: TextStyle(color: Colors.white)),
                          Text("${cartService.totalPaidQuantity}", style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Promo Quantity", style: TextStyle(color: Colors.white)),
                          Text("${cartService.totalPromoQuantity}", style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Order Total", style: TextStyle(color: Colors.white)),
                          Text("₱${cartService.totalPrice.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Pickup date and time selectors
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: pickDate,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900),
                              child: Text(
                                selectedDate == null
                                    ? "MM / DD / YYYY"
                                    : DateFormat('MM / dd / yyyy').format(selectedDate!),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: pickTime,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900),
                              child: Text(
                                selectedTime == null
                                    ? "HH : MM"
                                    : selectedTime!.format(context),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Note the following for pickup time:\nDaily Operations — 9:00 AM to 9:00 PM",
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (selectedDate == null || selectedTime == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Please select a scheduled pickup date and time."),
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const OrderArrangementPage()),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade400),
                          child: const Text("Place Order Request", style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> pickDate() async {
    final now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now, // Only today allowed
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        selectedTime = null; // Reset time if date changes
      });
    }
  }

  Future<void> pickTime() async {
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a pickup date first.")),
      );
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day);

    TimeOfDay startTime;
    final endTime = const TimeOfDay(hour: 21, minute: 0); // 9:00 PM

    if (selected == today) {
      final currentTime = TimeOfDay.fromDateTime(now);

      int startHour = currentTime.hour;
      int startMinute = currentTime.minute - 1;
      if (startMinute < 0) {
        startMinute = 0;
      }
      final minTimeCandidate = TimeOfDay(hour: startHour, minute: startMinute);
      final nineAm = const TimeOfDay(hour: 9, minute: 0);

      if ((minTimeCandidate.hour > nineAm.hour) ||
          (minTimeCandidate.hour == nineAm.hour && minTimeCandidate.minute > nineAm.minute)) {
        startTime = minTimeCandidate;
      } else {
        startTime = nineAm;
      }
    } else {
      startTime = const TimeOfDay(hour: 9, minute: 0);
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: startTime,
    );

    if (picked != null) {
      int pickedMinutes = picked.hour * 60 + picked.minute;
      int startMinutes = startTime.hour * 60 + startTime.minute;
      int endMinutes = endTime.hour * 60 + endTime.minute;

      if (pickedMinutes >= startMinutes && pickedMinutes <= endMinutes) {
        setState(() {
          selectedTime = picked;
        });
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Invalid Time"),
            content: Text(
              "Please select a time between "
              "${startTime.format(context)} and ${endTime.format(context)}.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    }
  }
}