import 'package:flutter_test/flutter_test.dart';
import 'package:game/features/game_two/domain/entities/mafia_lobby_player.dart';
import 'package:game/features/game_two/domain/entities/mafia_role.dart';
import 'package:game/features/game_two/domain/logic/distribute_mafia_roles.dart';

void main() {
  const host = MafiaLobbyPlayer(id: 'local', name: 'Host', isHost: true);
  const guest = MafiaLobbyPlayer(id: 'guest-1', name: 'Guest', isHost: false);

  test('rejects empty roster', () {
    expect(
      () => distributeMafiaRoles([]),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('rejects single player', () {
    expect(
      () => distributeMafiaRoles([host]),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('assigns Boss and Citizen for two players', () {
    final result = distributeMafiaRoles([host, guest]);

    expect(result, hasLength(2));
    expect(
      result.map((player) => player.role).toSet(),
      {MafiaRole.mafiaBoss, MafiaRole.citizen},
    );
    expect(result.map((player) => player.id).toSet(), {'local', 'guest-1'});
  });

  test('assigns Boss, Detective, and Doctor for three players', () {
    const guestTwo = MafiaLobbyPlayer(
      id: 'guest-2',
      name: 'Guest 2',
      isHost: false,
    );

    final result = distributeMafiaRoles([host, guest, guestTwo]);

    expect(result, hasLength(3));
    expect(
      result.map((player) => player.role).toSet(),
      {MafiaRole.mafiaBoss, MafiaRole.detective, MafiaRole.doctor},
    );
  });
}
