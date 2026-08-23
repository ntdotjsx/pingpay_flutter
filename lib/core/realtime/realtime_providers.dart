import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/bills/providers/bill_provider.dart';
import '../../features/friends/providers/friends_provider.dart';
import '../../features/payments/providers/payment_providers.dart';
import '../config/app_config.dart';
import 'realtime_connection_state.dart';
import 'realtime_event.dart';
import 'realtime_service.dart';

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final storage = ref.watch(dioClientProvider).secureStorage;
  final service = RealtimeService(
    storage: storage,
    url: AppConfig.realtimeUrl,
  );
  ref.onDispose(service.dispose);
  return service;
});

final realtimeConnectionStateProvider =
    StreamProvider<RealtimeConnectionStatus>((ref) {
  final service = ref.watch(realtimeServiceProvider);
  return service.connectionState;
});

final realtimeControllerProvider = Provider<RealtimeController>((ref) {
  final service = ref.watch(realtimeServiceProvider);
  final controller = RealtimeController(ref, service);
  ref.onDispose(controller.dispose);
  return controller;
});

class RealtimeController {
  final Ref _ref;
  final RealtimeService _service;
  final RealtimeEventDeduper _deduper = RealtimeEventDeduper();
  late final StreamSubscription<RealtimeEvent> _eventSubscription;

  RealtimeController(this._ref, this._service) {
    _eventSubscription = _service.events.listen(_handleEvent);
    _ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        _service.connect();
      } else if (previous?.status == AuthStatus.authenticated) {
        _deduper.clear();
        _service.disconnect();
      }
    }, fireImmediately: true);
  }

  Future<void> onAppResumed() async {
    final authState = _ref.read(authStateProvider);
    if (authState.status == AuthStatus.authenticated) {
      await _service.reconnectNow();
      _recoverMissedState();
    }
  }

  void dispose() {
    _eventSubscription.cancel();
  }

  void _handleEvent(RealtimeEvent event) {
    if (!_deduper.shouldProcess(event)) return;

    if (kDebugMode) {
      debugPrint('[Realtime] event ${event.type} ${event.resourceId ?? ''}');
    }

    switch (event.type) {
      case 'connection.ready':
      case 'sync.required':
        _recoverMissedState();
        break;
      case 'friend.request.created':
      case 'friend.request.accepted':
      case 'friend.request.rejected':
      case 'friend.request.cancelled':
      case 'friend.removed':
      case 'friend.blocked':
      case 'friend.unblocked':
        _refreshFriends(event);
        break;
      case 'bill.created':
      case 'bill.updated':
      case 'bill.deleted':
      case 'bill.member.added':
      case 'bill.member.removed':
      case 'bill.transaction.created':
      case 'bill.transaction.updated':
      case 'bill.transaction.deleted':
      case 'bill.payment.updated':
      case 'bill.status.updated':
        _refreshBillState(event);
        break;
      case 'notification.created':
        _refreshPaymentSummaries();
        break;
      default:
        if (kDebugMode) {
          debugPrint('[Realtime] unknown event ignored: ${event.type}');
        }
    }
  }

  void _refreshFriends(RealtimeEvent event) {
    // ignore: unused_result
    _ref.refresh(friendsListProvider);
    // ignore: unused_result
    _ref.refresh(incomingFriendRequestsProvider);
    // ignore: unused_result
    _ref.refresh(outgoingFriendRequestsProvider);

    final friendshipId = event.data['friendshipId']?.toString();
    if (friendshipId != null && friendshipId.isNotEmpty) {
      // ignore: unused_result
      _ref.refresh(friendDetailProvider(friendshipId));
      // ignore: unused_result
      _ref.refresh(removalCheckProvider(friendshipId));
    }
  }

  void _refreshBillState(RealtimeEvent event) {
    final billId = event.resourceId ?? event.data['billId']?.toString();
    // ignore: unused_result
    _ref.refresh(myBillsProvider);

    if (billId != null && billId.isNotEmpty) {
      // ignore: unused_result
      _ref.refresh(billDetailProvider(billId));
      // ignore: unused_result
      _ref.refresh(billPaymentHistoryProvider(billId));
    }

    _refreshPaymentSummaries();
  }

  void _refreshPaymentSummaries() {
    _ref.read(userDebtsProvider.notifier).loadDebts(showLoading: false);
    _ref
        .read(userReceivablesProvider.notifier)
        .loadReceivables(showLoading: false);
    _ref.read(authStateProvider.notifier).refreshUser();
  }

  void _recoverMissedState() {
    // ignore: unused_result
    _ref.refresh(friendsListProvider);
    // ignore: unused_result
    _ref.refresh(incomingFriendRequestsProvider);
    // ignore: unused_result
    _ref.refresh(outgoingFriendRequestsProvider);
    // ignore: unused_result
    _ref.refresh(myBillsProvider);
    _refreshPaymentSummaries();
  }
}
