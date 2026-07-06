import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/discovered_room.dart';
import '../../domain/entities/game_payload.dart';
import '../../domain/entities/game_session_event.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/player_role.dart';
import '../../domain/entities/session_end_reason.dart';
import '../../domain/repositories/game_repository.dart';
import '../../domain/usecases/distribute_roles_usecase.dart';
import '../../domain/usecases/ensure_p2p_permissions_usecase.dart';
import '../../domain/usecases/join_room_usecase.dart';
import '../../domain/usecases/scan_for_rooms_usecase.dart';
import '../../domain/usecases/start_hosting_usecase.dart';

part 'game_one_event.dart';
part 'game_one_state.dart';

@injectable
class GameOneBloc extends Bloc<GameOneEvent, GameOneState> {
  GameOneBloc(
    this._ensurePermissions,
    this._startHosting,
    this._scanForRooms,
    this._joinRoom,
    this._distributeRoles,
    this._repository,
  ) : super(const GameOneInitial()) {
    on<InitializeGameFlow>(_onInitialize);
    on<HostRoomEvent>(_onHostRoom);
    on<DiscoverRoomsEvent>(_onDiscoverRooms);
    on<PlayerJoinedEvent>(_onPlayerJoined);
    on<StartGameEvent>(_onStartGame);
    on<PayloadReceivedEvent>(_onPayloadReceived);
    on<DismissErrorEvent>(_onDismissError);
    on<SessionEventReceived>(_onSessionEventReceived);
    on<_DiscoveringRoomsUpdated>(_onDiscoveringRoomsUpdated);
  }

  final EnsureP2pPermissionsUseCase _ensurePermissions;
  final StartHostingUseCase _startHosting;
  final ScanForRoomsUseCase _scanForRooms;
  final JoinRoomUseCase _joinRoom;
  final DistributeRolesUseCase _distributeRoles;
  final GameRepository _repository;

  Timer? _countdownTimer;
  StreamSubscription<List<Player>>? _playersSub;
  StreamSubscription<DiscoveredRoom>? _discoveredRoomsSub;
  StreamSubscription<GamePayload>? _payloadsSub;
  StreamSubscription<GameSessionEvent>? _sessionSub;
  GameOneState? _lastStableState;

  void _onInitialize(InitializeGameFlow event, Emitter<GameOneState> emit) {
    _cancelSubscriptions();
    _countdownTimer?.cancel();
    _lastStableState = null;
    emit(const GameOneInitial());
  }

  Future<void> _onHostRoom(
    HostRoomEvent event,
    Emitter<GameOneState> emit,
  ) async {
    _cancelSubscriptions();
    final creating = CreatingRoom(userName: event.userName);
    _lastStableState = creating;
    emit(creating);

    final permissionResult = await _ensurePermissions(const NoParams());
    final permissionDenied = permissionResult.fold<bool>(
      (failure) {
        _handlePermissionFailure(emit, failure);
        return true;
      },
      (_) => false,
    );
    if (permissionDenied) return;

    _subscribeToPlayers();
    _subscribeToSessionEvents();

    final result = await _startHosting(
      StartHostingParams(userName: event.userName),
    );

    result.fold(
      (failure) {
        _lastStableState = const GameOneInitial();
        _emitError(emit, failure.message);
      },
      (_) {},
    );
  }

  Future<void> _onDiscoverRooms(
    DiscoverRoomsEvent event,
    Emitter<GameOneState> emit,
  ) async {
    if (event.endpointId != null) {
      await _joinDiscoveredRoom(event, emit);
      return;
    }

    _cancelSubscriptions();
    final discovering = DiscoveringRooms(
      userName: event.userName,
      rooms: const [],
    );
    _lastStableState = discovering;
    emit(discovering);

    final permissionResult = await _ensurePermissions(const NoParams());
    final permissionDenied = permissionResult.fold<bool>(
      (failure) {
        _handlePermissionFailure(emit, failure);
        return true;
      },
      (_) => false,
    );
    if (permissionDenied) return;

    _subscribeToDiscoveredRooms();
    _subscribeToSessionEvents();

    final result = await _scanForRooms(
      ScanForRoomsParams(userName: event.userName),
    );

    result.fold(
      (failure) => _emitError(emit, failure.message),
      (_) {},
    );
  }

  Future<void> _joinDiscoveredRoom(
    DiscoverRoomsEvent event,
    Emitter<GameOneState> emit,
  ) async {
    final current = state;
    if (current is! DiscoveringRooms) return;

    final joining = current.copyWith(isJoining: true);
    _lastStableState = joining;
    emit(joining);

    final permissionResult = await _ensurePermissions(const NoParams());
    final permissionDenied = permissionResult.fold<bool>(
      (failure) {
        final restored = current.copyWith(isJoining: false);
        _lastStableState = restored;
        emit(restored);
        _handlePermissionFailure(emit, failure);
        return true;
      },
      (_) => false,
    );
    if (permissionDenied) return;

    await _discoveredRoomsSub?.cancel();
    _discoveredRoomsSub = null;

    _subscribeToPlayers();
    _subscribeToIncomingPayloads();
    _subscribeToSessionEvents();

    final result = await _joinRoom(
      JoinRoomParams(
        endpointId: event.endpointId!,
        userName: event.userName,
      ),
    );

    result.fold(
      (failure) {
        final restored = current.copyWith(isJoining: false);
        _lastStableState = restored;
        _subscribeToDiscoveredRooms();
        _emitError(emit, failure.message);
      },
      (_) {},
    );
  }

  void _onPlayerJoined(
    PlayerJoinedEvent event,
    Emitter<GameOneState> emit,
  ) {
    final current = state;
    if (current is CreatingRoom ||
        current is InsideLobby ||
        (current is DiscoveringRooms && current.isJoining)) {
      final lobby = InsideLobby(
        players: event.players,
        isHost: _repository.isHost,
      );
      _lastStableState = lobby;
      emit(lobby);
    }
  }

  Future<void> _onStartGame(
    StartGameEvent event,
    Emitter<GameOneState> emit,
  ) async {
    final current = state;
    if (current is! InsideLobby || !current.isHost) return;

    final result = await _distributeRoles(
      DistributeRolesParams(
        players: current.players,
        imposterCount: 1,
      ),
    );

    result.fold(
      (failure) => _emitError(emit, failure.message),
      (distributeResult) {
        final payload = distributeResult.hostPayload;
        _startCountdown(
          emit,
          GameActive(
            role: payload.role,
            word: payload.word,
            remainingSeconds: 60,
            isHost: true,
          ),
        );
      },
    );
  }

  void _onPayloadReceived(
    PayloadReceivedEvent event,
    Emitter<GameOneState> emit,
  ) {
    final payload = event.payload;
    _startCountdown(
      emit,
      GameActive(
        role: payload.role,
        word: payload.word,
        remainingSeconds: 60,
        isHost: false,
      ),
    );
  }

  Future<void> _onSessionEventReceived(
    SessionEventReceived event,
    Emitter<GameOneState> emit,
  ) async {
    switch (event.event) {
      case ClientDisconnected():
        final current = state;
        if (current is InsideLobby || current is GameActive) {
          _emitError(emit, 'غادر لاعب');
        }
      case RosterUpdated(:final players):
        add(PlayerJoinedEvent(players));
      case HostDisconnected():
        await _endSession(
          emit,
          reason: SessionEndReason.hostDisconnected,
          message: 'انقطع الاتصال بالمضيف',
        );
      case EndpointLost(:final endpointId):
        final current = state;
        if (current is DiscoveringRooms && !current.isJoining) {
          add(
            _DiscoveringRoomsUpdated(
              current.copyWith(
                rooms: current.rooms
                    .where((room) => room.id != endpointId)
                    .toList(),
              ),
            ),
          );
        }
    }
  }

  void _onDiscoveringRoomsUpdated(
    _DiscoveringRoomsUpdated event,
    Emitter<GameOneState> emit,
  ) {
    _lastStableState = event.state;
    emit(event.state);
  }

  void _onDismissError(DismissErrorEvent event, Emitter<GameOneState> emit) {
    final previous = _lastStableState;
    if (previous != null) {
      emit(previous);
    } else {
      emit(const GameOneInitial());
    }
  }

  void _handlePermissionFailure(Emitter<GameOneState> emit, Failure failure) {
    emit(
      SessionEnded(
        reason: SessionEndReason.permissionDenied,
        message: failure.message,
      ),
    );
  }

  Future<void> _endSession(
    Emitter<GameOneState> emit, {
    required SessionEndReason reason,
    required String message,
  }) async {
    _countdownTimer?.cancel();
    _cancelSubscriptions();
    await _repository.disconnect();
    emit(SessionEnded(reason: reason, message: message));
  }

  void _startCountdown(Emitter<GameOneState> emit, GameActive initial) {
    _countdownTimer?.cancel();
    _lastStableState = initial;
    emit(initial);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final gameplay = state;
      if (gameplay is! GameActive) return;

      if (gameplay.remainingSeconds <= 0) {
        _countdownTimer?.cancel();
        return;
      }

      emit(
        gameplay.copyWith(remainingSeconds: gameplay.remainingSeconds - 1),
      );
    });
  }

  void _emitError(Emitter<GameOneState> emit, String message) {
    emit(GameOneError(message: message));
  }

  void _subscribeToPlayers() {
    _playersSub?.cancel();
    _playersSub = _repository.players.listen(
      (players) => add(PlayerJoinedEvent(players)),
    );
  }

  void _subscribeToSessionEvents() {
    _sessionSub?.cancel();
    _sessionSub = _repository.sessionEvents.listen(
      (event) => add(SessionEventReceived(event)),
    );
  }

  void _subscribeToDiscoveredRooms() {
    _discoveredRoomsSub?.cancel();
    _discoveredRoomsSub = _repository.discoveredRooms.listen((room) {
      final current = state;
      if (current is! DiscoveringRooms || current.isJoining) return;

      final exists = current.rooms.any((r) => r.id == room.id);
      if (exists) return;

      add(
        _DiscoveringRoomsUpdated(
          current.copyWith(rooms: [...current.rooms, room]),
        ),
      );
    });
  }

  void _subscribeToIncomingPayloads() {
    _payloadsSub?.cancel();
    _payloadsSub = _repository.incomingPayloads.listen(
      (payload) => add(PayloadReceivedEvent(payload)),
    );
  }

  void _cancelSubscriptions() {
    _playersSub?.cancel();
    _discoveredRoomsSub?.cancel();
    _payloadsSub?.cancel();
    _sessionSub?.cancel();
    _playersSub = null;
    _discoveredRoomsSub = null;
    _payloadsSub = null;
    _sessionSub = null;
  }

  @override
  Future<void> close() {
    _countdownTimer?.cancel();
    _cancelSubscriptions();
    unawaited(_repository.disconnect());
    return super.close();
  }
}

/// Internal event to update discovering rooms list from stream listener.
final class _DiscoveringRoomsUpdated extends GameOneEvent {
  _DiscoveringRoomsUpdated(this.state);

  final DiscoveringRooms state;
}
