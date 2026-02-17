import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_provider.dart';

typedef SharingFunctionInvoke = Future<FunctionResponse> Function(
  String functionName, {
  Map<String, dynamic>? body,
});

class PlantMemberEntry {
  const PlantMemberEntry({
    required this.authUserId,
    required this.role,
    required this.email,
    required this.createdAt,
  });

  final String authUserId;
  final String role;
  final String? email;
  final DateTime? createdAt;

  factory PlantMemberEntry.fromMap(Map<String, dynamic> map) {
    return PlantMemberEntry(
      authUserId: map['authUserId'] as String,
      role: map['role'] as String,
      email: map['email'] as String?,
      createdAt: map['createdAt'] == null
          ? null
          : DateTime.tryParse(map['createdAt'] as String),
    );
  }
}

class PlantInviteEntry {
  const PlantInviteEntry({
    required this.id,
    required this.invitedEmail,
    required this.role,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
  });

  final String id;
  final String invitedEmail;
  final String role;
  final String status;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  factory PlantInviteEntry.fromMap(Map<String, dynamic> map) {
    return PlantInviteEntry(
      id: map['id'] as String,
      invitedEmail: map['invitedEmail'] as String,
      role: map['role'] as String,
      status: map['status'] as String,
      expiresAt: map['expiresAt'] == null
          ? null
          : DateTime.tryParse(map['expiresAt'] as String),
      createdAt: map['createdAt'] == null
          ? null
          : DateTime.tryParse(map['createdAt'] as String),
    );
  }
}

class PlantSharingSnapshot {
  const PlantSharingSnapshot({required this.members, required this.invites});

  final List<PlantMemberEntry> members;
  final List<PlantInviteEntry> invites;
}

class SharingFunctionsService {
  SharingFunctionsService(this._client, {SharingFunctionInvoke? invoke})
    : _invoke =
          invoke ??
          ((functionName, {body}) =>
              _client!.functions.invoke(functionName, body: body));

  final SupabaseClient? _client;
  final SharingFunctionInvoke _invoke;

  Future<PlantSharingSnapshot> listSharing({required String plantId}) async {
    if (_client == null || plantId.startsWith('local-')) {
      return PlantSharingSnapshot(members: const [], invites: const []);
    }

    final response = await _invoke('plant_sharing_list', body: {'plantId': plantId});
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Unexpected response from plant_sharing_list');
    }

    final members = ((data['members'] as List<dynamic>? ?? const <dynamic>[]))
        .map((entry) => PlantMemberEntry.fromMap(entry as Map<String, dynamic>))
        .toList();
    final invites = ((data['invites'] as List<dynamic>? ?? const <dynamic>[]))
        .map((entry) => PlantInviteEntry.fromMap(entry as Map<String, dynamic>))
        .toList();

    return PlantSharingSnapshot(members: members, invites: invites);
  }

  Future<Map<String, dynamic>> invite({
    required String plantId,
    required String invitedEmail,
    String role = 'member',
  }) async {
    if (_client == null || plantId.startsWith('local-')) {
      return {'ok': true, 'offline': true};
    }
    final response = await _invoke(
      'plant_sharing_invite',
      body: {'plantId': plantId, 'invitedEmail': invitedEmail, 'role': role},
    );
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Unexpected response from plant_sharing_invite');
  }

  Future<void> revokeInvite({
    required String plantId,
    required String inviteId,
  }) async {
    if (_client == null || plantId.startsWith('local-')) {
      return;
    }
    await _invoke(
      'plant_sharing_revoke_invite',
      body: {'plantId': plantId, 'inviteId': inviteId},
    );
  }

  Future<void> removeMember({
    required String plantId,
    required String memberUserId,
  }) async {
    if (_client == null || plantId.startsWith('local-')) {
      return;
    }
    await _invoke(
      'plant_sharing_remove_member',
      body: {'plantId': plantId, 'memberUserId': memberUserId},
    );
  }

  Future<Map<String, dynamic>> acceptInvite({required String token}) async {
    if (_client == null) {
      return {'ok': true, 'offline': true};
    }
    final response = await _invoke(
      'plant_sharing_accept_invite',
      body: {'token': token},
    );
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Unexpected response from plant_sharing_accept_invite');
  }
}

final sharingFunctionsServiceProvider = Provider<SharingFunctionsService>((
  ref,
) {
  return SharingFunctionsService(ref.watch(supabaseClientProvider));
});
