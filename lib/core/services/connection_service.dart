import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';

enum AppConnectionState {
  online,
  offline,
  reconnecting,
  syncing,
  syncError,
}

class ConnectionStatus {
  final AppConnectionState state;
  final String message;
  final DateTime lastChecked;
  final int pendingCount;

  const ConnectionStatus({
    this.state = AppConnectionState.online,
    this.message = 'ONLINE',
    required this.lastChecked,
    this.pendingCount = 0,
  });

  ConnectionStatus copyWith({
    AppConnectionState? state,
    String? message,
    DateTime? lastChecked,
    int? pendingCount,
  }) {
    return ConnectionStatus(
      state: state ?? this.state,
      message: message ?? this.message,
      lastChecked: lastChecked ?? this.lastChecked,
      pendingCount: pendingCount ?? this.pendingCount,
    );
  }
}

class ConnectionService extends StateNotifier<ConnectionStatus> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _heartbeatTimer;
  bool _isDisposed = false;

  ConnectionService()
      : super(ConnectionStatus(
          state: AppConnectionState.online,
          message: 'ONLINE',
          lastChecked: DateTime.now(),
        )) {
    _init();
  }

  void _init() {
    // Listen for connectivity hardware changes
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final isDisconnected = results.contains(ConnectivityResult.none) || results.isEmpty;
      if (isDisconnected) {
        setOffline('OFFLINE — Changes will sync when connection returns');
      } else {
        // Network interface available, verify real reachability
        checkConnectivity();
      }
    });

    // Periodic heartbeat every 20 seconds
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (state.state != AppConnectionState.syncing) {
        checkConnectivity(silent: true);
      }
    });

    // Initial check
    checkConnectivity();
  }

  Future<bool> checkConnectivity({bool silent = false}) async {
    if (_isDisposed) return false;

    if (!silent && state.state == AppConnectionState.offline) {
      state = state.copyWith(
        state: AppConnectionState.reconnecting,
        message: 'RECONNECTING...',
      );
    }

    try {
      // Fast ping Supabase REST endpoint
      final url = Uri.parse('${SupabaseConfig.url}/rest/v1/');
      final response = await http.get(
        url,
        headers: {
          'apikey': SupabaseConfig.anonKey,
        },
      ).timeout(const Duration(seconds: 4));

      // Supabase responds with 200 or 401/404 if reached, confirming internet connectivity
      if (response.statusCode >= 200 && response.statusCode < 500) {
        if (state.state != AppConnectionState.syncing) {
          state = state.copyWith(
            state: AppConnectionState.online,
            message: state.pendingCount > 0 ? 'SYNC COMPLETE' : 'ONLINE',
            lastChecked: DateTime.now(),
          );
        }
        return true;
      } else {
        setOffline('OFFLINE — Server unreachable');
        return false;
      }
    } catch (_) {
      setOffline('OFFLINE — Changes will sync when connection returns');
      return false;
    }
  }

  void setOnline([String msg = 'ONLINE']) {
    if (_isDisposed) return;
    state = state.copyWith(
      state: AppConnectionState.online,
      message: msg,
      lastChecked: DateTime.now(),
    );
  }

  void setOffline([String msg = 'OFFLINE — Changes will sync when connection returns']) {
    if (_isDisposed) return;
    state = state.copyWith(
      state: AppConnectionState.offline,
      message: msg,
      lastChecked: DateTime.now(),
    );
  }

  void setSyncing([String msg = 'SYNCING...']) {
    if (_isDisposed) return;
    state = state.copyWith(
      state: AppConnectionState.syncing,
      message: msg,
      lastChecked: DateTime.now(),
    );
  }

  void setSyncError([String msg = 'SYNC_ERROR — Tap to view pending']) {
    if (_isDisposed) return;
    state = state.copyWith(
      state: AppConnectionState.syncError,
      message: msg,
      lastChecked: DateTime.now(),
    );
  }

  void updatePendingCount(int count) {
    if (_isDisposed) return;
    state = state.copyWith(pendingCount: count);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _connectivitySub?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}

final connectionServiceProvider = StateNotifierProvider<ConnectionService, ConnectionStatus>((ref) {
  return ConnectionService();
});
