import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/loading_overlay.dart';
import '../../core/widgets/page_header_banner.dart';
import 'settings_state.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();

  bool _showCreateUserForm = false;
  bool _showCreateRoleForm = false;
  bool _obscurePassword = true;

  final _createRoleFormKey = GlobalKey<FormState>();
  final _roleNameInputController = TextEditingController();
  List<dynamic> _activePermissionsList = [];
  final Set<int> _selectedPermissionIds = {};
  bool _isLoadingPermissions = false;
  String _roleStatus = 'Active';

  bool _showCreatePermissionForm = false;
  final _createPermissionFormKey = GlobalKey<FormState>();
  final _permissionNameInputController = TextEditingController();
  String _permissionStatus = 'Active';

  bool _showAddCameraForm = false;
  final _createCameraFormKey = GlobalKey<FormState>();
  final _camIDInputController = TextEditingController();
  final _camLocationInputController = TextEditingController();
  final _rtaOfficeCodeInputController = TextEditingController();
  final _channelNameInputController = TextEditingController();
  String? _selectedCamDistrict;
  String _camStatus = 'Active';

  bool _showCreateOffenceForm = false;
  final _createOffenceFormKey = GlobalKey<FormState>();
  final _offenceNameInputController = TextEditingController();
  final _challanAmountInputController = TextEditingController();
  final _duplicateDaysInputController = TextEditingController(text: '1');
  final _gracePeriodDaysInputController = TextEditingController(text: '0');
  bool _offenceIsActive = true;

  final Set<String> _selectedRoles = {};
  final Set<String> _selectedPermissions = {};
  final Set<String> _selectedDistricts = {};
  bool _selectAllDistricts = false;

  final List<Offset?> _signaturePoints = [];

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _roleNameInputController.dispose();
    _permissionNameInputController.dispose();
    _camIDInputController.dispose();
    _camLocationInputController.dispose();
    _rtaOfficeCodeInputController.dispose();
    _channelNameInputController.dispose();
    _offenceNameInputController.dispose();
    _challanAmountInputController.dispose();
    _duplicateDaysInputController.dispose();
    _gracePeriodDaysInputController.dispose();
    super.dispose();
  }

  void _resetCreateUserForm() {
    _usernameController.clear();
    _passwordController.clear();
    _firstNameController.clear();
    _lastNameController.clear();
    _emailController.clear();
    _mobileController.clear();
    _selectedRoles.clear();
    _selectedPermissions.clear();
    _selectedDistricts.clear();
    _selectAllDistricts = false;
    _signaturePoints.clear();
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

  Widget _buildMobileTabItem(int index, IconData icon, String label, int activeIndex, SettingsNotifier notifier) {
    final isActive = index == activeIndex;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () => notifier.changeModule(index),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFE8F4F3) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? const Color(0xFF64D2C3) : Colors.grey.shade300,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive ? const Color(0xFF0F5D55) : const Color(0xFF4A5568),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? const Color(0xFF0F5D55) : const Color(0xFF4A5568),
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
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
    final isMobile = MediaQuery.of(context).size.width < 900;

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
              const PageHeaderBanner(
                title: 'System Settings',
                subtitle: 'Government Administration Console',
              ),
              const SizedBox(height: 16),

              // Left Sidebar + Main settings window layout (Row on desktop, Column on mobile)
              Expanded(
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                _buildMobileTabItem(0, Icons.people_alt_outlined, 'User Management', state.activeModule, notifier),
                                _buildMobileTabItem(1, Icons.assignment_ind_outlined, 'Role Management', state.activeModule, notifier),
                                _buildMobileTabItem(2, Icons.verified_user_outlined, 'Permission Management', state.activeModule, notifier),
                                _buildMobileTabItem(3, Icons.videocam_outlined, 'Camera Management', state.activeModule, notifier),
                                _buildMobileTabItem(4, Icons.gavel_outlined, 'Offence Management', state.activeModule, notifier),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: Card(
                              elevation: 1,
                              color: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              clipBehavior: Clip.antiAlias,
                              child: RefreshIndicator(
                                onRefresh: () async {
                                  await notifier.loadData();
                                },
                                child: SingleChildScrollView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(16),
                                  child: _buildMainContent(state),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
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
        _buildModuleHeader(
          title: 'User Management',
          subtitle: 'Create and manage system users',
          icon: _showCreateUserForm ? Icons.close : Icons.person_add_outlined,
          buttonLabel: _showCreateUserForm ? 'Cancel' : 'Create New User',
          onPressed: () {
            setState(() {
              _resetCreateUserForm();
              _showCreateUserForm = !_showCreateUserForm;
            });
          },
        ),
        const SizedBox(height: 20),

        if (_showCreateUserForm)
          _buildCreateUserInlineForm(state)
        else ...[
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
        LayoutBuilder(
          builder: (context, constraints) {
            final double minWidth = 800;
            final double contentWidth = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: contentWidth,
                child: Table(
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
              ),
            );
          },
        ),
        ],
      ],
    );
  }

  Widget _buildCreateUserInlineForm(SettingsState state) {
    final availableRoles = state.roles.map((r) {
      if (r is Map) return r['roleName']?.toString() ?? '';
      return r.toString();
    }).where((name) => name.isNotEmpty).toList();

    if (availableRoles.isEmpty) {
      availableRoles.addAll(['Admin', 'Viewer', 'Tester', 'Inspector', 'Sub Inspector', 'officer']);
    }

    final availablePermissions = [
      'LIVE_FEED',
      'SETTINGS',
      'CHALLAN',
      'HISTORY',
      'SUPPORT_CENTER',
      'DETAILES_NOT_FOUND',
      'VEHICLE_HISTORY',
      'DASHBOARD',
      'BUDGET_PAGE',
      'VEHICLE_EXPORT',
    ];

    final availableDistricts = state.districts.map((d) {
      if (d is Map) return d['districtName']?.toString() ?? '';
      return d.toString();
    }).where((name) => name.isNotEmpty).toList();

    final isMobile = MediaQuery.of(context).size.width < 800;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'New User Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D9488),
            ),
          ),
          const SizedBox(height: 20),

          // Inputs Grid
          if (isMobile) ...[
            _buildFormTextField(
              label: 'Username',
              hintText: 'Enter username (max 50 chars)',
              controller: _usernameController,
              isRequired: true,
            ),
            const SizedBox(height: 16),
            _buildFormTextField(
              label: 'Mobile Number',
              hintText: 'Enter mobile (10-15 digits)',
              controller: _mobileController,
              isRequired: true,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            _buildFormTextField(
              label: 'Password',
              hintText: 'Minimum 6 characters',
              controller: _passwordController,
              isRequired: true,
              isPassword: true,
            ),
            const SizedBox(height: 16),
            _buildFormTextField(
              label: 'Email',
              hintText: 'Enter email (optional)',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _buildFormTextField(
              label: 'First Name',
              hintText: 'Enter first name (optional)',
              controller: _firstNameController,
            ),
            const SizedBox(height: 16),
            _buildFormTextField(
              label: 'Last Name',
              hintText: 'Enter last name (optional)',
              controller: _lastNameController,
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildFormTextField(
                    label: 'Username',
                    hintText: 'Enter username (max 50 chars)',
                    controller: _usernameController,
                    isRequired: true,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildFormTextField(
                    label: 'Mobile Number',
                    hintText: 'Enter mobile (10-15 digits)',
                    controller: _mobileController,
                    isRequired: true,
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildFormTextField(
                    label: 'Password',
                    hintText: 'Minimum 6 characters',
                    controller: _passwordController,
                    isRequired: true,
                    isPassword: true,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildFormTextField(
                    label: 'Email',
                    hintText: 'Enter email (optional)',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildFormTextField(
                    label: 'First Name',
                    hintText: 'Enter first name (optional)',
                    controller: _firstNameController,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildFormTextField(
                    label: 'Last Name',
                    hintText: 'Enter last name (optional)',
                    controller: _lastNameController,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),

          // Roles, Permissions & Districts Sections
          if (isMobile) ...[
            // Roles Box
            const Text('Roles', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: availableRoles.map((roleName) {
                  final isChecked = _selectedRoles.contains(roleName);
                  return CheckboxListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: Text(roleName, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B))),
                    value: isChecked,
                    activeColor: const Color(0xFF0D9488),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedRoles.add(roleName);
                        } else {
                          _selectedRoles.remove(roleName);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Permissions Box
            const Text('Permissions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F3260))),
            const SizedBox(height: 4),
            Text('Selecting a role automatically selects its permissions. You may check or uncheck permissions to create user-specific overrides.', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            Column(
              children: availablePermissions.map((perm) {
                final isChecked = _selectedPermissions.contains(perm);
                return CheckboxListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(perm, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                  value: isChecked,
                  activeColor: const Color(0xFF0D9488),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedPermissions.add(perm);
                      } else {
                        _selectedPermissions.remove(perm);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Districts Box
            const Text('Districts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  CheckboxListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: const Text('Select All Districts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F3260))),
                    value: _selectAllDistricts,
                    activeColor: const Color(0xFF0D9488),
                    onChanged: (val) {
                      setState(() {
                        _selectAllDistricts = val == true;
                        if (_selectAllDistricts) {
                          _selectedDistricts.addAll(availableDistricts);
                        } else {
                          _selectedDistricts.clear();
                        }
                      });
                    },
                  ),
                  const Divider(height: 1),
                  ...availableDistricts.map((dist) {
                    final isChecked = _selectedDistricts.contains(dist);
                    return CheckboxListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: Text(dist, style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                      value: isChecked,
                      activeColor: const Color(0xFF0D9488),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedDistricts.add(dist);
                          } else {
                            _selectedDistricts.remove(dist);
                          }
                          _selectAllDistricts = _selectedDistricts.length == availableDistricts.length;
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Roles & Permissions
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Roles', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      const SizedBox(height: 8),
                      Container(
                        height: 160,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          children: availableRoles.map((roleName) {
                            final isChecked = _selectedRoles.contains(roleName);
                            return CheckboxListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              title: Text(roleName, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B))),
                              value: isChecked,
                              activeColor: const Color(0xFF0D9488),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedRoles.add(roleName);
                                  } else {
                                    _selectedRoles.remove(roleName);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text('Permissions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F3260))),
                      const SizedBox(height: 4),
                      Text('Selecting a role automatically selects its permissions. You may check or uncheck permissions to create user-specific overrides.', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      const SizedBox(height: 12),
                      Column(
                        children: availablePermissions.map((perm) {
                          final isChecked = _selectedPermissions.contains(perm);
                          return CheckboxListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            title: Text(perm, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                            value: isChecked,
                            activeColor: const Color(0xFF0D9488),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedPermissions.add(perm);
                                } else {
                                  _selectedPermissions.remove(perm);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),

                // Right Column: Districts
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Districts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      const SizedBox(height: 8),
                      Container(
                        height: 320,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          children: [
                            CheckboxListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              title: const Text('Select All Districts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F3260))),
                              value: _selectAllDistricts,
                              activeColor: const Color(0xFF0D9488),
                              onChanged: (val) {
                                setState(() {
                                  _selectAllDistricts = val == true;
                                  if (_selectAllDistricts) {
                                    _selectedDistricts.addAll(availableDistricts);
                                  } else {
                                    _selectedDistricts.clear();
                                  }
                                });
                              },
                            ),
                            const Divider(height: 1),
                            ...availableDistricts.map((dist) {
                              final isChecked = _selectedDistricts.contains(dist);
                              return CheckboxListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                title: Text(dist, style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                                value: isChecked,
                                activeColor: const Color(0xFF0D9488),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedDistricts.add(dist);
                                    } else {
                                      _selectedDistricts.remove(dist);
                                    }
                                    _selectAllDistricts = _selectedDistricts.length == availableDistricts.length;
                                  });
                                },
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),

          // Signature Section
          const Text('Signature', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 8),
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Listener(
              onPointerDown: (event) {
                final RenderBox renderBox = context.findRenderObject() as RenderBox;
                final localPosition = renderBox.globalToLocal(event.position);
                setState(() {
                  _signaturePoints.add(localPosition);
                });
              },
              onPointerMove: (event) {
                final RenderBox renderBox = context.findRenderObject() as RenderBox;
                final localPosition = renderBox.globalToLocal(event.position);
                setState(() {
                  _signaturePoints.add(localPosition);
                });
              },
              onPointerUp: (event) {
                setState(() {
                  _signaturePoints.add(null);
                });
              },
              child: CustomPaint(
                painter: _SignaturePainter(_signaturePoints),
                child: Stack(
                  children: [
                    if (_signaturePoints.isEmpty)
                      const Center(
                        child: Text(
                          'Draw signature here',
                          style: TextStyle(color: Colors.black26, fontSize: 13),
                        ),
                      ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: OutlinedButton(
                        onPressed: () => setState(() => _signaturePoints.clear()),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                        child: const Text('Clear Signature', style: TextStyle(color: Color(0xFF334155), fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Form Action Buttons
          Row(
            children: [
              FilledButton.icon(
                onPressed: _submitInlineCreateUser,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Create User', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF64D2C3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () => setState(() {
                  _resetCreateUserForm();
                  _showCreateUserForm = false;
                }),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF94A3B8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormTextField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    bool isRequired = false,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword && _obscurePassword,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 13),
          validator: isRequired
              ? (val) => (val == null || val.trim().isEmpty) ? '$label is required' : null
              : null,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 18,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Future<void> _submitInlineCreateUser() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final messenger = ScaffoldMessenger.of(context);
    final roleStr = _selectedRoles.isNotEmpty ? _selectedRoles.join(', ') : 'User';

    final success = await ref.read(settingsNotifierProvider.notifier).createNewUser(
          username: _usernameController.text.trim(),
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          mobileNumber: _mobileController.text.trim(),
          role: roleStr,
        );

    if (success && mounted) {
      setState(() {
        _showCreateUserForm = false;
        _usernameController.clear();
        _passwordController.clear();
        _firstNameController.clear();
        _lastNameController.clear();
        _emailController.clear();
        _mobileController.clear();
        _signaturePoints.clear();
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('User created successfully.')),
      );
    }
  }

  Future<void> _toggleCreateRoleForm() async {
    setState(() {
      _showCreateRoleForm = !_showCreateRoleForm;
      if (_showCreateRoleForm) {
        _roleNameInputController.clear();
        _selectedPermissionIds.clear();
        _roleStatus = 'Active';
      }
    });

    if (_showCreateRoleForm && _activePermissionsList.isEmpty) {
      setState(() => _isLoadingPermissions = true);
      final perms = await ref.read(settingsNotifierProvider.notifier).fetchActivePermissions();
      if (mounted) {
        setState(() {
          _activePermissionsList = perms;
          _isLoadingPermissions = false;
        });
      }
    }
  }

  Future<void> _submitNewRole() async {
    if (!(_createRoleFormKey.currentState?.validate() ?? false)) return;
    final roleName = _roleNameInputController.text.trim();
    if (roleName.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final success = await ref.read(settingsNotifierProvider.notifier).createRole(
      roleName,
      _selectedPermissionIds.toList(),
      _roleStatus == 'Active',
    );

    if (success && mounted) {
      setState(() {
        _showCreateRoleForm = false;
        _roleNameInputController.clear();
        _selectedPermissionIds.clear();
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Role created successfully.')),
      );
    }
  }

  Widget _buildRoleManagement(SettingsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModuleHeader(
          title: 'Role Management',
          subtitle: 'Create and manage system roles',
          icon: Icons.badge_outlined,
          buttonLabel: _showCreateRoleForm ? 'Cancel' : 'Create Role',
          onPressed: _toggleCreateRoleForm,
        ),
        const SizedBox(height: 24),

        if (_showCreateRoleForm) ...[
          // New Role Card matching Image 2
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2ECEC), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Form(
              key: _createRoleFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'New Role',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00A49F),
                    ),
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      final roleNameField = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: const TextSpan(
                              text: 'Role Name ',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                              children: [
                                TextSpan(text: '*', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _roleNameInputController,
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Role name is required' : null,
                            decoration: InputDecoration(
                              hintText: 'Enter role name',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      );

                      final statusField = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Status',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _roleStatus,
                            items: const [
                              DropdownMenuItem(value: 'Active', child: Text('Active')),
                              DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _roleStatus = val);
                              }
                            },
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      );

                      if (isMobile) {
                        return Column(
                          children: [
                            roleNameField,
                            const SizedBox(height: 16),
                            statusField,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: roleNameField),
                          const SizedBox(width: 20),
                          Expanded(child: statusField),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Permissions',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300, width: 1.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _isLoadingPermissions
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D9488)))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _activePermissionsList.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (context, index) {
                              final item = _activePermissionsList[index];
                              final Map<String, dynamic> perm = item is Map ? Map<String, dynamic>.from(item) : {};
                              final id = int.tryParse(perm['id']?.toString() ?? '') ?? 0;
                              final permName = perm['permissionName']?.toString() ?? '';
                              final isChecked = _selectedPermissionIds.contains(id);

                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isChecked) {
                                      _selectedPermissionIds.remove(id);
                                    } else {
                                      _selectedPermissionIds.add(id);
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Checkbox(
                                          value: isChecked,
                                          activeColor: const Color(0xFF0D9488),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedPermissionIds.add(id);
                                              } else {
                                                _selectedPermissionIds.remove(id);
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        permName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: _submitNewRole,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF81C784),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text(
                          'Submit',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _toggleCreateRoleForm,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF90A4AE),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

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
        LayoutBuilder(
          builder: (context, constraints) {
            final double minWidth = 800;
            final double contentWidth = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: contentWidth,
                child: Table(
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
              ),
            );
          },
        ),
      ],
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

  void _toggleCreatePermissionForm() {
    setState(() {
      _showCreatePermissionForm = !_showCreatePermissionForm;
      if (_showCreatePermissionForm) {
        _permissionNameInputController.clear();
        _permissionStatus = 'Active';
      }
    });
  }

  Future<void> _submitNewPermission() async {
    if (!(_createPermissionFormKey.currentState?.validate() ?? false)) return;
    final permName = _permissionNameInputController.text.trim();
    if (permName.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final success = await ref.read(settingsNotifierProvider.notifier).createPermission(
      permName,
      _permissionStatus == 'Active',
    );

    if (success && mounted) {
      setState(() {
        _showCreatePermissionForm = false;
        _permissionNameInputController.clear();
        _permissionStatus = 'Active';
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Permission created successfully.')),
      );
    }
  }

  Widget _buildPermissionManagement(SettingsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModuleHeader(
          title: 'Permission Management',
          subtitle: 'Create and manage permissions',
          icon: Icons.security_outlined,
          buttonLabel: _showCreatePermissionForm ? 'Cancel' : 'Create Permission',
          onPressed: _toggleCreatePermissionForm,
        ),
        const SizedBox(height: 24),

        if (_showCreatePermissionForm) ...[
          // New Permission Card matching Image 2
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2ECEC), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Form(
              key: _createPermissionFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'New Permission',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00A49F),
                    ),
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      final permNameField = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Permission Name',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _permissionNameInputController,
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Permission name is required' : null,
                            decoration: InputDecoration(
                              hintText: 'Enter permission name',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      );

                      final statusField = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Status',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _permissionStatus,
                            items: const [
                              DropdownMenuItem(value: 'Active', child: Text('Active')),
                              DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _permissionStatus = val);
                              }
                            },
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      );

                      if (isMobile) {
                        return Column(
                          children: [
                            permNameField,
                            const SizedBox(height: 16),
                            statusField,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: permNameField),
                          const SizedBox(width: 20),
                          Expanded(child: statusField),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: _submitNewPermission,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF81C784),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text(
                          'Save Permission',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _toggleCreatePermissionForm,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF90A4AE),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

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
        LayoutBuilder(
          builder: (context, constraints) {
            final double minWidth = 800;
            final double contentWidth = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: contentWidth,
                child: Table(
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
              ),
            );
          },
        ),
      ],
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

  void _toggleAddCameraForm() {
    setState(() {
      _showAddCameraForm = !_showAddCameraForm;
      if (_showAddCameraForm) {
        _camIDInputController.clear();
        _camLocationInputController.clear();
        _rtaOfficeCodeInputController.clear();
        _channelNameInputController.clear();
        _selectedCamDistrict = null;
        _camStatus = 'Active';
      }
    });
  }

  Future<void> _submitNewCamera() async {
    if (!(_createCameraFormKey.currentState?.validate() ?? false)) return;
    final camID = _camIDInputController.text.trim();
    if (camID.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final success = await ref.read(settingsNotifierProvider.notifier).addCamera({
      'cameraID': camID,
      'cameraLocation': _camLocationInputController.text.trim(),
      'districtCode': _selectedCamDistrict ?? '',
      'rtaOfficeCode': _rtaOfficeCodeInputController.text.trim(),
      'channelName': _channelNameInputController.text.trim().isEmpty ? null : _channelNameInputController.text.trim(),
      'status': _camStatus == 'Active',
    });

    if (success && mounted) {
      setState(() {
        _showAddCameraForm = false;
        _camIDInputController.clear();
        _camLocationInputController.clear();
        _rtaOfficeCodeInputController.clear();
        _channelNameInputController.clear();
        _selectedCamDistrict = null;
        _camStatus = 'Active';
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Camera added successfully.')),
      );
    }
  }

  Widget _buildCameraManagement(SettingsState state) {
    final notifier = ref.read(settingsNotifierProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModuleHeader(
          title: 'Camera Management',
          subtitle: 'Add, edit, and monitor camera configurations',
          icon: Icons.add,
          buttonLabel: _showAddCameraForm ? 'Cancel' : 'Add / Edit Camera',
          onPressed: _toggleAddCameraForm,
        ),
        const SizedBox(height: 20),

        if (_showAddCameraForm) ...[
          // New Camera Information Card matching Image 2
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2ECEC), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Form(
              key: _createCameraFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'New Camera Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00A49F),
                    ),
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;

                      final camIDField = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: const TextSpan(
                              text: 'Camera ID ',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                              children: [
                                TextSpan(text: '*', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _camIDInputController,
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Camera ID is required' : null,
                            decoration: InputDecoration(
                              hintText: 'Enter camera ID',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      );

                      final camLocationField = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Camera Location',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _camLocationInputController,
                            decoration: InputDecoration(
                              hintText: 'Enter location (optional)',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      );

                      final districtField = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: const TextSpan(
                              text: 'District ',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                              children: [
                                TextSpan(text: '*', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _selectedCamDistrict,
                            hint: const Text('Select District', style: TextStyle(fontSize: 13, color: Colors.grey)),
                            items: state.districts.map((d) {
                              final name = d['districtName']?.toString() ?? '';
                              return DropdownMenuItem<String>(value: name, child: Text(name, overflow: TextOverflow.ellipsis));
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedCamDistrict = val),
                            validator: (val) => (val == null || val.isEmpty) ? 'District is required' : null,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      );

                      final rtaOfficeCodeField = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: const TextSpan(
                              text: 'RTA Office Code ',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                              children: [
                                TextSpan(text: '*', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _rtaOfficeCodeInputController,
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'RTA office code is required' : null,
                            decoration: InputDecoration(
                              hintText: 'Enter office code',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      );

                      final channelNameField = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Channel Name',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _channelNameInputController,
                            decoration: InputDecoration(
                              hintText: 'Enter channel name (optional)',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      );

                      final statusField = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Status',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _camStatus,
                            items: const [
                              DropdownMenuItem(value: 'Active', child: Text('Active')),
                              DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _camStatus = val);
                              }
                            },
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      );

                      if (isMobile) {
                        return Column(
                          children: [
                            camIDField,
                            const SizedBox(height: 16),
                            camLocationField,
                            const SizedBox(height: 16),
                            districtField,
                            const SizedBox(height: 16),
                            rtaOfficeCodeField,
                            const SizedBox(height: 16),
                            channelNameField,
                            const SizedBox(height: 16),
                            statusField,
                          ],
                        );
                      }
                      return Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: camIDField),
                              const SizedBox(width: 20),
                              Expanded(child: camLocationField),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: districtField),
                              const SizedBox(width: 20),
                              Expanded(child: rtaOfficeCodeField),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: channelNameField),
                              const SizedBox(width: 20),
                              Expanded(child: statusField),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _submitNewCamera,
                        icon: const Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
                        label: const Text(
                          'Add Camera',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF81C784),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _toggleAddCameraForm,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF90A4AE),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // District filter card
        Card(
          elevation: 1,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select District',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;

                    final dropdown = DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: state.selectedDistrict.isEmpty ? null : state.selectedDistrict,
                      hint: const Text(
                        'Select District',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Select District',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      items: state.districts.map((d) {
                        final name = d is Map ? (d['districtName']?.toString() ?? '') : d.toString();
                        return DropdownMenuItem<String>(value: name, child: Text(name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis));
                      }).where((item) => item.value != null && item.value!.isNotEmpty).toList(),
                      onChanged: (val) {
                        if (val != null) notifier.changeDistrict(val);
                      },
                    );

                    final loadBtn = ElevatedButton.icon(
                      onPressed: () {
                        if (state.selectedDistrict.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select a district first.'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        notifier.loadCameras();
                      },
                      icon: const Icon(Icons.search, size: 16, color: Colors.white),
                      label: const Text(
                        'Load Cameras',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                    );

                    if (isMobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          dropdown,
                          const SizedBox(height: 12),
                          loadBtn,
                        ],
                      );
                    } else {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: dropdown),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 50,
                            child: loadBtn,
                          ),
                        ],
                      );
                    }
                  },
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

        if (state.cameras.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.videocam_off_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    state.selectedDistrict.isEmpty
                        ? 'Select a district and click "Load Cameras" to view cameras.'
                        : 'No cameras found for the selected district.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          // Table
          LayoutBuilder(
            builder: (context, constraints) {
              final double minWidth = 820;
              final double contentWidth = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: contentWidth,
                  child: Table(
                    columnWidths: const {
                      0: FixedColumnWidth(100),  // Camera ID
                      1: FlexColumnWidth(2),     // Office
                      2: FlexColumnWidth(2),     // Location
                      3: FlexColumnWidth(2),     // District Code
                      4: FlexColumnWidth(2.5),   // Channel
                      5: FixedColumnWidth(90),   // Status
                      6: FixedColumnWidth(110),  // Actions
                    },
                    border: TableBorder(
                      horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1),
                      bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                    ),
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(color: Color(0xFFFAFAFA)),
                        children: const [
                          Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Camera ID', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260), fontSize: 12))),
                          Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Office', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260), fontSize: 12))),
                          Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Location', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260), fontSize: 12))),
                          Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('District Code', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260), fontSize: 12))),
                          Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Channel', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260), fontSize: 12))),
                          Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260), fontSize: 12))),
                          Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3260), fontSize: 12))),
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
                            Padding(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8), child: Text(cameraID, style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600))),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8), child: Text(rtaOfficeCode, style: const TextStyle(fontSize: 12, color: Colors.black87))),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8), child: Text(location, style: const TextStyle(fontSize: 12, color: Colors.black87))),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8), child: Text(districtCode, style: const TextStyle(fontSize: 12, color: Colors.black87))),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8), child: Text(channel, style: const TextStyle(fontSize: 12, color: Colors.black87))),
                            // Status badge
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                            // Actions popup menu
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: PopupMenuButton<String>(
                                  onSelected: (action) {
                                    switch (action) {
                                      case 'view':
                                        showDialog(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: Text('Camera: $cameraID'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _infoRow('Camera ID', cameraID),
                                                _infoRow('Location', location),
                                                _infoRow('Office', rtaOfficeCode),
                                                _infoRow('District Code', districtCode),
                                                _infoRow('Channel', channel),
                                                _infoRow('Status', status ? 'Active' : 'Inactive'),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                                            ],
                                          ),
                                        );
                                        break;
                                      case 'edit':
                                        final editCamIDCtrl     = TextEditingController(text: cameraID);
                                        final editLocationCtrl  = TextEditingController(text: location);
                                        final editChannelCtrl   = TextEditingController(text: channel);
                                        final editOfficeCtrl    = TextEditingController(text: rtaOfficeCode);
                                        String? editDistrict    = districtCode;
                                        bool   editStatus       = status;
                                        showDialog(
                                          context: context,
                                          builder: (_) => StatefulBuilder(
                                            builder: (ctx, setDlgState) => AlertDialog(
                                              title: Text('Edit Camera: $cameraID'),
                                              content: SingleChildScrollView(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    _editField('Camera ID', editCamIDCtrl, readOnly: true),
                                                    const SizedBox(height: 12),
                                                    _editField('Camera Location', editLocationCtrl),
                                                    const SizedBox(height: 12),
                                                    _editField('Channel Name', editChannelCtrl),
                                                    const SizedBox(height: 12),
                                                    _editField('RTA Office Code', editOfficeCtrl),
                                                    const SizedBox(height: 12),
                                                    const Text('District', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
                                                    const SizedBox(height: 4),
                                                    DropdownButtonFormField<String>(
                                                      isExpanded: true,
                                                      initialValue: state.districts.any((d) {
                                                        final n = d is Map ? d['districtCode']?.toString() : d.toString();
                                                        return n == editDistrict;
                                                      }) ? editDistrict : null,
                                                      items: state.districts.map((d) {
                                                        final code = d is Map ? (d['districtCode']?.toString() ?? '') : d.toString();
                                                        final name = d is Map ? (d['districtName']?.toString() ?? code) : code;
                                                        return DropdownMenuItem<String>(value: code, child: Text(name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis));
                                                      }).where((i) => i.value != null && i.value!.isNotEmpty).toList(),
                                                      onChanged: (v) => setDlgState(() => editDistrict = v),
                                                      decoration: InputDecoration(
                                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                                        isDense: true,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Row(
                                                      children: [
                                                        const Text('Active', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
                                                        const SizedBox(width: 8),
                                                        Switch(
                                                          value: editStatus,
                                                          onChanged: (v) => setDlgState(() => editStatus = v),
                                                          activeThumbColor: const Color(0xFF0D9488),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    Navigator.pop(ctx);
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('Camera $cameraID updated successfully.')),
                                                    );
                                                  },
                                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
                                                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                        break;
                                      case 'delete':
                                        showDialog(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Delete Camera'),
                                            content: Text('Are you sure you want to delete camera $cameraID?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Camera $cameraID deleted.')),
                                                  );
                                                },
                                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem<String>(
                                      value: 'view',
                                      child: Row(
                                        children: [
                                          Icon(Icons.visibility_outlined, size: 16, color: Colors.black87),
                                          SizedBox(width: 8),
                                          Text('View Camera', style: TextStyle(fontSize: 13, color: Colors.black87)),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 16, color: Colors.black87),
                                          SizedBox(width: 8),
                                          Text('Edit Camera', style: TextStyle(fontSize: 13, color: Colors.black87)),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete Camera', style: TextStyle(fontSize: 13, color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Actions', style: TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w600)),
                                        SizedBox(width: 4),
                                        Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.black87),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );

  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editField(String label, TextEditingController ctrl, {bool readOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          readOnly: readOnly,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: readOnly,
            fillColor: readOnly ? Colors.grey.shade100 : null,
          ),
        ),
      ],
    );
  }

  void _toggleCreateOffenceForm() {
    setState(() {
      _showCreateOffenceForm = !_showCreateOffenceForm;
      if (_showCreateOffenceForm) {
        _offenceNameInputController.clear();
        _challanAmountInputController.clear();
        _duplicateDaysInputController.text = '1';
        _gracePeriodDaysInputController.text = '0';
        _offenceIsActive = true;
      }
    });
  }

  Future<void> _submitNewOffence() async {
    if (!(_createOffenceFormKey.currentState?.validate() ?? false)) return;
    final name = _offenceNameInputController.text.trim();
    if (name.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final success = await ref.read(settingsNotifierProvider.notifier).createOffence({
      'offence': name,
      'challanAmount': double.tryParse(_challanAmountInputController.text.trim()) ?? 0.0,
      'duplicateDays': int.tryParse(_duplicateDaysInputController.text.trim()) ?? 1,
      'gracePeriodDays': int.tryParse(_gracePeriodDaysInputController.text.trim()) ?? 0,
      'isActive': _offenceIsActive,
    });

    if (success && mounted) {
      setState(() {
        _showCreateOffenceForm = false;
        _offenceNameInputController.clear();
        _challanAmountInputController.clear();
        _duplicateDaysInputController.text = '1';
        _gracePeriodDaysInputController.text = '0';
        _offenceIsActive = true;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Offence rule created successfully.')),
      );
    }
  }

  Widget _buildOffenceManagement(SettingsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        _buildModuleHeader(
          title: 'Offence Management',
          subtitle: 'Create and maintain offence rules used for challan generation',
          icon: Icons.add,
          buttonLabel: _showCreateOffenceForm ? 'Cancel' : 'Create New Offence',
          onPressed: _toggleCreateOffenceForm,
        ),
        const SizedBox(height: 20),

        if (_showCreateOffenceForm) ...[
          // Offence Rule Details Card matching Image 2
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2ECEC), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Form(
              key: _createOffenceFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Offence Rule Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00A49F),
                    ),
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;

                      final offenceNameField = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: const TextSpan(
                              text: 'Offence Name ',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                              children: [
                                TextSpan(text: '*', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _offenceNameInputController,
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Offence name is required' : null,
                            decoration: InputDecoration(
                              hintText: 'Enter offence name',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      );

                      final challanAmountField = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Challan Amount',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _challanAmountInputController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'Enter amount',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      );

                      final duplicateDaysField = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Duplicate Days',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _duplicateDaysInputController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      );

                      final gracePeriodDaysField = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Grace Period Days',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _gracePeriodDaysInputController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      );

                      if (isMobile) {
                        return Column(
                          children: [
                            offenceNameField,
                            const SizedBox(height: 16),
                            challanAmountField,
                            const SizedBox(height: 16),
                            duplicateDaysField,
                            const SizedBox(height: 16),
                            gracePeriodDaysField,
                          ],
                        );
                      }
                      return Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: offenceNameField),
                              const SizedBox(width: 20),
                              Expanded(child: challanAmountField),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: duplicateDaysField),
                              const SizedBox(width: 20),
                              Expanded(child: gracePeriodDaysField),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _offenceIsActive,
                          activeColor: const Color(0xFF0D9488),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (val) {
                            setState(() => _offenceIsActive = val ?? true);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Active',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2D3748)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _submitNewOffence,
                        icon: const Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
                        label: const Text(
                          'Save Offence',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF81C784),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _toggleCreateOffenceForm,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF90A4AE),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

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
        LayoutBuilder(
          builder: (context, constraints) {
            final double minWidth = 1000;
            final double contentWidth = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: contentWidth,
                child: Table(
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
              ),
            );
          },
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

  Widget _buildModuleHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = MediaQuery.of(context).size.width < 600;
        
        final infoColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F3260),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        );
        
        final actionButton = FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 16),
          label: Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0D9488),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        
        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              infoColumn,
              const SizedBox(height: 12),
              actionButton,
            ],
          );
        } else {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: infoColumn),
              const SizedBox(width: 16),
              actionButton,
            ],
          );
        }
      },
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.points);
  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

