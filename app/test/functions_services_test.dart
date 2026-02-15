import 'package:app/data/provider_functions_service.dart';
import 'package:app/data/sharing_functions_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProviderFunctionsService', () {
    const service = ProviderFunctionsService(null);

    test('upsertProviderConnection returns offline response without client', () async {
      final response = await service.upsertProviderConnection(
        plantId: 'plant-1',
        displayName: 'Test',
        inverterSn: 'SN123',
        apiId: 'id',
        apiSecret: 'secret',
      );

      expect(response['ok'], isTrue);
      expect(response['offline'], isTrue);
    });

    test('testProviderConnection returns offline message without client', () async {
      final response = await service.testProviderConnection(plantId: 'plant-1');

      expect(response['ok'], isTrue);
      expect(response['offline'], isTrue);
      expect(response['message'], isNotEmpty);
    });

    test('applyControl returns offline response without client', () async {
      final response = await service.applyControl(
        plantId: 'plant-1',
        peakShavingW: 2000,
        gridChargingAllowed: true,
      );

      expect(response['ok'], isTrue);
      expect(response['offline'], isTrue);
    });
  });

  group('SharingFunctionsService', () {
    const service = SharingFunctionsService(null);

    test('listSharing returns empty snapshot for local plant id', () async {
      final snapshot = await service.listSharing(plantId: 'local-plant-1');

      expect(snapshot.members, isEmpty);
      expect(snapshot.invites, isEmpty);
    });

    test('invite and acceptInvite return offline responses without client', () async {
      final inviteResponse = await service.invite(
        plantId: 'plant-1',
        invitedEmail: 'user@example.com',
      );
      final acceptResponse = await service.acceptInvite(token: 'token-1');

      expect(inviteResponse['ok'], isTrue);
      expect(inviteResponse['offline'], isTrue);
      expect(acceptResponse['ok'], isTrue);
      expect(acceptResponse['offline'], isTrue);
    });

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
