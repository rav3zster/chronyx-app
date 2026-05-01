import 'package:chronyx/core/routing/app_routes.dart';
import 'package:chronyx/features/time_tracking/presentation/pages/time_tracking_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.timeTracking,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.timeTracking,
        builder: (context, state) => const TimeTrackingPage(),
      ),
    ],
  );
});
