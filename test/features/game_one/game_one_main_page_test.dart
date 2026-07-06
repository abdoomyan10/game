import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game/app.dart';
import 'package:game/core/di/injection.dart';
import 'package:game/core/error/failure.dart';
import 'package:game/core/usecase/usecase.dart';
import 'package:game/features/game_one/domain/entities/distribute_roles_result.dart';
import 'package:game/features/game_one/domain/entities/game_payload.dart';
import 'package:game/features/game_one/domain/entities/game_session_event.dart';
import 'package:game/features/game_one/domain/entities/player.dart';
import 'package:game/features/game_one/domain/entities/player_role.dart';
import 'package:game/features/game_one/domain/repositories/game_repository.dart';
import 'package:game/features/game_one/domain/usecases/distribute_roles_usecase.dart';
import 'package:game/features/game_one/domain/usecases/ensure_p2p_permissions_usecase.dart';
import 'package:game/features/game_one/domain/usecases/join_room_usecase.dart';
import 'package:game/features/game_one/domain/usecases/scan_for_rooms_usecase.dart';
import 'package:game/features/game_one/domain/usecases/start_hosting_usecase.dart';
import 'package:game/features/game_one/presentation/bloc/game_one_bloc.dart';
import 'package:game/features/game_one/presentation/pages/game_one_main_page.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockGameRepository extends Mock implements GameRepository {}

class MockEnsureP2pPermissionsUseCase extends Mock
    implements EnsureP2pPermissionsUseCase {}

class MockStartHostingUseCase extends Mock implements StartHostingUseCase {}

class MockScanForRoomsUseCase extends Mock implements ScanForRoomsUseCase {}

class MockJoinRoomUseCase extends Mock implements JoinRoomUseCase {}

class MockDistributeRolesUseCase extends Mock
    implements DistributeRolesUseCase {}

void main() {
  late MockGameRepository repository;
  late MockEnsureP2pPermissionsUseCase ensurePermissions;
  late MockStartHostingUseCase startHosting;
  late MockScanForRoomsUseCase scanForRooms;
  late MockJoinRoomUseCase joinRoom;
  late MockDistributeRolesUseCase distributeRoles;
  late StreamController<List<Player>> playersController;
  late StreamController<GameSessionEvent> sessionEventsController;

  setUpAll(() {
    registerFallbackValue(const StartHostingParams(userName: 'test'));
    registerFallbackValue(const ScanForRoomsParams(userName: 'test'));
    registerFallbackValue(
      const JoinRoomParams(endpointId: 'ep-1', userName: 'test'),
    );
    registerFallbackValue(
      const DistributeRolesParams(players: [], imposterCount: 1),
    );
    registerFallbackValue(const NoParams());
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    await configureDependencies();

    repository = MockGameRepository();
    ensurePermissions = MockEnsureP2pPermissionsUseCase();
    startHosting = MockStartHostingUseCase();
    scanForRooms = MockScanForRoomsUseCase();
    joinRoom = MockJoinRoomUseCase();
    distributeRoles = MockDistributeRolesUseCase();
    playersController = StreamController<List<Player>>.broadcast();
    sessionEventsController = StreamController<GameSessionEvent>.broadcast();

    when(() => repository.isHost).thenReturn(true);
    when(() => repository.players).thenAnswer((_) => playersController.stream);
    when(
      () => repository.discoveredRooms,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => repository.incomingPayloads,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => repository.sessionEvents,
    ).thenAnswer((_) => sessionEventsController.stream);
    when(
      () => repository.connectedEndpointIds,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => repository.disconnect(),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => ensurePermissions(any()),
    ).thenAnswer((_) async => const Right(null));

    when(() => startHosting(any())).thenAnswer((invocation) async {
      final params = invocation.positionalArguments[0] as StartHostingParams;
      playersController.add([
        Player(id: 'local', name: params.userName, isHost: true),
      ]);
      return const Right(null);
    });

    when(() => distributeRoles(any())).thenAnswer(
      (_) async => const Right(
        DistributeRolesResult(
          hostPayload: GamePayload(role: PlayerRole.normal, word: 'تفاحة'),
        ),
      ),
    );
  });

  tearDown(() async {
    await playersController.close();
    await sessionEventsController.close();
  });

  GameOneBloc createBloc() => GameOneBloc(
    ensurePermissions,
    startHosting,
    scanForRooms,
    joinRoom,
    distributeRoles,
    repository,
  );

  Future<void> enterNameAndHost(WidgetTester tester) async {
    await tester.tap(find.text('استضافة لعبة'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'أحمد');
    await tester.tap(find.text('تأكيد'));
    await tester.pumpAndSettle();
  }

  group('GameOneMainPage', () {
    testWidgets('shows role selection then lobby and gameplay flow', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => createBloc(),
            child: const GameOneMainPage(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('استضافة لعبة'), findsOneWidget);
      expect(find.text('انضمام للعبة'), findsOneWidget);

      await enterNameAndHost(tester);

      expect(find.text('غرفة الانتظار'), findsOneWidget);
      expect(find.text('بدء اللعبة'), findsOneWidget);

      await tester.tap(find.text('بدء اللعبة'));
      await tester.pump();

      expect(find.text('01:00'), findsOneWidget);
      expect(find.text('تفاحة'), findsOneWidget);
    });

    testWidgets('ends session when host disconnects', (tester) async {
      final bloc = createBloc();
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(value: bloc, child: const GameOneMainPage()),
        ),
      );
      await tester.pump();

      await enterNameAndHost(tester);
      expect(find.text('غرفة الانتظار'), findsOneWidget);

      sessionEventsController.add(const HostDisconnected());
      await tester.pump();
      await tester.pump();

      expect(bloc.state, isA<SessionEnded>());
      verify(() => repository.disconnect()).called(1);
    });

    testWidgets('shows session ended on permission denial', (tester) async {
      when(() => ensurePermissions(any())).thenAnswer(
        (_) async => const Left(
          PermissionFailure(message: 'يجب تفعيل Bluetooth والموقع'),
        ),
      );

      final bloc = createBloc();
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(value: bloc, child: const GameOneMainPage()),
        ),
      );
      await tester.pump();

      await enterNameAndHost(tester);
      await tester.pump();

      expect(bloc.state, isA<SessionEnded>());
    });
  });

  testWidgets('Home navigates to game one role selection', (tester) async {
    await tester.pumpWidget(const App());

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Imposter '));
    await tester.pumpAndSettle();

    expect(find.text('كيف تريد اللعب؟'), findsOneWidget);
    expect(find.text('استضافة لعبة'), findsOneWidget);
  });
}
