import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_provider.dart';

class ProviderFunctionsService {
  ProviderFunctionsService(this._client);

  final SupabaseClient? _client;

  Future<Map<String, dynamic>> upsertProviderConnection({
    required String plantId,
    required String displayName,
    required String inverterSn,
    required String apiId,
    required String apiSecret,
    String? apiBaseUrl,
  }) async {
    if (_client == null) {
      return {'ok': true, 'offline': true};
    }

    final response = await _client.functions.invoke(
      'provider_connection_upsert',
      body: {
        'plantId': plantId,
        'displayName': displayName,
        'inverterSn': inverterSn,
        'apiId': apiId,
        'apiSecret': apiSecret,
        if (apiBaseUrl != null && apiBaseUrl.isNotEmpty)
          'apiBaseUrl': apiBaseUrl,
      },
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return {'ok': false, 'error': 'Unexpected response'};
  }

  Future<Map<String, dynamic>> testProviderConnection({
    required String plantId,
    String? inverterSn,
    String? apiId,
    String? apiSecret,
    String? apiBaseUrl,
  }) async {
    if (_client == null) {
      return {
        'ok': true,
        'offline': true,
        'message': 'Supabase not configured',
      };
    }

    final response = await _client.functions.invoke(
      'provider_connection_test',
      body: {
        'plantId': plantId,
        if (inverterSn != null && inverterSn.isNotEmpty)
          'inverterSn': inverterSn,
        if (apiId != null && apiId.isNotEmpty) 'apiId': apiId,
        if (apiSecret != null && apiSecret.isNotEmpty) 'apiSecret': apiSecret,
        if (apiBaseUrl != null && apiBaseUrl.isNotEmpty)
          'apiBaseUrl': apiBaseUrl,
      },
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return {'ok': false, 'error': 'Unexpected response'};
  }

  Future<Map<String, dynamic>> applyControl({
    required String plantId,
    required int peakShavingW,
    required bool gridChargingAllowed,
  }) async {
    if (_client == null) {
      return {'ok': true, 'offline': true};
    }

    final response = await _client.functions.invoke(
      'provider_apply_control',
      body: {
        'plantId': plantId,
        'peakShavingW': peakShavingW,
        'gridChargingAllowed': gridChargingAllowed,
      },
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return {'ok': false, 'error': 'Unexpected response'};
  }
}

final providerFunctionsServiceProvider = Provider<ProviderFunctionsService>((
  ref,
) {
  return ProviderFunctionsService(ref.watch(supabaseClientProvider));
});
