import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/animations/app_page_transitions.dart';
import '../../core/widgets/pingpay_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/models/auth_models.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/pdpa/presentation/pdpa_screen.dart';
import '../../features/pin/presentation/pin_setup_screen.dart';
import '../../features/pin/presentation/pin_lock_screen.dart';
import '../../features/profile/presentation/username_setup_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/main_shell_screen.dart';
import '../../features/bills/presentation/create_bill_screen.dart';
import '../../features/bills/presentation/bill_detail_screen.dart';
import '../../features/bills/presentation/my_bills_screen.dart';
import '../../features/friends/screens/friends_screen.dart';
import '../../features/friends/screens/add_friend_screen.dart';
import '../../features/friends/screens/friend_detail_screen.dart';
import '../../features/friends/screens/qr_scan_friend_screen.dart';
import '../../features/payments/presentation/payments_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/rewards/presentation/rewards_store_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authStateProvider.notifier);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(authNotifier.stream),
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => AppPageTransition.fade(
          key: state.pageKey,
          child: const Scaffold(body: PingPayLoadingWidget()),
        ),
      ),
      GoRoute(path: '/login', pageBuilder: (context, state) => AppPageTransition.fade(key: state.pageKey, child: const LoginScreen())),
      GoRoute(path: '/pdpa', pageBuilder: (context, state) => AppPageTransition.fade(key: state.pageKey, child: const PdpaScreen())),
      GoRoute(
        path: '/pin/setup',
        pageBuilder: (context, state) => AppPageTransition.fade(key: state.pageKey, child: const PinSetupScreen()),
      ),
      GoRoute(
        path: '/pin/lock',
        pageBuilder: (context, state) => AppPageTransition.fade(key: state.pageKey, child: const PinLockScreen()),
      ),
      GoRoute(
        path: '/profile/setup',
        pageBuilder: (context, state) => AppPageTransition.fade(key: state.pageKey, child: const UsernameSetupScreen()),
      ),
      // Persistent Shell Navigation for 5 Main Tabs (Always shows BottomNavigationBar)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScreen(navigationShell: navigationShell);
        },
        branches: [
          // Tab 0: Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // Tab 1: Payments & Debts
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/payments',
                builder: (context, state) {
                  final tabStr = state.uri.queryParameters['tab'];
                  final initialTab =
                      tabStr == 'receivables' || tabStr == '1' ? 1 : 0;
                  return PaymentsScreen(initialTab: initialTab);
                },
              ),
            ],
          ),
          // Tab 2: My Bills
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/bills/my',
                builder: (context, state) => const MyBillsScreen(),
              ),
            ],
          ),
          // Tab 3: Rewards Store
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rewards',
                builder: (context, state) => const RewardsStoreScreen(),
              ),
            ],
          ),
          // Tab 4: Profile & Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Other Direct Routes (Modals, Details, Setup)
      GoRoute(
        path: '/bills/create',
        pageBuilder: (context, state) => AppPageTransition.modal(key: state.pageKey, child: const CreateBillScreen()),
      ),
      GoRoute(
        path: '/bills/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return AppPageTransition.slide(key: state.pageKey, child: BillDetailScreen(billId: id));
        },
      ),
      GoRoute(
        path: '/friends',
        pageBuilder: (context, state) => AppPageTransition.slide(key: state.pageKey, child: const FriendsScreen()),
      ),
      GoRoute(
        path: '/friends/add',
        pageBuilder: (context, state) => AppPageTransition.slide(key: state.pageKey, child: const AddFriendScreen()),
      ),
      GoRoute(
        path: '/friends/scan',
        pageBuilder: (context, state) => AppPageTransition.modal(key: state.pageKey, child: const QrScanFriendScreen()),
      ),
      GoRoute(
        path: '/friends/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return AppPageTransition.slide(key: state.pageKey, child: FriendDetailScreen(friendshipId: id));
        },
      ),
    ],
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final status = authState.status;
      final currentLoc = state.uri.path;

      // While determining session at startup
      if (status == AuthStatus.unknown) {
        return currentLoc == '/splash' ? null : '/splash';
      }

      // Unauthenticated -> force login
      if (status == AuthStatus.unauthenticated) {
        return currentLoc == '/login' ? null : '/login';
      }

      // Authenticated -> Check Onboarding State Machine
      final user = authState.user;
      if (user == null) return '/login';

      final onboarding = user.onboardingState;

      switch (onboarding) {
        case OnboardingState.unknown:
          return '/splash';

        case OnboardingState.pdpaRequired:
          return currentLoc == '/pdpa' ? null : '/pdpa';

        case OnboardingState.pinRequired:
          return currentLoc == '/pin/setup' ? null : '/pin/setup';

        case OnboardingState.profileRequired:
          return currentLoc == '/profile/setup' ? null : '/profile/setup';

        case OnboardingState.completed:
          if (authState.isLocked) {
            return currentLoc == '/pin/lock' ? null : '/pin/lock';
          }
          if (currentLoc == '/login' ||
              currentLoc == '/splash' ||
              currentLoc == '/pdpa' ||
              currentLoc == '/pin/setup' ||
              currentLoc == '/pin/lock' ||
              currentLoc == '/profile/setup') {
            return '/home';
          }
          return null; // allow /home or /bills/create
      }
    },
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
