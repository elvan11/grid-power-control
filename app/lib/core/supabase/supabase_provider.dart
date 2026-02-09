import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_bootstrap.dart';

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!SupabaseBootstrap.isEnabled || !SupabaseBootstrap.isInitialized) {
    return null;
  }
  return Supabase.instance.client;
});

class AuthRefreshListenable extends ChangeNotifier {
  AuthRefreshListenable(this._client) {
    _subscription = _client?.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  final SupabaseClient? _client;
  StreamSubscription<AuthState>? _subscription;

  bool get isAuthenticated {
    if (_client == null) {
      return true;
    }
    return _client.auth.currentSession != null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final authRefreshListenableProvider = Provider<AuthRefreshListenable>((ref) {
  final listenable = AuthRefreshListenable(ref.watch(supabaseClientProvider));
  ref.onDispose(listenable.dispose);
  return listenable;
});
