import 'package:app/data/provider_functions_service.dart';
import 'package:app/data/sharing_functions_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('ProviderFunctionsService', () {
    test(
      'getProviderConnection returns offline response without client',
      () async {
        final service = ProviderFunctionsService(null);
        final response = await service.getProviderConnection(
          plantId: 'plant-1',
        );

        expect(response['ok'], isTrue);
        expect(response['offline'], isTrue);
      },
    );

    test('getProviderConnection invokes provider_connection_get', () async {
      String? invokedName;
      Map<String, dynamic>? invokedBody;
      final service = ProviderFunctionsService(
        _fakeClient,
        invoke: (functionName, {body}) async {
          invokedName = functionName;
          invokedBody = body;
          return FunctionResponse(
            data: {
              'ok': true,
              'config': {'apiId': 'id'},
            },
            status: 200,
          );
        },
      );

      final response = await service.getProviderConnection(plantId: 'plant-1');

      expect(invokedName, 'provider_connection_get');
      expect(invokedBody, {'plantId': 'plant-1'});
      expect(response['ok'], isTrue);
    });

    test(
      'upsertProviderConnection returns offline response without client',
      () async {
        final service = ProviderFunctionsService(null);
        final response = await service.upsertProviderConnection(
          plantId: 'plant-1',
          displayName: 'Test',
          inverterSn: 'SN123',
          apiId: 'id',
          apiSecret: 'secret',
        );

        expect(response['ok'], isTrue);
        expect(response['offline'], isTrue);
      },
    );

    test(
      'upsertProviderConnection sends expected payload and returns data',
      () async {
        String? invokedName;
        Map<String, dynamic>? invokedBody;
        final service = ProviderFunctionsService(
          _fakeClient,
          invoke: (functionName, {body}) async {
            invokedName = functionName;
            invokedBody = body;
            return FunctionResponse(
              data: {'ok': true, 'saved': true},
              status: 200,
            );
          },
        );

        final response = await service.upsertProviderConnection(
          plantId: 'plant-1',
          displayName: 'Main inverter',
          inverterSn: 'INV-42',
          apiId: 'api-id',
          apiSecret: 'api-secret',
          apiBaseUrl: 'https://api.example.com',
        );

        expect(invokedName, 'provider_connection_upsert');
        expect(invokedBody, {
          'plantId': 'plant-1',
          'displayName': 'Main inverter',
          'inverterSn': 'INV-42',
          'apiId': 'api-id',
          'apiSecret': 'api-secret',
          'apiBaseUrl': 'https://api.example.com',
        });
        expect(response, {'ok': true, 'saved': true});
      },
    );

    test('upsertProviderConnection includes stationId when provided', () async {
      Map<String, dynamic>? invokedBody;
      final service = ProviderFunctionsService(
        _fakeClient,
        invoke: (functionName, {body}) async {
          invokedBody = body;
          return FunctionResponse(data: {'ok': true}, status: 200);
        },
      );

      await service.upsertProviderConnection(
        plantId: 'plant-1',
        displayName: 'Main inverter',
        inverterSn: 'INV-42',
        stationId: '123456',
        apiId: 'api-id',
        apiSecret: 'api-secret',
      );

      expect(invokedBody?['stationId'], '123456');
    });

    test(
      'testProviderConnection returns offline message without client',
      () async {
        final service = ProviderFunctionsService(null);
        final response = await service.testProviderConnection(
          plantId: 'plant-1',
        );

        expect(response['ok'], isTrue);
        expect(response['offline'], isTrue);
        expect(response['message'], isNotEmpty);
      },
    );

    test('testProviderConnection omits empty optional fields', () async {
      Map<String, dynamic>? invokedBody;
      final service = ProviderFunctionsService(
        _fakeClient,
        invoke: (functionName, {body}) async {
          invokedBody = body;
          return FunctionResponse(data: {'ok': true}, status: 200);
        },
      );

      await service.testProviderConnection(
        plantId: 'plant-1',
        inverterSn: '',
        apiId: null,
        apiSecret: 'secret',
        apiBaseUrl: '',
      );

      expect(invokedBody, {'plantId': 'plant-1', 'apiSecret': 'secret'});
    });

    test('applyControl returns offline response without client', () async {
      final service = ProviderFunctionsService(null);
      final response = await service.applyControl(
        plantId: 'plant-1',
        peakShavingW: 2000,
        gridChargingAllowed: true,
      );

      expect(response['ok'], isTrue);
      expect(response['offline'], isTrue);
    });

    test(
      'applyControl returns unexpected-response payload for non-map data',
      () async {
        final service = ProviderFunctionsService(
          _fakeClient,
          invoke: (functionName, {body}) async =>
              FunctionResponse(data: 'not-a-map', status: 200),
        );

        final response = await service.applyControl(
          plantId: 'plant-1',
          peakShavingW: 2000,
          gridChargingAllowed: true,
        );

        expect(response['ok'], isFalse);
        expect(response['error'], 'Unexpected response');
      },
    );

    test('getBatterySoc returns offline response without client', () async {
      final service = ProviderFunctionsService(null);
      final response = await service.getBatterySoc(plantId: 'plant-1');

      expect(response['ok'], isTrue);
      expect(response['offline'], isTrue);
      expect(response['batteryPercentage'], 68);
    });

    test('getBatterySoc invokes provider_battery_soc', () async {
      String? invokedName;
      Map<String, dynamic>? invokedBody;
      final service = ProviderFunctionsService(
        _fakeClient,
        invoke: (functionName, {body}) async {
          invokedName = functionName;
          invokedBody = body;
          return FunctionResponse(
            data: {'ok': true, 'batteryPercentage': 55},
            status: 200,
          );
        },
      );

      final response = await service.getBatterySoc(plantId: 'plant-1');

      expect(invokedName, 'provider_battery_soc');
      expect(invokedBody, {'plantId': 'plant-1'});
      expect(response['ok'], isTrue);
      expect(response['batteryPercentage'], 55);
    });
  });

  group('SharingFunctionsService', () {
    test('listSharing returns empty snapshot for local plant id', () async {
      final service = SharingFunctionsService(null);
      final snapshot = await service.listSharing(plantId: 'local-plant-1');

      expect(snapshot.members, isEmpty);
      expect(snapshot.invites, isEmpty);
    });

    test(
      'listSharing maps members and invites from response payload',
      () async {
        final service = SharingFunctionsService(
          _fakeClient,
          invoke: (functionName, {body}) async => FunctionResponse(
            data: {
              'members': [
                {
                  'authUserId': 'user-1',
                  'role': 'owner',
                  'email': 'owner@example.com',
                  'createdAt': '2026-02-10T12:00:00Z',
                },
              ],
              'invites': [
                {
                  'id': 'invite-1',
                  'invitedEmail': 'invitee@example.com',
                  'role': 'member',
                  'status': 'pending',
                  'expiresAt': '2026-02-20T12:00:00Z',
                  'createdAt': '2026-02-10T12:00:00Z',
                },
              ],
            },
            status: 200,
          ),
        );

        final snapshot = await service.listSharing(plantId: 'plant-1');

        expect(snapshot.members.single.authUserId, 'user-1');
        expect(snapshot.invites.single.id, 'invite-1');
      },
    );

    test(
      'invite and acceptInvite return offline responses without client',
      () async {
        final service = SharingFunctionsService(null);
        final inviteResponse = await service.invite(
          plantId: 'plant-1',
          invitedEmail: 'user@example.com',
        );
        final acceptResponse = await service.acceptInvite(token: 'token-1');

        expect(inviteResponse['ok'], isTrue);
        expect(inviteResponse['offline'], isTrue);
        expect(acceptResponse['ok'], isTrue);
        expect(acceptResponse['offline'], isTrue);
      },
    );

    test('invite throws for unexpected response shape', () async {
      final service = SharingFunctionsService(
        _fakeClient,
        invoke: (functionName, {body}) async =>
            FunctionResponse(data: 'bad', status: 200),
      );

      expect(
        () => service.invite(plantId: 'plant-1', invitedEmail: 'u@e.com'),
        throwsException,
      );
    });

    test(
      'revoke/remove/accept invoke expected function names and payloads',
      () async {
        final calls = <Map<String, dynamic>>[];
        final service = SharingFunctionsService(
          _fakeClient,
          invoke: (functionName, {body}) async {
            calls.add({'name': functionName, 'body': body ?? {}});
            return FunctionResponse(data: {'ok': true}, status: 200);
          },
        );

        await service.revokeInvite(plantId: 'plant-1', inviteId: 'invite-1');
        await service.removeMember(plantId: 'plant-1', memberUserId: 'user-2');
        await service.acceptInvite(token: 'token-1');

        expect(calls[0], {
          'name': 'plant_sharing_revoke_invite',
          'body': {'plantId': 'plant-1', 'inviteId': 'invite-1'},
        });
        expect(calls[1], {
          'name': 'plant_sharing_remove_member',
          'body': {'plantId': 'plant-1', 'memberUserId': 'user-2'},
        });
        expect(calls[2], {
          'name': 'plant_sharing_accept_invite',
          'body': {'token': 'token-1'},
        });
      },
    );

    test('PlantMemberEntry and PlantInviteEntry parse expected fields', () {
      final member = PlantMemberEntry.fromMap({
        'authUserId': 'user-1',
        'role': 'owner',
        'email': 'owner@example.com',
        'createdAt': '2026-02-10T12:00:00Z',
      });
      final invite = PlantInviteEntry.fromMap({
        'id': 'invite-1',
        'invitedEmail': 'invitee@example.com',
        'role': 'member',
        'status': 'pending',
        'expiresAt': '2026-02-20T12:00:00Z',
        'createdAt': '2026-02-10T12:00:00Z',
      });

      expect(member.authUserId, 'user-1');
      expect(member.createdAt, isNotNull);
      expect(invite.id, 'invite-1');
      expect(invite.expiresAt, isNotNull);
    });
  });
}

final _fakeClient = SupabaseClient('https://example.supabase.co', 'anon-key');
