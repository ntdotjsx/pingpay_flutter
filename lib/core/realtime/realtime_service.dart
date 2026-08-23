import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../storage/secure_storage.dart';
import 'realtime_connection_state.dart';
import 'realtime_event.dart';

class RealtimeService {
  final SecureStorageService _storage;
  final String _url;

  WebSocket? _socket;
  StreamSubscription? _socketSubscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _manualDisconnect = false;
  bool _hasConnectedOnce = false;
  int _reconnectAttempt = 0;

  final _events = StreamController<RealtimeEvent>.broadcast();
  final _connectionState =
      StreamController<RealtimeConnectionStatus>.broadcast();

  RealtimeConnectionStatus _status = RealtimeConnectionStatus.disconnected;

  RealtimeService({
    required SecureStorageService storage,
    required String url,
  })  : _storage = storage,
        _url = url;

  Stream<RealtimeEvent> get events => _events.stream;
  Stream<RealtimeConnectionStatus> get connectionState =>
      _connectionState.stream;
  RealtimeConnectionStatus get status => _status;

  Future<void> connect() async {
    if (_status == RealtimeConnectionStatus.connected ||
        _status == RealtimeConnectionStatus.connecting) {
      return;
    }

    _manualDisconnect = false;
    _setStatus(
      _hasConnectedOnce
          ? RealtimeConnectionStatus.reconnecting
          : RealtimeConnectionStatus.connecting,
    );

    final token = await _storage.getAccessToken();
    if (token == null || token.isEmpty) {
      _setStatus(RealtimeConnectionStatus.disconnected);
      return;
    }

    try {
      await _cleanupSocket();
      final socket = await WebSocket.connect(
        _url,
        headers: {'Authorization': 'Bearer $token'},
      );
      _socket = socket;
      _hasConnectedOnce = true;
      _reconnectAttempt = 0;
      _setStatus(RealtimeConnectionStatus.connected);
      _startHeartbeat();

      _socketSubscription = socket.listen(
        _handleMessage,
        onDone: _handleClosed,
        onError: (Object error, StackTrace stackTrace) {
          if (kDebugMode) {
            debugPrint('[Realtime] socket error: $error');
          }
          _handleClosed();
        },
        cancelOnError: true,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[Realtime] connect failed: $error');
      }
      _scheduleReconnect();
    }
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    await _cleanupSocket();
    _setStatus(RealtimeConnectionStatus.disconnected);
  }

  Future<void> reconnectNow() async {
    if (_manualDisconnect) return;
    _reconnectTimer?.cancel();
    await _cleanupSocket();
    await connect();
  }

  void send(Map<String, dynamic> payload) {
    final socket = _socket;
    if (socket == null || _status != RealtimeConnectionStatus.connected) {
      return;
    }
    socket.add(jsonEncode(payload));
  }

  void dispose() {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _cleanupSocket();
    _events.close();
    _connectionState.close();
  }

  void _handleMessage(dynamic message) {
    if (message == 'pong') return;
    if (message is! String) return;

    try {
      final decoded = jsonDecode(message);
      if (decoded is! Map<String, dynamic>) return;
      final event = RealtimeEvent.fromJson(decoded);
      if (event.type.isEmpty) return;
      _events.add(event);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[Realtime] malformed event ignored: $error');
      }
    }
  }

  void _handleClosed() {
    if (_manualDisconnect) {
      _setStatus(RealtimeConnectionStatus.disconnected);
      return;
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_manualDisconnect) return;
    _heartbeatTimer?.cancel();
    _setStatus(RealtimeConnectionStatus.reconnecting);

    final seconds = _backoffSeconds(_reconnectAttempt);
    _reconnectAttempt += 1;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: seconds), connect);
  }

  int _backoffSeconds(int attempt) {
    final value = 1 << attempt;
    return value > 30 ? 30 : value;
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final socket = _socket;
      if (socket == null || _status != RealtimeConnectionStatus.connected) {
        return;
      }
      socket.add('ping');
    });
  }

  Future<void> _cleanupSocket() async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await _socket?.close();
    _socket = null;
  }

  void _setStatus(RealtimeConnectionStatus status) {
    _status = status;
    if (!_connectionState.isClosed) {
      _connectionState.add(status);
    }
  }
}
