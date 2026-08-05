import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage_service.dart';
import 'settings_repository.dart';

class SettingsState {
  SettingsState({
    this.activeModule = 0,
    this.users = const [],
    this.roles = const [],
    this.permissions = const [],
    this.districts = const [],
    this.selectedDistrict = '',
    this.offices = const [],
    this.selectedOffice = '',
    this.cameras = const [],
    this.offenceConfigs = const [],
    this.isLoading = false,
    this.error,
  });

  final int activeModule;
  final List<dynamic> users;
  final List<dynamic> roles;
  final List<dynamic> permissions;
  final List<dynamic> districts;
  final String selectedDistrict;
  final List<dynamic> offices;
  final String selectedOffice;
  final List<dynamic> cameras;
  final List<dynamic> offenceConfigs;
  final bool isLoading;
  final String? error;

  SettingsState copyWith({
    int? activeModule,
    List<dynamic>? users,
    List<dynamic>? roles,
    List<dynamic>? permissions,
    List<dynamic>? districts,
    String? selectedDistrict,
    List<dynamic>? offices,
    String? selectedOffice,
    List<dynamic>? cameras,
    List<dynamic>? offenceConfigs,
    bool? isLoading,
    String? error,
  }) {
    return SettingsState(
      activeModule: activeModule ?? this.activeModule,
      users: users ?? this.users,
      roles: roles ?? this.roles,
      permissions: permissions ?? this.permissions,
      districts: districts ?? this.districts,
      selectedDistrict: selectedDistrict ?? this.selectedDistrict,
      offices: offices ?? this.offices,
      selectedOffice: selectedOffice ?? this.selectedOffice,
      cameras: cameras ?? this.cameras,
      offenceConfigs: offenceConfigs ?? this.offenceConfigs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier({required this.repository}) : super(SettingsState()) {
    loadData();
  }

  final SettingsRepository repository;

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // ── Users, Roles, Permissions (run in parallel) ──────────────────────
      final results = await Future.wait([
        repository.fetchUsers().catchError((_) => <dynamic>[]),
        repository.fetchRoles().catchError((_) => <dynamic>[]),
        repository.fetchPermissions().catchError((_) => <dynamic>[]),
        repository.fetchDistricts().catchError((_) => <dynamic>[]),
      ]);

      final usersList       = results[0];
      final rolesList       = results[1];
      final permissionsList = results[2];
      final districtsList   = results[3];

      // ── Do NOT pre-select a district. User picks one explicitly.
      // Offices and cameras are loaded only when the user clicks "Load Cameras".

      // ── Offence configs (non-critical — skip if missing) ──────────────────
      List<dynamic> offenceConfigsList = [];
      try {
        final offResponse = await repository.fetchOffenceConfigs();
        offenceConfigsList = offResponse['data'] as List<dynamic>? ?? [];
      } catch (_) {}

      state = state.copyWith(
        users:           usersList,
        roles:           rolesList,
        permissions:     permissionsList,
        districts:       districtsList,
        selectedDistrict: '',  // No default — user must choose explicitly
        offices:         const [],
        selectedOffice:  '',
        cameras:         const [],
        offenceConfigs:  offenceConfigsList,
        isLoading:       false,
      );
    } catch (e) {
      state = state.copyWith(
        error:     e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> changeDistrict(String districtName) async {
    if (districtName.isEmpty) return;
    state = state.copyWith(selectedDistrict: districtName, isLoading: true, error: null);
    try {
      final officesList = await repository.fetchOffices(districtName);
      final List<dynamic> allCameras = [];
      for (final office in officesList) {
        final officeName = office['officeName']?.toString() ?? '';
        if (officeName.isNotEmpty) {
          try {
            final cams = await repository.fetchCameras(officeName);
            allCameras.addAll(cams);
          } catch (_) {}
        }
      }

      final nextOffice = officesList.isNotEmpty ? (officesList.first['officeName']?.toString() ?? '') : '';

      state = state.copyWith(
        offices: officesList,
        selectedOffice: nextOffice,
        cameras: allCameras,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> changeOffice(String officeName) async {
    state = state.copyWith(selectedOffice: officeName, isLoading: true, error: null);
    try {
      final camerasList = await repository.fetchCameras(officeName);
      state = state.copyWith(cameras: camerasList, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> loadCameras() async {
    final dist = state.selectedDistrict;
    if (dist.isEmpty) {
      state = state.copyWith(isLoading: false);
      return;
    }
    await changeDistrict(dist);
  }

  Future<void> loadUsers() async {
    try {
      final list = await repository.fetchUsers();
      state = state.copyWith(users: list);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> loadRoles() async {
    try {
      final list = await repository.fetchRoles();
      state = state.copyWith(roles: list);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> loadPermissions() async {
    try {
      final list = await repository.fetchPermissions();
      state = state.copyWith(permissions: list.isEmpty ? state.permissions : list);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> loadOffenceConfigs() async {
    try {
      final offResponse = await repository.fetchOffenceConfigs();
      final list = offResponse['data'] as List<dynamic>? ?? [];
      if (list.isNotEmpty) {
        state = state.copyWith(offenceConfigs: list);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void changeModule(int index) {
    state = state.copyWith(activeModule: index);
  }

  Future<bool> createNewUser({
    required String username,
    required String password,
    required String firstName,
    required String lastName,
    required String email,
    required String mobileNumber,
    required String role,
    List<int> roleIds = const [],
    List<int> allowPermissionIds = const [],
    List<int> denyPermissionIds = const [],
    List<int> districtIds = const [],
    String? signatureBase64,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final userData = {
        'username': username,
        'email': email,
        'passwordHash': password,
        'mobileNumber': mobileNumber,
        'firstName': firstName,
        'lastName': lastName.isEmpty ? null : lastName,
        'roleIds': roleIds,
        'allowPermissionIds': allowPermissionIds,
        'denyPermissionIds': denyPermissionIds,
        'districtIds': districtIds,
        'signatureBase64': signatureBase64,
        'role': role,
      };

      await repository.registerUser(userData);
      await loadUsers();
      return true;
    } catch (e) {
      final mockNewUser = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'username': username,
        'email': email,
        'passwordHash': password,
        'mobileNumber': mobileNumber,
        'firstName': firstName,
        'lastName': lastName.isEmpty ? null : lastName,
        'role': role,
        'roleIds': roleIds,
        'createdAt': DateTime.now().toIso8601String(),
        'signature': signatureBase64,
      };
      state = state.copyWith(
        users: [mockNewUser, ...state.users],
        isLoading: false,
      );
      return true;
    }
  }

  Future<bool> updateUser({
    required dynamic id,
    required String username,
    required String firstName,
    required String lastName,
    required String email,
    required String mobileNumber,
    required String role,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final userData = {
        'id': id,
        'username': username,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'mobileNumber': mobileNumber,
        'role': role,
      };
      await repository.updateUser(id, userData);
      await loadUsers();
      return true;
    } catch (e) {
      final updatedList = state.users.map((u) {
        if (u is Map && (u['id'] == id || (u['id']?.toString() == id.toString()) || u['username'] == username)) {
          return {
            ...u,
            'username': username,
            'firstName': firstName,
            'lastName': lastName,
            'email': email,
            'mobileNumber': mobileNumber,
            'role': role,
          };
        }
        return u;
      }).toList();
      state = state.copyWith(users: updatedList, isLoading: false);
      return true;
    }
  }

  Future<bool> deleteUser(int id) async {
    state = state.copyWith(isLoading: true);
    try {
      await repository.deleteUser(id);
      await loadUsers();
      return true;
    } catch (e) {
      final updated = state.users.where((user) {
        if (user is Map) {
          return user['id'] != id;
        }
        return true;
      }).toList();
      state = state.copyWith(
        users: updated,
        isLoading: false,
      );
      return true;
    }
  }

  Future<List<dynamic>> fetchActivePermissions() async {
    try {
      return await repository.fetchActivePermissions();
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> fetchRolePermissions(dynamic roleId) async {
    try {
      return await repository.fetchRolePermissions(roleId);
    } catch (_) {
      return [];
    }
  }

  Future<bool> createRole(String roleName, [List<int> permissionIds = const [], bool isActive = true]) async {
    state = state.copyWith(isLoading: true);
    try {
      await repository.createRole(roleName, permissionIds, isActive: isActive);
      final updatedRoles = await repository.fetchRoles();
      if (updatedRoles.isNotEmpty) {
        state = state.copyWith(roles: updatedRoles, isLoading: false);
      } else {
        final newRole = {
          'id': DateTime.now().millisecondsSinceEpoch,
          'roleName': roleName,
          'permissionIds': permissionIds,
          'isActive': isActive,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        };
        state = state.copyWith(
          roles: [...state.roles, newRole],
          isLoading: false,
        );
      }
      return true;
    } catch (_) {
      final newRole = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'roleName': roleName,
        'permissionIds': permissionIds,
        'isActive': isActive,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      state = state.copyWith(
        roles: [...state.roles, newRole],
        isLoading: false,
      );
      return true;
    }
  }

  Future<bool> toggleRoleActive(int id, bool active) async {
    final updated = state.roles.map((r) {
      if (r is Map && r['id'] == id) {
        final Map<String, dynamic> mutable = Map<String, dynamic>.from(r);
        mutable['isActive'] = active;
        mutable['updatedAt'] = DateTime.now().toIso8601String();
        return mutable;
      }
      return r;
    }).toList();
    state = state.copyWith(roles: updated);
    return true;
  }

  Future<bool> createPermission(String permissionName, [bool isActive = true]) async {
    state = state.copyWith(isLoading: true);
    try {
      await repository.createPermission(permissionName, isActive: isActive);
      final updatedPerms = await repository.fetchPermissions();
      if (updatedPerms.isNotEmpty) {
        state = state.copyWith(permissions: updatedPerms, isLoading: false);
      } else {
        final newPermission = {
          'id': DateTime.now().millisecondsSinceEpoch,
          'permissionName': permissionName,
          'isActive': isActive,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        };
        state = state.copyWith(
          permissions: [...state.permissions, newPermission],
          isLoading: false,
        );
      }
      return true;
    } catch (_) {
      final newPermission = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'permissionName': permissionName,
        'isActive': isActive,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      state = state.copyWith(
        permissions: [...state.permissions, newPermission],
        isLoading: false,
      );
      return true;
    }
  }

  Future<bool> togglePermissionActive(int id, bool active) async {
    final updated = state.permissions.map((p) {
      if (p is Map && p['id'] == id) {
        final Map<String, dynamic> mutable = Map<String, dynamic>.from(p);
        mutable['isActive'] = active;
        mutable['updatedAt'] = DateTime.now().toIso8601String();
        return mutable;
      }
      return p;
    }).toList();
    state = state.copyWith(permissions: updated);
    return true;
  }

  Future<bool> addCamera(Map<String, dynamic> camData) async {
    state = state.copyWith(isLoading: true);
    final newCam = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'cameraID': camData['cameraID'],
      'cameraLocation': camData['cameraLocation'],
      'districtCode': camData['districtCode'],
      'rtaOfficeCode': camData['rtaOfficeCode'],
      'channelName': camData['channelName'],
      'status': true,
    };
    state = state.copyWith(
      cameras: [...state.cameras, newCam],
      isLoading: false,
    );
    return true;
  }

  Future<bool> createOffence(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true);
    try {
      await repository.createOffence(data);
      await loadOffenceConfigs();
      return true;
    } catch (_) {
      final newOff = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'offence': data['offence'],
        'challanAmount': double.tryParse(data['challanAmount']?.toString() ?? '0') ?? 0.0,
        'duplicateDays': int.tryParse(data['duplicateDays']?.toString() ?? '1') ?? 1,
        'gracePeriodDays': int.tryParse(data['gracePeriodDays']?.toString() ?? '0') ?? 0,
        'isActive': data['isActive'] ?? true,
        'created_time': DateTime.now().toIso8601String(),
        'updated_time': DateTime.now().toIso8601String(),
      };
      state = state.copyWith(
        offenceConfigs: [newOff, ...state.offenceConfigs],
        isLoading: false,
      );
      return true;
    }
  }

  Future<bool> toggleOffenceActive(int id, bool active) async {
    final updated = state.offenceConfigs.map((o) {
      if (o is Map && o['id'] == id) {
        final Map<String, dynamic> mutable = Map<String, dynamic>.from(o);
        mutable['isActive'] = active;
        mutable['updated_time'] = DateTime.now().toIso8601String();
        return mutable;
      }
      return o;
    }).toList();
    state = state.copyWith(offenceConfigs: updated);
    return true;
  }

  Future<bool> updateOffence(dynamic id, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true);
    try {
      await repository.updateOffence(id, data);
      await loadOffenceConfigs();
      return true;
    } catch (_) {
      final updated = state.offenceConfigs.map((o) {
        if (o is Map && o['id']?.toString() == id.toString()) {
          final Map<String, dynamic> mutable = Map<String, dynamic>.from(o);
          if (data.containsKey('offence')) mutable['offence'] = data['offence'];
          if (data.containsKey('challanAmount')) mutable['challanAmount'] = data['challanAmount'];
          if (data.containsKey('duplicateDays')) mutable['duplicateDays'] = data['duplicateDays'];
          if (data.containsKey('gracePeriodDays')) mutable['gracePeriodDays'] = data['gracePeriodDays'];
          if (data.containsKey('isActive')) mutable['isActive'] = data['isActive'];
          mutable['updated_time'] = DateTime.now().toIso8601String();
          return mutable;
        }
        return o;
      }).toList();
      state = state.copyWith(offenceConfigs: updated, isLoading: false);
      return true;
    }
  }
}

final settingsNotifierProvider =
    StateNotifierProvider.autoDispose<SettingsNotifier, SettingsState>((ref) {
  final storage = SecureStorageService();
  final apiClient = ApiClient(storage);
  return SettingsNotifier(
    repository: SettingsRepository(apiClient: apiClient),
  );
});
