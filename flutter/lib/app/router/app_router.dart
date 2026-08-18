import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/models/auth_models.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/pdpa/presentation/pdpa_screen.dart';
import '../../features/pin/presentation/pin_setup_screen.dart';
import '../../features/profile/presentation/username_setup_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/bills/presentation/create_bill_screen.dart';
import '../../features/bills/presentation/bill_detail_screen.dart';
import '../../features/friends/screens/friends_screen.dart';
import '../../features/friends/screens/add_friend_screen.dart';
import '../../features/friends/screens/friend_detail_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authStateProvider.notifier);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(authNotifier.stream),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/pdpa', builder: (context, state) => const PdpaScreen()),
      GoRoute(
        path: '/pin/setup',
        builder: (context, state) => const PinSetupScreen(),
      ),
      GoRoute(
        path: '/profile/setup',
        builder: (context, state) => const UsernameSetupScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/bills/create',
        builder: (context, state) => const CreateBillScreen(),
      ),
      GoRoute(
        path: '/bills/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return BillDetailScreen(billId: id);
        },
      ),
      GoRoute(
        path: '/friends',
        builder: (context, state) => const FriendsScreen(),
      ),
      GoRoute(
        path: '/friends/add',
        builder: (context, state) => const AddFriendScreen(),
      ),
      GoRoute(
        path: '/friends/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return FriendDetailScreen(friendshipId: id);
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
          if (currentLoc == '/login' ||
              currentLoc == '/splash' ||
              currentLoc == '/pdpa' ||
              currentLoc == '/pin/setup' ||
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
