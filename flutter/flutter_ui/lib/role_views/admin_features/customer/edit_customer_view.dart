import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

//import 'package:shared_preferences/shared_preferences.dart';
class EditCustomerView extends StatefulWidget {
  final int id;
  final String name;
  final String email;
  final String? contact;

  const EditCustomerView({
    super.key,
    required this.id,
    required this.name,
    required this.email,
    this.contact,
  });

  @override
  State<EditCustomerView> createState() => _EditCustomerViewState();
}

class _EditCustomerViewState extends State<EditCustomerView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameCtrl;
  late TextEditingController emailCtrl;
  late TextEditingController contactCtrl;

  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    nameCtrl    = TextEditingController(text: widget.name);
    emailCtrl   = TextEditingController(text: widget.email);
    contactCtrl = TextEditingController(text: widget.contact ?? '');
  }

  // ── actually sends the PUT request ─────────────────────────
  Future<void> _saveChanges() async {
    setState(() => isSaving = true);

    final url  = Uri.parse('http://10.0.2.2:8000/api/customers/${widget.id}/');
    final body = {
      'name'        : nameCtrl.text.trim(),
      'email'       : emailCtrl.text.trim(), // Even though it's uneditable, still send it in the payload
      'contact_num' : contactCtrl.text.trim(),
    };

    final res = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    setState(() => isSaving = false);

    if (res.statusCode == 200) {
      Navigator.pop(context, true);   // go back & signal success
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${res.statusCode}')),
      );
    }
  }

  // ── show confirm dialog then call _saveChanges ─────────────
  Future<void> _confirmAndSave() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Update'),
        content: const Text('Save these changes to the customer profile?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _saveChanges();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Customer Profile'),
      backgroundColor: const Color(0xFF5C7C9A), // Updated color
      foregroundColor: Colors.white, // Updated color for font and icon
      
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v!.isEmpty ? 'Enter a name' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: contactCtrl,
                decoration: const InputDecoration(labelText: 'Contact Number'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                readOnly: true, // <-- Make the email field uneditable
                validator: (v) => v!.isEmpty ? 'Enter an email' : null,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: isSaving ? null : _confirmAndSave,   // ← use confirm
                child: isSaving
                    ? const CircularProgressIndicator()
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}