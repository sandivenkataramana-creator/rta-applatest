import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';
import '../../features/auth/auth_notifier.dart';
import '../../features/alerts/alerts_state.dart';

final sidebarCollapsedProvider = StateProvider<bool>((ref) => true);

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.activePath,
  });

  final Widget child;
  final String activePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;
    final isCollapsed = ref.watch(sidebarCollapsedProvider);

    if (isDesktop) {
      return Scaffold(
        backgroundColor: const Color(0xFFF3F6F6),
        body: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isCollapsed ? 70.0 : 260.0,
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(),
              child: OverflowBox(
                alignment: AlignmentDirectional.topStart,
                minWidth: isCollapsed ? 70.0 : 260.0,
                maxWidth: isCollapsed ? 70.0 : 260.0,
                child: _PortalDrawer(
                  isDrawer: false,
                  isCollapsed: isCollapsed,
                  activePath: activePath,
                ),
              ),
            ),
            Expanded(
              child: child,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF031A1C),
                Color(0xFF0A3C39),
                Color(0xFF0B423E),
              ],
            ),
            border: Border(
              bottom: BorderSide(color: Color(0xFF00F5D4), width: 2),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            Image.asset(
              'assets/images/telangana_logo.png',
              height: 36,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.account_balance,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Telangana ANPR Portal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      const Flexible(
                        child: Text(
                          'Vehicle Identification & Enforcement Automation',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.verified,
                        color: Colors.teal.shade200,
                        size: 10,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (context) {
              final alertsState = ref.watch(alertsNotifierProvider);
              final alertCount = alertsState.items.length;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none, color: Colors.white, size: 24),
                    onPressed: () {
                      context.go('/dashboard/alerts');
                    },
                  ),
                  if (alertCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                          child: Text(
                            alertCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _PortalDrawer(
        isDrawer: true,
        isCollapsed: false,
        activePath: activePath,
      ),
      body: child,
      bottomNavigationBar: Builder(
        builder: (scaffoldContext) {
          int getActiveIndex() {
            if (activePath == AppRoutes.dashboard) return 0;
            if (activePath == AppRoutes.analytics) return 1;
            if (activePath == AppRoutes.vehicleClassification) return 2;
            if (activePath == AppRoutes.reports) return 3;
            return 0;
          }

          return BottomNavigationBar(
            currentIndex: getActiveIndex(),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color(0xFF0D9488),
            unselectedItemColor: Colors.grey,
            selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 10),
            onTap: (index) {
              if (index == 4) {
                Scaffold.of(scaffoldContext).openDrawer();
                return;
              }
              final paths = [
                AppRoutes.dashboard,
                AppRoutes.analytics,
                AppRoutes.vehicleClassification,
                AppRoutes.reports,
              ];
              context.go(paths[index]);
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_outlined),
                activeIcon: Icon(Icons.bar_chart),
                label: 'Analytics',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_outlined),
                activeIcon: Icon(Icons.receipt_long),
                label: 'Challan',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.description_outlined),
                activeIcon: Icon(Icons.description),
                label: 'Reports',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.more_horiz_outlined),
                activeIcon: Icon(Icons.more_horiz),
                label: 'More',
              ),
            ],
          );
        },
      ),
    );
  }
}



class _PortalDrawer extends ConsumerWidget {
  const _PortalDrawer({
    required this.isDrawer,
    required this.isCollapsed,
    required this.activePath,
  });

  final bool isDrawer;
  final bool isCollapsed;
  final String activePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final header = isCollapsed
        ? Container(
            height: 64.0,
            alignment: Alignment.center,
            child: IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF0D9488)),
              onPressed: () {
                ref.read(sidebarCollapsedProvider.notifier).update((state) => !state);
              },
              tooltip: 'Expand Sidebar',
            ),
          )
        : Container(
            height: 64.0,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.menu, color: Color(0xFF0D9488)),
                  onPressed: () {
                    ref.read(sidebarCollapsedProvider.notifier).update((state) => !state);
                  },
                  tooltip: 'Collapse Sidebar',
                ),
                const SizedBox(width: 8),
                Image.asset(
                  'assets/images/telangana_logo.png',
                  height: 32,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.account_balance,
                    color: Color(0xFF0F5D55),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 8),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'VIAES',
                      style: TextStyle(
                        color: Color(0xFF0D9488),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'TELANGANA',
                      style: TextStyle(
                        color: Color(0xFF0F5D55),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

    bool isRouteActive(String route) {
      if (route.isEmpty) return false;
      if (route == AppRoutes.dashboard) {
        return activePath == AppRoutes.dashboard || activePath == '/dashboard/';
      }
      return activePath == route || activePath.startsWith('$route/') || activePath.startsWith('$route?');
    }

    final items = [
      _DrawerItem(
        label: 'Dashboard',
        icon: Icons.grid_view_outlined,
        route: AppRoutes.dashboard,
        isCollapsed: isCollapsed,
        isActive: isRouteActive(AppRoutes.dashboard),
      ),
      _DrawerItem(
        label: 'Live Feed',
        icon: Icons.account_tree_outlined,
        route: AppRoutes.liveFeed,
        isCollapsed: isCollapsed,
        isActive: isRouteActive(AppRoutes.liveFeed),
      ),
      _DrawerItem(
        label: 'History',
        icon: Icons.format_list_bulleted,
        route: AppRoutes.vehicleMonitoring,
        isCollapsed: isCollapsed,
        isActive: isRouteActive(AppRoutes.vehicleMonitoring),
      ),
      _DrawerItem(
        label: 'Vehicle Export',
        icon: Icons.assignment_outlined,
        route: AppRoutes.anprRecords,
        isCollapsed: isCollapsed,
        isActive: isRouteActive(AppRoutes.anprRecords),
      ),
      _DrawerItem(
        label: 'Details Not Found',
        icon: Icons.error,
        route: AppRoutes.alerts,
        isCollapsed: isCollapsed,
        isActive: isRouteActive(AppRoutes.alerts),
      ),
      _DrawerItem(
        label: 'Budget Page',
        icon: Icons.folder_open_outlined,
        route: AppRoutes.analytics,
        isCollapsed: isCollapsed,
        isActive: isRouteActive(AppRoutes.analytics),
      ),
      _DrawerItem(
        label: 'Settings',
        icon: Icons.settings_outlined,
        route: AppRoutes.settings,
        isCollapsed: isCollapsed,
        isActive: isRouteActive(AppRoutes.settings),
      ),
      _DrawerItem(
        label: 'Support Center',
        icon: Icons.local_play_outlined,
        route: AppRoutes.users,
        isCollapsed: isCollapsed,
        isActive: isRouteActive(AppRoutes.users),
      ),
      _DrawerItem(
        label: 'Vehicle History',
        icon: Icons.search_outlined,
        route: AppRoutes.vehicleClassification,
        isCollapsed: isCollapsed,
        isActive: isRouteActive(AppRoutes.vehicleClassification),
      ),
      _DrawerItem(
        label: 'Logout',
        icon: Icons.logout,
        route: '',
        isCollapsed: isCollapsed,
        isActive: false,
        onTap: () => ref.read(authNotifierProvider.notifier).logout(),
      ),
    ];

    final content = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: isDrawer
            ? null
            : const Border(
                right: BorderSide(
                  color: Color(0xFFE2ECEC),
                  width: 1.0,
                ),
              ),
      ),
      child: Column(
        children: [
          header,
          const Divider(color: Color(0xFFE2ECEC), height: 1),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: items,
            ),
          ),
        ],
      ),
    );

    if (isDrawer) {
      return Drawer(
        child: content,
      );
    } else {
      return content;
    }
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.label,
    required this.icon,
    required this.route,
    required this.isCollapsed,
    required this.isActive,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final String route;
  final bool isCollapsed;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    final activeBgColor = const Color(0xFFE6F7F5);
    final activeTextColor = const Color(0xFF0D9488);
    final inactiveTextColor = const Color(0xFF4A5568);
    final hoverColor = const Color(0xFF0D9488).withValues(alpha: 0.04);

    if (isCollapsed) {
      return Tooltip(
        message: label,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: InkWell(
            onTap: () {
              if (isMobile) {
                Navigator.of(context).pop();
              }
              if (onTap != null) {
                onTap!();
              } else {
                context.go(route);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: isActive ? activeBgColor : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: isActive ? activeTextColor : inactiveTextColor,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? activeBgColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? const Border(
                  left: BorderSide(color: Color(0xFF0D9488), width: 4),
                )
              : null,
        ),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          selected: isActive,
          selectedTileColor: Colors.transparent,
          hoverColor: hoverColor,
          leading: Icon(
            icon,
            color: isActive ? activeTextColor : inactiveTextColor,
          ),
          title: Text(
            label,
            style: TextStyle(
              color: isActive ? activeTextColor : inactiveTextColor,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
            ),
          ),
          onTap: () {
            if (isMobile) {
              Navigator.of(context).pop();
            }
            if (onTap != null) {
              onTap!();
            } else {
              context.go(route);
            }
          },
        ),
      ),
    );
  }
}
