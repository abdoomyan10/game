import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/mafia_discovered_lobby.dart';
import '../../domain/entities/mafia_game_config.dart';
import '../../domain/entities/mafia_game_state.dart';
import '../../domain/entities/mafia_lobby_player.dart';
import '../../domain/entities/mafia_phase.dart';
import '../../domain/entities/mafia_role.dart';
import '../../domain/entities/mafia_session_end_reason.dart';
import '../../domain/entities/mafia_session_event.dart';
import '../../domain/entities/mafia_victory_side.dart';
import '../../domain/logic/distribute_mafia_roles.dart';
import '../../domain/logic/eliminate_player.dart';
import '../../domain/repositories/mafia_repository.dart';
import '../../data/constants/mafia_p2p_constants.dart';
import 'mafia_event.dart';
import 'mafia_state.dart';

@injectable
class MafiaBloc extends Bloc<MafiaEvent, MafiaState> {
  MafiaBloc(this._repository) : super(const MafiaInitial()) {
    on<InitMafiaFlow>(_onInitMafiaFlow);
    on<HostLobbyEvent>(_onHostLobby);
    on<DiscoverLobbyEvent>(_onDiscoverLobby);
    on<DiscoveredLobbiesUpdatedEvent>(_onDiscoveredLobbiesUpdated);
    on<PlayersUpdatedEvent>(_onPlayersUpdated);
    on<CanStartGameUpdatedEvent>(_onCanStartGameUpdated);
    on<StartMafiaGame>(_onStartMafiaGame);
    on<DismissLobbyStartErrorEvent>(_onDismissLobbyStartError);
    on<NextPhaseEvent>(_onNextPhase);
    on<ExecuteRoleAction>(_onExecuteRoleAction);
    on<CastVoteEvent>(_onCastVote);
    on<MafiaSessionEventReceived>(_onSessionEventReceived);
    on<MafiaLeaveSessionEvent>(_onLeaveSession);
  }

  final MafiaRepository _repository;

  static const _hostPlayerId = 'local';

  static const _nightWakeOrder = [
    MafiaRole.mafiaBoss,
    MafiaRole.silencerMafia,
    MafiaRole.doctor,
    MafiaRole.detective,
    MafiaRole.sniper,
  ];

  static const _startGameErrorMessage =
      'تعذر بدء اللعبة — تحقق من اتصال اللاعبين';

  int _roundNumber = 1;
  MafiaState? _frozenPhase;

  StreamSubscription<List<MafiaLobbyPlayer>>? _playersSub;
  StreamSubscription<MafiaSessionEvent>? _sessionSub;
  StreamSubscription<bool>? _canStartGameSub;
  StreamSubscription<MafiaDiscoveredLobby>? _discoveredLobbiesSub;

  Future<void> _onInitMafiaFlow(
    InitMafiaFlow event,
    Emitter<MafiaState> emit,
  ) async {
    _cancelSubscriptions();
    _frozenPhase = null;
    _roundNumber = 1;
    await _repository.disconnect();
    emit(const MafiaInitial());
  }

  Future<void> _onHostLobby(
    HostLobbyEvent event,
    Emitter<MafiaState> emit,
  ) async {
    _cancelSubscriptions();

    final permission = await _repository.ensurePermissions();
    if (permission.fold((failure) {
      _emitSessionEnded(emit, failure);
      return true;
    }, (_) => false)) {
      return;
    }

    _subscribeToRepositoryStreams();

    final result = await _repository.startHosting(event.userName);
    result.fold(
      (failure) => _emitSessionEnded(emit, failure),
      (_) {
        emit(
          MafiaLobby(
            players: [
              MafiaLobbyPlayer(
                id: _hostPlayerId,
                name: event.userName,
                isHost: true,
              ),
            ],
            isHost: true,
            userName: event.userName,
          ),
        );
      },
    );
  }

  Future<void> _onDiscoverLobby(
    DiscoverLobbyEvent event,
    Emitter<MafiaState> emit,
  ) async {
    if (event.endpointId != null) {
      await _joinDiscoveredLobby(event, emit);
      return;
    }

    _cancelSubscriptions();

    final permission = await _repository.ensurePermissions();
    if (permission.fold((failure) {
      _emitSessionEnded(emit, failure);
      return true;
    }, (_) => false)) {
      return;
    }

    emit(
      DiscoveringLobbies(
        userName: event.userName,
        lobbies: const [],
      ),
    );

    _subscribeToSessionEvents();
    _subscribeToDiscoveredLobbies();

    final result = await _repository.scanForLobbies(event.userName);
    result.fold(
      (failure) => _emitSessionEnded(emit, failure),
      (_) {},
    );
  }

  Future<void> _joinDiscoveredLobby(
    DiscoverLobbyEvent event,
    Emitter<MafiaState> emit,
  ) async {
    final current = state;
    if (current is! DiscoveringLobbies) return;

    emit(current.copyWith(isJoining: true));

    final permission = await _repository.ensurePermissions();
    if (permission.fold((failure) {
      emit(current.copyWith(isJoining: false));
      _emitSessionEnded(emit, failure);
      return true;
    }, (_) => false)) {
      return;
    }

    await _discoveredLobbiesSub?.cancel();
    _discoveredLobbiesSub = null;

    _subscribeToRepositoryStreams();

    final result = await _repository.joinLobby(
      endpointId: event.endpointId!,
      userName: event.userName,
    );

    result.fold(
      (failure) {
        emit(current.copyWith(isJoining: false));
        _emitSessionEnded(emit, failure);
      },
      (_) {
        emit(
          MafiaLobby(
            players: [
              MafiaLobbyPlayer(
                id: _hostPlayerId,
                name: event.userName,
                isHost: false,
              ),
            ],
            isHost: false,
            userName: event.userName,
          ),
        );
      },
    );
  }

  void _onDiscoveredLobbiesUpdated(
    DiscoveredLobbiesUpdatedEvent event,
    Emitter<MafiaState> emit,
  ) {
    emit(event.state);
  }

  void _onPlayersUpdated(
    PlayersUpdatedEvent event,
    Emitter<MafiaState> emit,
  ) {
    final current = state;
    if (current is! MafiaLobby) return;

    emit(current.copyWith(players: event.players));
  }

  void _onCanStartGameUpdated(
    CanStartGameUpdatedEvent event,
    Emitter<MafiaState> emit,
  ) {
    final current = state;
    if (current is! MafiaLobby || !current.isHost) return;

    emit(current.copyWith(canStartGame: event.canStartGame));
  }

  Future<void> _onStartMafiaGame(
    StartMafiaGame event,
    Emitter<MafiaState> emit,
  ) async {
    final current = state;
    if (current is! MafiaLobby || !current.isHost) return;

    final lobbyPlayers = _repository.lobbyPlayers;
    final playersForStart = lobbyPlayers.length >= current.players.length
        ? lobbyPlayers
        : current.players;

    if (playersForStart.length < MafiaP2pConstants.minPlayersToStart) {
      emit(
        current.copyWith(
          startErrorMessage: _startGameErrorMessage,
          clearStartErrorMessage: false,
        ),
      );
      return;
    }

    try {
      final playersWithRoles = distributeMafiaRoles(playersForStart);
      final config = MafiaGameConfig(
        state: MafiaGameState.inProgress,
        phase: MafiaPhase.night,
        players: playersWithRoles,
      );

      final wakeRoles = _wakeRolesForConfig(config);
      if (wakeRoles.isEmpty) {
        emit(
          current.copyWith(
            startErrorMessage: _startGameErrorMessage,
            clearStartErrorMessage: false,
          ),
        );
        return;
      }

      await _repository.setActiveGameConfig(config);
      _roundNumber = 1;
      emit(
        MafiaNightPhase(
          config: config,
          activeWakeRole: wakeRoles.first,
          completedWakeRoles: const {},
          isHost: true,
          roundNumber: _roundNumber,
        ),
      );
    } on ArgumentError {
      emit(
        current.copyWith(
          startErrorMessage: _startGameErrorMessage,
          clearStartErrorMessage: false,
          canStartGame: _repository.canStartGame,
        ),
      );
    } catch (_) {
      if (_repository.activeGameConfig?.state == MafiaGameState.inProgress) {
        await _repository.setActiveGameConfig(null);
      }
      emit(
        current.copyWith(
          startErrorMessage: _startGameErrorMessage,
          clearStartErrorMessage: false,
          canStartGame: _repository.canStartGame,
        ),
      );
    }
  }

  void _onDismissLobbyStartError(
    DismissLobbyStartErrorEvent event,
    Emitter<MafiaState> emit,
  ) {
    final current = state;
    if (current is! MafiaLobby) return;

    emit(current.copyWith(clearStartErrorMessage: true));
  }

  void _emitNightPhaseFromConfig(
    Emitter<MafiaState> emit,
    MafiaGameConfig config, {
    required bool isHost,
  }) {
    final wakeRoles = _wakeRolesForConfig(config);
    if (wakeRoles.isEmpty) return;

    _roundNumber = 1;
    emit(
      MafiaNightPhase(
        config: config,
        activeWakeRole: wakeRoles.first,
        completedWakeRoles: const {},
        isHost: isHost,
        roundNumber: _roundNumber,
      ),
    );
  }

  void _onExecuteRoleAction(
    ExecuteRoleAction event,
    Emitter<MafiaState> emit,
  ) {
    if (state is MafiaPaused) return;

    final current = state;
    if (current is! MafiaNightPhase) return;
    if (event.actingRole != current.activeWakeRole) return;

    final completed = {...current.completedWakeRoles, event.actingRole};
    _emitAfterNightWake(
      emit,
      current.copyWith(completedWakeRoles: completed),
    );
  }

  void _onCastVote(CastVoteEvent event, Emitter<MafiaState> emit) {
    if (state is MafiaPaused) return;

    final current = state;
    if (current is! MafiaVotingPhase) return;

    final isAliveTarget = current.config.activePlayers
        .any((player) => player.id == event.targetPlayerId);
    if (!isAliveTarget) return;

    final counts = Map<String, int>.from(current.voteCounts);
    final previousVote = current.myVoteTargetId;
    if (previousVote != null) {
      final previousCount = counts[previousVote];
      if (previousCount != null) {
        if (previousCount <= 1) {
          counts.remove(previousVote);
        } else {
          counts[previousVote] = previousCount - 1;
        }
      }
    }

    counts[event.targetPlayerId] = (counts[event.targetPlayerId] ?? 0) + 1;

    emit(
      current.copyWith(
        voteCounts: counts,
        myVoteTargetId: event.targetPlayerId,
      ),
    );
  }

  Future<void> _onSessionEventReceived(
    MafiaSessionEventReceived event,
    Emitter<MafiaState> emit,
  ) async {
    switch (event.event) {
      case PeerReconnecting(:final playerId, :final deadline):
        final active = _activePhaseState(state);
        if (active == null) return;
        _frozenPhase = active;
        emit(
          MafiaPaused(
            frozenPhase: active,
            reconnectingPlayerId: playerId,
            reconnectDeadline: deadline,
            statusMessage: 'انقطع اتصال لاعب — محاولة إعادة الاتصال…',
          ),
        );
      case PeerReconnected():
      case SessionResumed():
        final frozen = _frozenPhase;
        if (frozen != null) {
          _frozenPhase = null;
          emit(frozen);
        }
      case PeerEliminated(:final playerId):
        final base = _frozenPhase ?? _activePhaseState(state);
        final baseConfig = _configFromPhase(base);
        if (base == null || baseConfig == null) return;
        final updatedConfig = eliminatePlayer(baseConfig, playerId);
        unawaited(_repository.setActiveGameConfig(updatedConfig));
        final updatedPhase = _phaseWithConfig(base, updatedConfig);
        _frozenPhase = null;
        final gameOver = _checkVictory(updatedConfig);
        if (gameOver != null) {
          emit(gameOver);
        } else {
          emit(updatedPhase);
        }
      case RosterUpdated(:final players):
        if (state is MafiaLobby) {
          emit((state as MafiaLobby).copyWith(players: players));
        }
      case GameStarted(:final config):
        final current = state;
        if (current is! MafiaLobby || current.isHost) return;
        _emitNightPhaseFromConfig(emit, config, isHost: false);
      case HostDisconnected():
        await _endSession(
          emit,
          reason: MafiaSessionEndReason.hostDisconnected,
          message: 'انقطع الاتصال بالمضيف',
          showHostLostDialog: true,
        );
      case HostAdvertiserLost(:final endpointId):
        final current = state;
        if (current is DiscoveringLobbies && !current.isJoining) {
          add(
            DiscoveredLobbiesUpdatedEvent(
              current.copyWith(
                lobbies: current.lobbies
                    .where((lobby) => lobby.endpointId != endpointId)
                    .toList(),
              ),
            ),
          );
        }
      case PeerDisconnected():
      case SessionPaused():
        break;
    }
  }

  Future<void> _onLeaveSession(
    MafiaLeaveSessionEvent event,
    Emitter<MafiaState> emit,
  ) async {
    await _endSession(
      emit,
      reason: MafiaSessionEndReason.userLeft,
      message: 'تم مغادرة الجلسة',
    );
  }

  void _onNextPhase(NextPhaseEvent event, Emitter<MafiaState> emit) {
    if (state is MafiaPaused) return;

    final current = state;

    switch (current) {
      case MafiaNightPhase():
        final completed = {
          ...current.completedWakeRoles,
          current.activeWakeRole,
        };
        _emitAfterNightWake(
          emit,
          current.copyWith(completedWakeRoles: completed),
        );
      case MafiaDayPhase():
        final gameOver = _checkVictory(current.config);
        if (gameOver != null) {
          emit(gameOver);
          return;
        }
        emit(
          MafiaVotingPhase(
            config: current.config,
            isHost: current.isHost,
            roundNumber: current.roundNumber,
            voteCounts: const {},
          ),
        );
        unawaited(
          _repository.setActiveGameConfig(
            current.config.copyWith(phase: MafiaPhase.day),
          ),
        );
      case MafiaVotingPhase():
        final gameOver = _checkVictory(current.config);
        if (gameOver != null) {
          emit(gameOver);
          return;
        }
        _roundNumber = current.roundNumber + 1;
        final resetPlayers = current.config.players
            .map((player) => player.copyWith(isSilenced: false))
            .toList();
        final nightConfig = current.config.copyWith(
          phase: MafiaPhase.night,
          players: resetPlayers,
        );
        unawaited(_repository.setActiveGameConfig(nightConfig));
        final wakeRoles = _wakeRolesForConfig(nightConfig);
        if (wakeRoles.isEmpty) return;

        emit(
          MafiaNightPhase(
            config: nightConfig,
            activeWakeRole: wakeRoles.first,
            completedWakeRoles: const {},
            isHost: current.isHost,
            roundNumber: _roundNumber,
          ),
        );
      default:
        return;
    }
  }

  void _emitAfterNightWake(
    Emitter<MafiaState> emit,
    MafiaNightPhase current,
  ) {
    final wakeRoles = _wakeRolesForConfig(current.config);
    final nextRole = _nextWakeRole(wakeRoles, current.completedWakeRoles);

    if (nextRole != null) {
      emit(current.copyWith(activeWakeRole: nextRole));
      return;
    }

    final dayConfig = current.config.copyWith(phase: MafiaPhase.day);
    unawaited(_repository.setActiveGameConfig(dayConfig));
    final gameOver = _checkVictory(dayConfig);
    if (gameOver != null) {
      emit(gameOver);
      return;
    }

    emit(
      MafiaDayPhase(
        config: dayConfig,
        isHost: current.isHost,
        roundNumber: current.roundNumber,
      ),
    );
  }

  MafiaState? _activePhaseState(MafiaState current) {
    return switch (current) {
      MafiaPaused(:final frozenPhase) => _activePhaseState(frozenPhase),
      MafiaNightPhase() || MafiaDayPhase() || MafiaVotingPhase() => current,
      _ => null,
    };
  }

  MafiaGameConfig? _configFromPhase(MafiaState? phase) {
    return switch (phase) {
      MafiaNightPhase(:final config) => config,
      MafiaDayPhase(:final config) => config,
      MafiaVotingPhase(:final config) => config,
      _ => null,
    };
  }

  MafiaState _phaseWithConfig(MafiaState phase, MafiaGameConfig config) {
    return switch (phase) {
      MafiaNightPhase() => phase.copyWith(config: config),
      MafiaDayPhase() => phase.copyWith(config: config),
      MafiaVotingPhase() => phase.copyWith(config: config),
      _ => phase,
    };
  }

  List<MafiaRole> _wakeRolesForConfig(MafiaGameConfig config) {
    final presentRoles = config.players.map((player) => player.role).toSet();
    return _nightWakeOrder
        .where((role) => presentRoles.contains(role))
        .toList();
  }

  MafiaRole? _nextWakeRole(
    List<MafiaRole> wakeRoles,
    Set<MafiaRole> completedWakeRoles,
  ) {
    for (final role in wakeRoles) {
      if (!completedWakeRoles.contains(role)) {
        return role;
      }
    }
    return null;
  }

  MafiaGameOver? _checkVictory(MafiaGameConfig config) {
    final alive = config.activePlayers;
    final mafiaCount = alive.where((player) => player.role.isMafia).length;
    final citizenCount = alive.length - mafiaCount;

    if (mafiaCount == 0) {
      return MafiaGameOver(
        config: config.copyWith(state: MafiaGameState.finished),
        winner: MafiaVictorySide.citizens,
        message: 'فاز المواطنون!',
      );
    }

    if (mafiaCount >= citizenCount) {
      return MafiaGameOver(
        config: config.copyWith(state: MafiaGameState.finished),
        winner: MafiaVictorySide.mafia,
        message: 'فازت المافيا!',
      );
    }

    return null;
  }

  void _subscribeToRepositoryStreams() {
    _playersSub ??= _repository.players.listen((players) {
      add(PlayersUpdatedEvent(players));
    });
    _subscribeToSessionEvents();
    _canStartGameSub ??= _repository.canStartGameUpdates.listen((canStart) {
      add(CanStartGameUpdatedEvent(canStart));
    });
  }

  void _subscribeToSessionEvents() {
    _sessionSub ??= _repository.sessionEvents.listen((sessionEvent) {
      add(MafiaSessionEventReceived(sessionEvent));
    });
  }

  void _subscribeToDiscoveredLobbies() {
    _discoveredLobbiesSub?.cancel();
    _discoveredLobbiesSub = _repository.discoveredLobbies.listen((lobby) {
      final current = state;
      if (current is! DiscoveringLobbies || current.isJoining) return;

      final exists =
          current.lobbies.any((entry) => entry.endpointId == lobby.endpointId);
      if (exists) return;

      add(
        DiscoveredLobbiesUpdatedEvent(
          current.copyWith(lobbies: [...current.lobbies, lobby]),
        ),
      );
    });
  }

  void _cancelSubscriptions() {
    _playersSub?.cancel();
    _sessionSub?.cancel();
    _canStartGameSub?.cancel();
    _discoveredLobbiesSub?.cancel();
    _playersSub = null;
    _sessionSub = null;
    _canStartGameSub = null;
    _discoveredLobbiesSub = null;
  }

  Future<void> _endSession(
    Emitter<MafiaState> emit, {
    required MafiaSessionEndReason reason,
    required String message,
    bool showHostLostDialog = false,
  }) async {
    _cancelSubscriptions();
    _frozenPhase = null;
    await _repository.disconnect();
    emit(
      MafiaSessionEnded(
        reason: reason,
        message: message,
        showHostLostDialog: showHostLostDialog,
      ),
    );
  }

  void _emitSessionEnded(Emitter<MafiaState> emit, Failure failure) {
    final reason = failure is PermissionFailure
        ? MafiaSessionEndReason.permissionDenied
        : MafiaSessionEndReason.userLeft;
    emit(
      MafiaSessionEnded(
        reason: reason,
        message: failure.message,
      ),
    );
  }

  @override
  Future<void> close() {
    _cancelSubscriptions();
    return super.close();
  }
}
