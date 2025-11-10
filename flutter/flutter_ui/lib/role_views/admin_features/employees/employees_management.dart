import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
//import 'package:shared_preferences/shared_preferences.dart'; // Retained commented import

/// -------------------------------------------------------------------
/// Employee List and Management Page
/// -------------------------------------------------------------------

class EmployeesManagementPage extends StatefulWidget {
  const EmployeesManagementPage({super.key});

  @override
  State<EmployeesManagementPage> createState() =>
      _EmployeesManagementPageState();
}

class _EmployeesManagementPageState extends State<EmployeesManagementPage> {
  // --- Data & API Endpoints ---
  List<dynamic> employees = [];
  static const String _apiUrl = 'http://192.168.1.8:8000/api/staff/';

  // --- Lifecycle & Initialization ---
  @override
  void initState() {
    super.initState();
    _fetchEmployees(); // Use leading underscore for private methods
  }

  // --- API Methods ---

  /// Fetches the list of staff (excluding admins) from the backend API.
  Future<void> _fetchEmployees() async {
    final response = await http.get(Uri.parse(_apiUrl));

    if (response.statusCode == 200) {
      final List<dynamic> fetchedEmployees = json.decode(response.body);
      setState(() {
        // Filter out employees with the 'admin' role (Logic retained)
        employees =
            fetchedEmployees.where((emp) => emp['role'] != 'admin').toList();
      });
    } else {
      debugPrint('Failed to load employees: ${response.statusCode}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load employee data')),
        );
      }
    }
  }

  /// Deletes a staff member using their ID.
  Future<void> _deleteEmployee(int id) async {
    final response = await http.delete(Uri.parse('$_apiUrl$id/'));

    if (response.statusCode == 204) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Employee deleted successfully')));
      }
      await _fetchEmployees(); // Refresh list
    } else {
      debugPrint('Failed to delete employee: ${response.statusCode}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete employee')));
      }
    }
  }

  // --- Navigation & UI Handlers ---

  void _openAddEmployeeForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeForm(onSuccess: _fetchEmployees),
      ),
    );
  }

  void _openEditEmployeeForm(Map<String, dynamic> employee) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            EmployeeForm(employee: employee, onSuccess: _fetchEmployees),
      ),
    );
  }

  /// Shows a confirmation dialog before deletion.
  Future<void> _showDeleteConfirmation(BuildContext context, int id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Deletion',
            style: TextStyle(fontWeight: FontWeight.w600)),
        content:
            const Text('Are you sure you want to permanently remove this employee?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteEmployee(id);
    }
  }

  // --- Widget Build ---

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF5C7C9A); // Formal Slate Blue
    const Color deleteColor = Colors.redAccent;
    const Color editColor = Color(0xFF007BFF); // Blue for Edit

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        title: const Text(
          'Staff Management',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: _openAddEmployeeForm,
            tooltip: 'Add New Staff',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: employees.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'No non-admin staff records found. Tap the (+) icon to add one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: employees.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: Color(0xFFE0E0E0),
              ),
              itemBuilder: (context, index) {
                final emp = employees[index];
                final role = emp['role'] ?? 'N/A';
                final name = emp['name'] ?? 'Unknown Staff';
                final contact = emp['contact_num'] ?? 'N/A';
                final email = emp['email'] ?? 'N/A';

                return InkWell(
                  onTap: () => _openEditEmployeeForm(emp),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    leading: CircleAvatar(
                      backgroundColor: primaryColor.withOpacity(0.1),
                      child: Text(
                        name[0].toUpperCase(),
                        style: TextStyle(
                            color: primaryColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          '${role.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text('$contact',
                            style: TextStyle(color: Colors.grey[600])),
                        Text('$email',
                            style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Edit Button
                        IconButton(
                          icon: Icon(Icons.edit_note_rounded, color: editColor),
                          tooltip: 'Edit Staff',
                          onPressed: () => _openEditEmployeeForm(emp),
                        ),
                        // Delete Button
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded,
                              color: deleteColor),
                          tooltip: 'Delete Staff',
                          onPressed: () =>
                              _showDeleteConfirmation(context, emp['id']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// -------------------------------------------------------------------
// Employee Add/Edit Form Page
// -------------------------------------------------------------------

class EmployeeForm extends StatefulWidget {
  final Map<String, dynamic>? employee;
  final VoidCallback onSuccess;

  const EmployeeForm({super.key, this.employee, required this.onSuccess});

  @override
  State<EmployeeForm> createState() => _EmployeeFormState();
}

class _EmployeeFormState extends State<EmployeeForm> {
  // --- Data & State ---
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final List<String> roles = ['manager', 'cashier', 'staff'];
  static const String _apiUrl = 'http://192.168.1.8:8000/api/staff/';

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _contactController;
  late TextEditingController _passwordController;
  late String _selectedRole;

  // --- Lifecycle ---
  @override
  void initState() {
    super.initState();
    // Use private variables for controllers and state
    _nameController = TextEditingController(text: widget.employee?['name'] ?? '');
    _emailController = TextEditingController(text: widget.employee?['email'] ?? '');
    _contactController =
        TextEditingController(text: widget.employee?['contact_num'] ?? '');
    _passwordController = TextEditingController();
    _selectedRole = widget.employee?['role'] ?? 'manager';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- API Method ---

  /// Handles the submission for adding or editing an employee.
  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) return;

    final bool isEdit = widget.employee != null;
    final String url = isEdit
        ? '$_apiUrl${widget.employee!['id']}/'
        : _apiUrl;

    final Map<String, dynamic> data = {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'contact_num': _contactController.text.trim(),
      'role': _selectedRole,
    };

    // Password logic retained (required for add, optional for edit)
    if (!isEdit) {
      if (_passwordController.text.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Password is required for new staff')));
        }
        return;
      } else {
        data['password'] = _passwordController.text;
      }
    } else if (_passwordController.text.isNotEmpty) {
      data['password'] = _passwordController.text;
    }

    // Determine HTTP method
    final http.Response response = await (isEdit
        ? http.put(Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(data))
        : http.post(Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(data)));

    if (response.statusCode == 200 || response.statusCode == 201) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Staff profile ${isEdit ? 'updated' : 'added'} successfully')));
        widget.onSuccess();
        Navigator.pop(context);
      }
    } else {
      debugPrint('Error Response: ${response.body}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save staff profile')));
      }
    }
  }

  // --- Widget Build ---

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.employee != null;
    const Color primaryColor = Color(0xFF5C7C9A);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        title: Text(
          isEdit ? 'Edit Staff Profile' : 'Add New Staff',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Name Field
              _buildTextFormField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person_rounded,
                validator: (v) => v!.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              // Email Field
              _buildTextFormField(
                controller: _emailController,
                label: 'Email Address',
                icon: Icons.email_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v!.isEmpty ? 'Email is required' : null,
              ),
              const SizedBox(height: 16),
              // Contact Field
              _buildTextFormField(
                controller: _contactController,
                label: 'Contact Number',
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                validator: (v) => v!.isEmpty ? 'Contact number is required' : null,
              ),
              const SizedBox(height: 16),
              // Role Dropdown
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Staff Role',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge_rounded),
                ),
                items: roles.map((role) => DropdownMenuItem(value: role, child: Text(role.toUpperCase()))).toList(),
                onChanged: (String? value) => setState(() => _selectedRole = value!),
                validator: (v) => v == null ? 'Please select a role' : null,
              ),
              const SizedBox(height: 16),
              // Password Field
              _buildTextFormField(
                controller: _passwordController,
                label: isEdit ? 'New Password (Optional)' : 'Password',
                icon: Icons.lock_rounded,
                obscureText: true,
                validator: (v) {
                  if (!isEdit && (v == null || v.isEmpty)) {
                    return 'Password is required for new staff';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              // Save Button
              ElevatedButton.icon(
                onPressed: () => _showSaveConfirmation(context, isEdit),
                icon: Icon(isEdit ? Icons.save_rounded : Icons.add_circle_rounded),
                label: Text(
                  isEdit ? 'SAVE CHANGES' : 'ADD STAFF',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEdit ? primaryColor : Colors.green[600],
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Widget for consistent input design ---
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
      ),
      validator: validator,
    );
  }

  /// Shows a confirmation dialog before saving/submitting.
  Future<void> _showSaveConfirmation(BuildContext context, bool isEdit) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? 'Save Changes' : 'Confirm Add',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        content: Text(isEdit
            ? 'Are you sure you want to save these changes?'
            : 'Do you want to add this new staff profile?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isEdit ? const Color(0xFF5C7C9A) : Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _saveEmployee();
    }
  }
}