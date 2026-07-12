import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/loading_overlay.dart';
import 'settings_state.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  String _selectedRole = 'admin';

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  String _formatCreatedDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  void _showCreateUserDialog() {
    _usernameController.clear();
    _firstNameController.clear();
    _lastNameController.clear();
    _emailController.clear();
    _mobileController.clear();
    setState(() => _selectedRole = 'admin');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Create New User',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)),
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInputField('Username *', _usernameController, true),
                        _buildInputField('First Name *', _firstNameController, true),
                        _buildInputField('Last Name', _lastNameController, false),
                        _buildInputField('Email *', _emailController, true, keyboardType: TextInputType.emailAddress),
                        _buildInputField('Mobile Number *', _mobileController, true, keyboardType: TextInputType.phone),
                                                const Text(
                          'Role *',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedRole,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'admin', child: Text('Admin')),
                            DropdownMenuItem(value: 'operator', child: Text('Operator')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => _selectedRole = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                FilledButton(
                  onPressed: () async {
                    if (_formKey.currentState?.validate() ?? false) {
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      final success = await ref.read(settingsNotifierProvider.notifier).createNewUser(
                            username: _usernameController.text.trim(),
                            firstName: _firstNameController.text.trim(),
                            lastName: _lastNameController.text.trim(),
                            email: _emailController.text.trim(),
                            mobileNumber: _mobileController.text.trim(),
                            role: _selectedRole,
                          );
                      if (success && mounted) {
                        navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('User created successfully.')),
                        );
                      }
                    }
                  },
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, bool required, {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: required
                ? (val) => (val == null || val.trim().isEmpty) ? 'This field is required' : null
                : null,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  void _showViewUserDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) {
        final fullName = (user['firstName']?.toString().isEmpty ?? true) && (user['lastName']?.toString().isEmpty ?? true)
            ? '-'
            : '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
        return AlertDialog(
          title: const Text('User Profile Details', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260))),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileDetailRow('Name', fullName),
                _buildProfileDetailRow('Username', user['username']?.toString() ?? '-'),
                _buildProfileDetailRow('Email', user['email']?.toString() ?? '-'),
                _buildProfileDetailRow('Mobile Number', user['mobileNumber']?.toString() ?? '-'),
                _buildProfileDetailRow('Role', user['role']?.toString().toUpperCase() ?? '-'),
                _buildProfileDetailRow('Created At', _formatCreatedDate(user['createdAt']?.toString())),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteUser(int id) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete User'),
          content: const Text('Are you sure you want to delete this user? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                final success = await ref.read(settingsNotifierProvider.notifier).deleteUser(id);
                if (success && mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('User deleted successfully.')),
                  );
                }
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLeftMenuItem(int index, IconData icon, String label, int activeIndex, SettingsNotifier notifier) {
    final isActive = index == activeIndex;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => notifier.changeModule(index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFE8F4F3) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? const Color(0xFF64D2C3) : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? const Color(0xFF0F5D55) : const Color(0xFF4A5568),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? const Color(0xFF0F5D55) : const Color(0xFF4A5568),
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsNotifierProvider);
    final notifier = ref.read(settingsNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F6),
      body: LoadingOverlay(
        isLoading: state.isLoading,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Title Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F3260),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Government Administration Console',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text(
                        'Logged in as: ',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const Text(
                        'admin',
                        style: TextStyle(fontSize: 13, color: Color(0xFF0F5D55), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Left Sidebar + Main settings window row
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Menu Card
                    SizedBox(
                      width: 280,
                      child: Card(
                        elevation: 1,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Settings Modules',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildLeftMenuItem(0, Icons.people_alt_outlined, 'User Management', state.activeModule, notifier),
                              _buildLeftMenuItem(1, Icons.assignment_ind_outlined, 'Role Management', state.activeModule, notifier),
                              _buildLeftMenuItem(2, Icons.verified_user_outlined, 'Permission Management', state.activeModule, notifier),
                              _buildLeftMenuItem(3, Icons.videocam_outlined, 'Camera Management', state.activeModule, notifier),
                              _buildLeftMenuItem(4, Icons.gavel_outlined, 'Offence Management', state.activeModule, notifier),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Right Main Panel
                    Expanded(
                      child: Card(
                        elevation: 1,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        clipBehavior: Clip.antiAlias,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: _buildMainContent(state),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(SettingsState state) {
    switch (state.activeModule) {
      case 0:
        return _buildUserManagement(state);
      case 1:
        return _buildRoleManagement(state);
      case 2:
        return _buildPermissionManagement(state);
      case 3:
        return _buildCameraManagement(state);
      case 4:
        return _buildOffenceManagement(state);
      default:
        return _buildUserManagement(state);
    }
  }



  Widget _buildUserManagement(SettingsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User Management Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User Management',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F3260),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Create and manage system users',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: _showCreateUserDialog,
              icon: const Icon(Icons.person_add_outlined, size: 16),
              label: const Text('Create New User', style: TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Info Alert Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: const Border(
              left: BorderSide(color: Color(0xFF3B82F6), width: 4),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF3B82F6), size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Management Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Click "Create New User" to add and manage system users.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Section Title: Users with badge
        Row(
          children: [
            const Text(
              'Users',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F3260)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F4EA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${state.users.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF137333),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Table
        Table(
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(4),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(2),
            4: FlexColumnWidth(3),
            5: FlexColumnWidth(3),
          },
          border: TableBorder(
            horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1),
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          children: [
            TableRow(
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAFA),
              ),
              children: const [
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Email', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Role', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Created Date', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
              ],
            ),
            ...state.users.map((userObj) {
              final Map<String, dynamic> user = userObj is Map ? Map<String, dynamic>.from(userObj) : {};
              final userId = int.tryParse(user['id']?.toString() ?? '') ?? 0;
              final name = (user['firstName']?.toString().isEmpty ?? true) && (user['lastName']?.toString().isEmpty ?? true)
                  ? '-'
                  : '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
              final email = user['email']?.toString().isEmpty ?? true ? '-' : user['email'].toString();

              return TableRow(
                children: [
                  Padding(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), child: Text(name, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), child: Text(email, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), child: Text(user['role']?.toString() ?? 'N/A', style: const TextStyle(fontSize: 13, color: Colors.black87))),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Active', style: TextStyle(color: Color(0xFF166534), fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), child: Text(_formatCreatedDate(user['createdAt']?.toString()), style: const TextStyle(fontSize: 13, color: Colors.black87))),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () => _showViewUserDialog(user),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                minimumSize: Size.zero,
                              ),
                              child: const Text('View', style: TextStyle(color: Colors.black87, fontSize: 11)),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Edit user functionality under construction.')),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                minimumSize: Size.zero,
                              ),
                              child: const Text('Edit', style: TextStyle(color: Colors.black87, fontSize: 11)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        FilledButton(
                          onPressed: () => _confirmDeleteUser(userId),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFB91C1C),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            minimumSize: const Size(88, 24),
                          ),
                          child: const Text('Delete', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleManagement(SettingsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Role Management',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F3260),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Create and manage system roles',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: _showCreateRoleDialog,
              icon: const Icon(Icons.badge_outlined, size: 16),
              label: const Text('Create Role', style: TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Section Title: Roles with badge
        Row(
          children: [
            const Text(
              'Roles',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F3260)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F4EA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${state.roles.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF137333),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Table
        Table(
          columnWidths: const {
            0: FlexColumnWidth(4),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(3),
            3: FlexColumnWidth(5),
          },
          border: TableBorder(
            horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1),
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          children: [
            TableRow(
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAFA),
              ),
              children: const [
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Role Name', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Created Date', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
              ],
            ),
            ...state.roles.map((roleObj) {
              final Map<String, dynamic> r = roleObj is Map ? Map<String, dynamic>.from(roleObj) : {};
              final roleId = int.tryParse(r['id']?.toString() ?? '') ?? 0;
              final name = r['roleName']?.toString() ?? '-';
              final isActive = r['isActive'] == true;

              return TableRow(
                children: [
                  Padding(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), child: Text(name, style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500))),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isActive ? 'Active' : 'Deactivated',
                          style: TextStyle(
                            color: isActive ? const Color(0xFF166534) : const Color(0xFF991B1B),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), child: Text(_formatCreatedDate(r['createdAt']?.toString()), style: const TextStyle(fontSize: 13, color: Colors.black87))),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton(
                          onPressed: () => _showViewRoleDialog(r),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                          ),
                          child: const Text('View', style: TextStyle(color: Colors.black87, fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Edit role functionality under construction.')),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                          ),
                          child: const Text('Edit', style: TextStyle(color: Colors.black87, fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => _confirmToggleRole(roleId, isActive),
                          style: FilledButton.styleFrom(
                            backgroundColor: isActive ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                          ),
                          child: Text(
                            isActive ? 'Deactivate' : 'Activate',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  void _showCreateRoleDialog() {
    final roleController = TextEditingController();
    final roleFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Role', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260))),
          content: SizedBox(
            width: 400,
            child: Form(
              key: roleFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Role Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: roleController,
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Role name is required' : null,
                    decoration: InputDecoration(
                      hintText: 'Enter role name (e.g. Viewer)',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              onPressed: () async {
                if (roleFormKey.currentState?.validate() ?? false) {
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final success = await ref.read(settingsNotifierProvider.notifier).createRole(roleController.text.trim());
                  if (success && mounted) {
                    navigator.pop();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Role created successfully.')),
                    );
                  }
                }
              },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _showViewRoleDialog(Map<String, dynamic> role) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Role Details', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260))),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileDetailRow('Role ID', role['id']?.toString() ?? '-'),
                _buildProfileDetailRow('Role Name', role['roleName']?.toString() ?? '-'),
                _buildProfileDetailRow('Status', (role['isActive'] == true) ? 'Active' : 'Deactivated'),
                _buildProfileDetailRow('Created Date', _formatCreatedDate(role['createdAt']?.toString())),
                _buildProfileDetailRow('Last Updated', _formatCreatedDate(role['updatedAt']?.toString())),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _confirmToggleRole(int id, bool currentActiveState) {
    final actionText = currentActiveState ? 'deactivate' : 'activate';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${actionText.substring(0, 1).toUpperCase()}${actionText.substring(1)} Role'),
          content: Text('Are you sure you want to $actionText this role?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                final success = await ref.read(settingsNotifierProvider.notifier).toggleRoleActive(id, !currentActiveState);
                if (success && mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(content: Text('Role has been $actionText\u0064 successfully.')),
                  );
                }
              },
              style: FilledButton.styleFrom(backgroundColor: currentActiveState ? Colors.red : Colors.green),
              child: Text(currentActiveState ? 'Deactivate' : 'Activate'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPermissionManagement(SettingsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Permission Management',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F3260),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Create and manage permissions',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: _showCreatePermissionDialog,
              icon: const Icon(Icons.security_outlined, size: 16),
              label: const Text('Create Permission', style: TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Section Title: Permissions with badge
        Row(
          children: [
            const Text(
              'Permissions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F3260)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F4EA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${state.permissions.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF137333),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Table
        Table(
          columnWidths: const {
            0: FlexColumnWidth(4),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(3),
            3: FlexColumnWidth(4),
          },
          border: TableBorder(
            horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1),
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          children: [
            TableRow(
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAFA),
              ),
              children: const [
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Permission Name', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Created Date', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
              ],
            ),
            ...state.permissions.map((permObj) {
              final Map<String, dynamic> p = permObj is Map ? Map<String, dynamic>.from(permObj) : {};
              final permId = int.tryParse(p['id']?.toString() ?? '') ?? 0;
              final name = p['permissionName']?.toString() ?? '-';
              final isActive = p['isActive'] == true;

              return TableRow(
                children: [
                  Padding(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), child: Text(name, style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500))),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isActive ? 'Active' : 'Deactivated',
                          style: TextStyle(
                            color: isActive ? const Color(0xFF166534) : const Color(0xFF991B1B),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), child: Text(_formatCreatedDate(p['createdAt']?.toString()), style: const TextStyle(fontSize: 13, color: Colors.black87))),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Edit permission functionality under construction.')),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                          ),
                          child: const Text('Edit', style: TextStyle(color: Colors.black87, fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => _confirmTogglePermission(permId, isActive),
                          style: FilledButton.styleFrom(
                            backgroundColor: isActive ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                          ),
                          child: Text(
                            isActive ? 'Deactivate' : 'Activate',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  void _showCreatePermissionDialog() {
    final permController = TextEditingController();
    final permFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Permission', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260))),
          content: SizedBox(
            width: 400,
            child: Form(
              key: permFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Permission Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: permController,
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Permission name is required' : null,
                    decoration: InputDecoration(
                      hintText: 'Enter permission name (e.g. dashboard)',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              onPressed: () async {
                if (permFormKey.currentState?.validate() ?? false) {
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final success = await ref.read(settingsNotifierProvider.notifier).createPermission(permController.text.trim());
                  if (success && mounted) {
                    navigator.pop();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Permission created successfully.')),
                    );
                  }
                }
              },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _confirmTogglePermission(int id, bool currentActiveState) {
    final actionText = currentActiveState ? 'deactivate' : 'activate';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${actionText.substring(0, 1).toUpperCase()}${actionText.substring(1)} Permission'),
          content: Text('Are you sure you want to $actionText this permission?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                final success = await ref.read(settingsNotifierProvider.notifier).togglePermissionActive(id, !currentActiveState);
                if (success && mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(content: Text('Permission has been $actionText\u0064 successfully.')),
                  );
                }
              },
              style: FilledButton.styleFrom(backgroundColor: currentActiveState ? Colors.red : Colors.green),
              child: Text(currentActiveState ? 'Deactivate' : 'Activate'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCameraManagement(SettingsState state) {
    final notifier = ref.read(settingsNotifierProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Camera Management',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F3260),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Add, edit, and monitor camera configurations',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: _showAddCameraDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add / Edit Camera', style: TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // District filter card
        Card(
          elevation: 1,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('District', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: state.selectedDistrict.isEmpty ? null : state.selectedDistrict,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                        items: state.districts.map((d) {
                          final name = d['districtName']?.toString() ?? '';
                          return DropdownMenuItem<String>(value: name, child: Text(name));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            notifier.changeDistrict(val);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        notifier.loadCameras();
                      },
                      icon: const Icon(Icons.search, size: 16, color: Colors.black87),
                      label: const Text('Load Cameras', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Section Title: Cameras with badge
        Row(
          children: [
            const Text(
              'Cameras',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F3260)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F4EA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${state.cameras.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF137333),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Table
        Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(3),
            4: FlexColumnWidth(2),
            5: FlexColumnWidth(2),
            6: FlexColumnWidth(2),
          },
          border: TableBorder(
            horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1),
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          children: [
            TableRow(
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAFA),
              ),
              children: const [
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Camera ID', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Office', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('District Code', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Location', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Channel', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
              ],
            ),
            ...state.cameras.map((camObj) {
              final Map<String, dynamic> c = camObj is Map ? Map<String, dynamic>.from(camObj) : {};
              final cameraID = c['cameraID']?.toString() ?? '-';
              final location = c['cameraLocation']?.toString() ?? '-';
              final districtCode = c['districtCode']?.toString() ?? '-';
              final rtaOfficeCode = c['rtaOfficeCode']?.toString() ?? '-';
              final channel = c['channelName']?.toString() ?? '-';
              final status = c['status'] != false;

              return TableRow(
                children: [
                  Padding(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), child: Text(cameraID, style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600))),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), child: Text(rtaOfficeCode, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), child: Text(districtCode, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), child: Text(location, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), child: Text(channel, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: status ? const Color(0xFFE6F4EA) : const Color(0xFFFCE8E6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status ? 'Active' : 'Inactive',
                          style: TextStyle(
                            color: status ? const Color(0xFF137333) : const Color(0xFFC5221F),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Actions for $cameraID triggered.')),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Actions', style: TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w600)),
                            SizedBox(width: 4),
                            Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.black87),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  void _showAddCameraDialog() {
    final camIDController = TextEditingController();
    final locationController = TextEditingController();
    final channelController = TextEditingController();
    final camFormKey = GlobalKey<FormState>();

    final state = ref.read(settingsNotifierProvider);
    String? selectedDistCode;
    String? selectedOfficeCode;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add New Camera', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260))),
              content: SizedBox(
                width: 450,
                child: Form(
                  key: camFormKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInputField('Camera ID *', camIDController, true),
                        _buildInputField('Location *', locationController, true),
                        
                        const Text('District *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: state.districts.map((d) {
                            final code = d['districtCode']?.toString() ?? '';
                            final name = d['districtName']?.toString() ?? '';
                            return DropdownMenuItem<String>(value: code, child: Text('$name ($code)'));
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedDistCode = val;
                              selectedOfficeCode = null; // Reset office on district change
                            });
                          },
                          validator: (val) => val == null ? 'District is required' : null,
                        ),
                        const SizedBox(height: 12),

                        const Text('RTA Office *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: selectedOfficeCode,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          // Filter offices by chosen district code
                          items: state.offices.where((o) => o['districtCode'] == selectedDistCode).map((o) {
                            final code = o['officeCode']?.toString() ?? '';
                            final name = o['officeName']?.toString() ?? '';
                            return DropdownMenuItem<String>(value: code, child: Text('$name ($code)'));
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedOfficeCode = val;
                            });
                          },
                          validator: (val) => val == null ? 'RTA office is required' : null,
                        ),
                        const SizedBox(height: 12),
                        
                        _buildInputField('Channel Name (optional)', channelController, false),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                FilledButton(
                  onPressed: () async {
                    if (camFormKey.currentState?.validate() ?? false) {
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      final success = await ref.read(settingsNotifierProvider.notifier).addCamera({
                        'cameraID': camIDController.text.trim(),
                        'cameraLocation': locationController.text.trim(),
                        'districtCode': selectedDistCode,
                        'rtaOfficeCode': selectedOfficeCode,
                        'channelName': channelController.text.trim().isEmpty ? null : channelController.text.trim(),
                      });
                      if (success && mounted) {
                        navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Camera registered successfully.')),
                        );
                      }
                    }
                  },
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildOffenceManagement(SettingsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offence Management',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F3260),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Create and maintain offence rules used for challan generation',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: _showCreateOffenceDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Create New Offence', style: TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Info Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: const Border(
              left: BorderSide(color: Color(0xFF3B82F6), width: 4),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF3B82F6), size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offence Management Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Maintain offence rules, limits, cooldowns, and activation status from here.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Section Title: Offence Rules with badge
        Row(
          children: [
            const Text(
              'Offence Rules',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F3260)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F4EA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${state.offenceConfigs.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF137333),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Table
        Table(
          columnWidths: const {
            0: FlexColumnWidth(4),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(2),
            4: FlexColumnWidth(2),
            5: FlexColumnWidth(3),
            6: FlexColumnWidth(3),
          },
          border: TableBorder(
            horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1),
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          children: [
            TableRow(
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAFA),
              ),
              children: const [
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Offence', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Duplicate Days', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Grace Period Days', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Updated', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
                Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260)))),
              ],
            ),
            ...state.offenceConfigs.map((offObj) {
              final Map<String, dynamic> o = offObj is Map ? Map<String, dynamic>.from(offObj) : {};
              final offenceId = int.tryParse(o['id']?.toString() ?? '') ?? 0;
              final name = o['offence']?.toString() ?? '-';
              
              final double amountVal = double.tryParse(o['challanAmount']?.toString() ?? '0') ?? 0.0;
              final amountText = amountVal == amountVal.toInt() ? amountVal.toInt().toString() : amountVal.toString();
              
              final duplicateDays = o['duplicateDays']?.toString() ?? '1';
              final gracePeriodDays = o['gracePeriodDays']?.toString() ?? '0';
              final isActive = o['isActive'] == true;
              final updatedTime = _formatOffenceUpdatedTime(o['updated_time']?.toString() ?? o['created_time']?.toString());

              return TableRow(
                children: [
                  Padding(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), child: Text(name, style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500))),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), child: Text(amountText, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), child: Text(duplicateDays, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), child: Text(gracePeriodDays, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            color: isActive ? const Color(0xFF166534) : const Color(0xFF991B1B),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), child: Text(updatedTime, style: const TextStyle(fontSize: 12, color: Colors.black54))),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: isActive
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                OutlinedButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Edit offence configuration under construction.')),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.grey.shade300),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    minimumSize: const Size(80, 28),
                                  ),
                                  child: const Text('Edit', style: TextStyle(color: Colors.black87, fontSize: 11)),
                                ),
                                const SizedBox(height: 6),
                                OutlinedButton(
                                  onPressed: () => _confirmToggleOffence(offenceId, isActive),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.grey.shade300),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    minimumSize: const Size(80, 28),
                                  ),
                                  child: const Text('Deactivate', style: TextStyle(color: Colors.black87, fontSize: 11)),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                OutlinedButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Edit offence configuration under construction.')),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.grey.shade300),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    minimumSize: const Size(60, 28),
                                  ),
                                  child: const Text('Edit', style: TextStyle(color: Colors.black87, fontSize: 11)),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => _confirmToggleOffence(offenceId, isActive),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.grey.shade300),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    minimumSize: const Size(60, 28),
                                  ),
                                  child: const Text('Activate', style: TextStyle(color: Colors.black87, fontSize: 11)),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  String _formatOffenceUpdatedTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  void _showCreateOffenceDialog() {
    final offenceController = TextEditingController();
    final amountController = TextEditingController();
    final dupController = TextEditingController(text: '1');
    final graceController = TextEditingController(text: '0');
    final offFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Offence Rule', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260))),
          content: SizedBox(
            width: 400,
            child: Form(
              key: offFormKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputField('Offence Name *', offenceController, true),
                    _buildInputField('Challan Amount (₹) *', amountController, true, keyboardType: TextInputType.number),
                    _buildInputField('Duplicate Days *', dupController, true, keyboardType: TextInputType.number),
                    _buildInputField('Grace Period Days *', graceController, true, keyboardType: TextInputType.number),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              onPressed: () async {
                if (offFormKey.currentState?.validate() ?? false) {
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final success = await ref.read(settingsNotifierProvider.notifier).createOffence({
                    'offence': offenceController.text.trim(),
                    'challanAmount': amountController.text.trim(),
                    'duplicateDays': dupController.text.trim(),
                    'gracePeriodDays': graceController.text.trim(),
                  });
                  if (success && mounted) {
                    navigator.pop();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Offence rule created successfully.')),
                    );
                  }
                }
              },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _confirmToggleOffence(int id, bool currentActiveState) {
    final actionText = currentActiveState ? 'deactivate' : 'activate';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${actionText.substring(0, 1).toUpperCase()}${actionText.substring(1)} Offence'),
          content: Text('Are you sure you want to $actionText this offence rule?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                final success = await ref.read(settingsNotifierProvider.notifier).toggleOffenceActive(id, !currentActiveState);
                if (success && mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(content: Text('Offence rule has been $actionText\u0064 successfully.')),
                  );
                }
              },
              style: FilledButton.styleFrom(backgroundColor: currentActiveState ? Colors.red : Colors.green),
              child: Text(currentActiveState ? 'Deactivate' : 'Activate'),
            ),
          ],
        );
      },
    );
  }
}
