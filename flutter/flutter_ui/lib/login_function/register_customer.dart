import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Use dart-define to override in different environments
const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://10.0.2.2:8000',
);

class RegisterCustomer extends StatefulWidget {
  const RegisterCustomer({super.key});

  @override
  State<RegisterCustomer> createState() => _RegisterCustomerState();
}

class _RegisterCustomerState extends State<RegisterCustomer> {
  final nameController    = TextEditingController();
  final emailController    = TextEditingController();
  final passwordController = TextEditingController();
  final contactController  = TextEditingController();

  String errorMsg   = '';
  String successMsg = '';
  bool   isLoading  = false;

  Future<void> registerCustomer() async {
    setState(() {
      isLoading  = true;
      errorMsg   = '';
      successMsg = '';
    });

    // MODIFIED: Use the API_BASE constant for consistency
    final url = Uri.parse('$API_BASE/api/register/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name'        : nameController.text.trim(),
        'email'       : emailController.text.trim(),
        'password'    : passwordController.text.trim(),
        'contact_num' : contactController.text.trim(),
      }),
    );

    setState(() => isLoading = false);

    if (response.statusCode == 201) {
      setState(() {
        successMsg = 'Registered successfully! You may now log in.';
        nameController.clear();
        emailController.clear();
        passwordController.clear();
        contactController.clear();
      });
    } else {
      final data = json.decode(response.body);
      setState(() => errorMsg = data.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // MODIFIED: Styled TextField with rounded border and hint text
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              hintText: 'Full Name',
              contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30.0),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // MODIFIED: Styled TextField
          TextField(
            controller: emailController,
            decoration: InputDecoration(
              hintText: 'Email',
              contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30.0),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // MODIFIED: Styled TextField
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Password',
              contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30.0),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // MODIFIED: Styled TextField
          TextField(
            controller: contactController,
            decoration: InputDecoration(
              hintText: 'Contact Number',
              contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30.0),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // MODIFIED: Styled ElevatedButton to match login button
          ElevatedButton(
            onPressed: isLoading ? null : registerCustomer,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0),
              ),
              minimumSize: const Size.fromHeight(50),
              backgroundColor: const Color.fromRGBO(71, 102, 137, 1),
            ),
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Register',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
          ),
          if (successMsg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(successMsg, style: const TextStyle(color: Colors.green)),
            ),
          if (errorMsg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(errorMsg, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }
}