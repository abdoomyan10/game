import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game/features/game_one/domain/constants/secret_words.dart';
import 'package:game/features/game_one/domain/entities/game_payload.dart';
import 'package:game/features/game_one/domain/entities/player.dart';
import 'package:game/features/game_one/domain/entities/player_role.dart';
import 'package:game/features/game_one/domain/repositories/game_repository.dart';
import 'package:game/features/game_one/domain/usecases/distribute_roles_usecase.dart';
import 'package:game/features/game_one/domain/usecases/send_game_payload_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockGameRepository extends Mock implements GameRepository {}

class MockSendGamePayloadUseCase extends Mock
    implements SendGamePayloadUseCase {}

void main() {
  late MockGameRepository repository;
  late MockSendGamePayloadUseCase sendGamePayload;
  late DistributeRolesUseCase useCase;

  setUpAll(() {
    registerFallbackValue(
      const SendGamePayloadParams(
        payload: GamePayload(role: PlayerRole.normal, word: 'تفاحة'),
        endpointId: 'fallback',
      ),
    );
  });

  setUp(() {
    repository = MockGameRepository();
    sendGamePayload = MockSendGamePayloadUseCase();
    useCase = DistributeRolesUseCase(repository, sendGamePayload);

    when(() => repository.isHost).thenReturn(true);
    when(() => sendGamePayload(any())).thenAnswer((_) async => const Right(null));
  });

  const players = [
    Player(id: 'local', name: 'المضيف', isHost: true),
    Player(id: 'peer-a', name: 'لاعب ١', isHost: false),
    Player(id: 'peer-b', name: 'لاعب ٢', isHost: false),
  ];

  test('fails when caller is not host', () async {
    when(() => repository.isHost).thenReturn(false);

    final result = await useCase(
      const DistributeRolesParams(players: players, imposterCount: 1),
    );

    expect(result.isLeft(), isTrue);
    verifyNever(() => sendGamePayload(any()));
  });

  test('sends isolated payloads and never sends real word to imposters', () async {
    final captured = <SendGamePayloadParams>[];

    when(() => sendGamePayload(any())).thenAnswer((invocation) async {
      captured.add(invocation.positionalArguments.first as SendGamePayloadParams);
      return const Right(null);
    });

    final result = await useCase(
      const DistributeRolesParams(players: players, imposterCount: 1),
    );

    expect(result.isRight(), isTrue);
    expect(captured, hasLength(2));

    final hostPayload = result.getOrElse(() => throw StateError('expected right')).hostPayload;
    expect(SecretWords.words.contains(hostPayload.word) ||
        hostPayload.word == SecretWords.imposterPlaceholder, isTrue);

    for (final params in captured) {
      if (params.payload.role == PlayerRole.imposter) {
        expect(params.payload.word, SecretWords.imposterPlaceholder);
        expect(params.payload.word, isNot(isIn(SecretWords.words)));
      } else {
        expect(SecretWords.words, contains(params.payload.word));
      }
    }

    final imposterPayloads = captured
        .where((params) => params.payload.role == PlayerRole.imposter)
        .toList();
    final normalPayloads = captured
        .where((params) => params.payload.role == PlayerRole.normal)
        .toList();

    final allRoles = [
      hostPayload.role,
      ...captured.map((params) => params.payload.role),
    ];
    expect(
      allRoles.where((role) => role == PlayerRole.imposter),
      hasLength(1),
    );
    expect(normalPayloads, isNotEmpty);
    expect(normalPayloads.first.payload.word, isNot(SecretWords.imposterPlaceholder));
    expect(imposterPayloads.length + (hostPayload.role.isImposter ? 1 : 0), 1);
  });

  test('assigns exactly N imposters across all players including host', () async {
    final captured = <GamePayload>[];

    when(() => sendGamePayload(any())).thenAnswer((invocation) async {
      final params = invocation.positionalArguments.first as SendGamePayloadParams;
      captured.add(params.payload);
      return const Right(null);
    });

    final result = await useCase(
      const DistributeRolesParams(players: players, imposterCount: 2),
    );

    expect(result.isRight(), isTrue);

    final hostPayload = result.getOrElse(() => throw StateError('expected right')).hostPayload;
    final allPayloads = [...captured, hostPayload];
    final imposterCount =
        allPayloads.where((payload) => payload.role == PlayerRole.imposter).length;

    expect(imposterCount, 2);
  });
}
