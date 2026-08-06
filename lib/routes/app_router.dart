import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../core/widgets/responsive_scaffold.dart';
import '../features/alerts/alerts_screen.dart';
import '../features/anpr/vehicle_export_screen.dart';
import '../features/auth/auth_notifier.dart';
import '../features/auth/login_screen.dart';
import '../features/analytics/analytics_screen.dart';
import '../features/cameras/cameras_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/vehicle_classification/vehicle_classification_screen.dart';
import '../features/vehicle_monitoring/vehicle_monitoring_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/users/users_screen.dart';
import '../features/support/presentation/screens/support_screen.dart';
import '../features/support/presentation/screens/support_ticket_details_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable: GoRouterRefreshStream(
      ref.watch(authNotifierProvider.notifier).authChangeStream,
    ),
    redirect: (context, state) {
      final isInitializing = authState.isInitializing;
      final loggedIn = authState.isAuthenticated;
      final currentLoc = state.uri.toString();
      final isSplashing = currentLoc == AppRoutes.splash;
      final isLoggingIn = currentLoc == AppRoutes.login;

      // 1. While auth state is initializing from storage, stay on Splash
      if (isInitializing) {
        return isSplashing ? null : AppRoutes.splash;
      }

      // 2. If not logged in and not on login page, redirect to Login
      if (!loggedIn) {
        return isLoggingIn ? null : AppRoutes.login;
      }

      // 3. If logged in and on Splash or Login page, redirect to Dashboard
      if (loggedIn && (isSplashing || isLoggingIn)) {
        return AppRoutes.dashboard;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(activePath: state.uri.path, child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.vehicleMonitoring,
            builder: (context, state) => const VehicleMonitoringScreen(),
          ),
          GoRoute(
            path: AppRoutes.vehicleClassification,
            builder: (context, state) => const VehicleClassificationScreen(),
          ),
          GoRoute(
            path: AppRoutes.anprRecords,
            builder: (context, state) => const VehicleExportScreen(),
          ),
          GoRoute(
            path: AppRoutes.liveFeed,
            builder: (context, state) =>
                const VehicleMonitoringScreen(isLiveFeed: true),
          ),
          GoRoute(
            path: AppRoutes.cameras,
            builder: (context, state) => const CamerasScreen(),
          ),
          GoRoute(
            path: AppRoutes.alerts,
            builder: (context, state) => const AlertsScreen(),
          ),
          GoRoute(
            path: AppRoutes.reports,
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: AppRoutes.analytics,
            builder: (context, state) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: AppRoutes.users,
            builder: (context, state) => const UsersScreen(),
          ),
          GoRoute(
            path: AppRoutes.support,
            builder: (context, state) => const SupportScreen(),
          ),
          GoRoute(
            path: '/support/:ticketId',
            pageBuilder: (context, state) {
              final ticketId = int.tryParse(
                state.pathParameters['ticketId'] ?? '',
              );
              if (ticketId == null) {
                return const MaterialPage(
                  key: ValueKey('invalid-ticket'),
                  child: Scaffold(body: Center(child: Text('Invalid ticket'))),
                );
              }
              return CustomTransitionPage(
                key: state.pageKey,
                child: SupportTicketDetailsScreen(ticketId: ticketId),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
              );
            },
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<void> stream) {
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<void> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
