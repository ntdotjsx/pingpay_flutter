import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/services/notification_service.dart';
import '../models/auth_models.dart';
import '../repositories/auth_repository.dart';

final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return AuthRepository(dioClient);
});

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final bool isLoading;
  final bool isLocked;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isLoading = false,
    this.isLocked = false,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    bool? isLoading,
    bool? isLocked,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isLocked: isLocked ?? this.isLocked,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(const AuthState()) {
    checkSession();
  }

  void forceUnauthenticated([String? reason]) {
    state = AuthState(
      status: AuthStatus.unauthenticated,
      user: null,
      isLocked: false,
      errorMessage: reason,
    );
  }

  void lockApp() {
    // Only lock if user is authenticated and has completed onboarding
    if (state.status == AuthStatus.authenticated &&
        state.user?.onboardingState == OnboardingState.completed &&
        !state.isLocked) {
      state = state.copyWith(isLocked: true);
    }
  }

  void unlockApp() {
    state = state.copyWith(isLocked: false, errorMessage: null);
  }

  Future<bool> verifyPin(String pin) async {
    try {
      final success = await _repo.verifyPin(pin);
      if (success) {
        unlockApp();
        return true;
      }
      return false;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> checkSession() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _repo.getCurrentUser();
      final shouldLock = user.onboardingState == OnboardingState.completed;
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        isLocked: shouldLock,
        isLoading: false,
      );
      _syncFcmToken();
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isLoading: false,
        isLocked: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _syncFcmToken() async {
    String? token = NotificationService.currentFcmToken;
    if (token == null) {
      try {
        token = await FirebaseMessaging.instance.getToken();
        NotificationService.currentFcmToken = token;
      } catch (e) {
        debugPrint('Could not retrieve FCM token directly: $e');
      }
    }

    if (token != null) {
      try {
        await _repo.registerDeviceToken(token);
        debugPrint('FCM Token & Device Specs synced to backend successfully.');
      } catch (e) {
        debugPrint('Failed to sync FCM token to backend: $e');
      }
    }
  }

  Future<void> authenticateWithGoogleTokens({
    String? idToken,
    String? accessToken,
    String? mockGoogleId,
    String? mockEmail,
    String? mockDisplayName,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _repo.verifyGoogleToken(
        idToken: idToken,
        accessToken: accessToken,
        mockGoogleId: mockGoogleId,
        mockEmail: mockEmail,
        mockDisplayName: mockDisplayName,
      );
      final shouldLock = user.onboardingState == OnboardingState.completed;
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        isLocked: shouldLock,
        isLoading: false,
      );
      _syncFcmToken();
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isLoading: false,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> acceptPdpa() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repo.acceptConsent();
      final updatedUser = await _repo.getCurrentUser();
      state = state.copyWith(user: updatedUser, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  Future<void> setupPin(String pin) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repo.setupPin(pin);
      final updatedUser = await _repo.getCurrentUser();
      state = state.copyWith(user: updatedUser, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  Future<void> completeProfile(
    String fullName, {
    String? displayName,
    String? phone,
    String? address,
    String? promptPayId,
    String? bankAccountNumber,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repo.updateProfile(
        displayName: displayName,
        fullName: fullName,
        phoneNumber: phone,
        address: address,
        promptPayId: promptPayId ?? phone,
        bankAccountNumber: bankAccountNumber,
      );
      final updatedUser = await _repo.getCurrentUser();
      state = state.copyWith(user: updatedUser, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  final notifier = AuthNotifier(repo);
  
  // Connect onUnauthorized callback from DioClient to trigger logout
  final dioClient = ref.watch(dioClientProvider);
  dioClient.onUnauthorized = (reason) {
    notifier.forceUnauthenticated(reason);
  };

  return notifier;
});
