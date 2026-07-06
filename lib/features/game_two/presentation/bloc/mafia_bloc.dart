import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
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
import 'mafia_event.dart';
import 'mafia_state.dart';

@injectable
class MafiaBloc extends Bloc<MafiaEvent, MafiaState> {
  MafiaBloc(this._repository) : super(const MafiaInitial()) {
    on<InitMafiaFlow>(_onInitMafiaFlow);
    on<HostLobbyEvent>(_onHostLobby);
    on<DiscoverLobbyEvent>(_onDiscoverLobby);
    on<PlayersUpdatedEvent>(_onPlayersUpdated);
    on<StartMafiaGame>(_onStartMafiaGame);
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

  int _roundNumber = 1;
  MafiaState? _frozenPhase;

  StreamSubscription<List<MafiaLobbyPlayer>>? _playersSub;
  StreamSubscription<MafiaSessionEvent>? _sessionSub;

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
    _cancelSubscriptions();

    final permission = await _repository.ensurePermissions();
    if (permission.fold((failure) {
      _emitSessionEnded(emit, failure);
      return true;
    }, (_) => false)) {
      return;
    }

    _subscribeToRepositoryStreams();

    if (event.endpointId != null) {
      final result = await _repository.joinLobby(
        endpointId: event.endpointId!,
        userName: event.userName,
      );
      result.fold(
        (failure) => _emitSessionEnded(emit, failure),
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
      return;
    }

    final result = await _repository.scanForLobbies(event.userName);
    result.fold(
      (failure) => _emitSessionEnded(emit, failure),
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

  void _onPlayersUpdated(
    PlayersUpdatedEvent event,
    Emitter<MafiaState> emit,
  ) {
    final current = state;
    if (current is! MafiaLobby) return;

    emit(current.copyWith(players: event.players));
  }

  void _onStartMafiaGame(StartMafiaGame event, Emitter<MafiaState> emit) {
    final current = state;
    if (current is! MafiaLobby || !current.isHost) return;
    if (current.players.length < 3) return;

    try {
      final playersWithRoles = distributeMafiaRoles(current.players);
      final config = MafiaGameConfig(
        state: MafiaGameState.inProgress,
        phase: MafiaPhase.night,
        players: playersWithRoles,
      );

      final wakeRoles = _wakeRolesForConfig(config);
      if (wakeRoles.isEmpty) return;

      _repository.setActiveGameConfig(config);
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
      emit(current);
    }
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
        _repository.setActiveGameConfig(updatedConfig);
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
      case HostDisconnected():
        await _endSession(
          emit,
          reason: MafiaSessionEndReason.hostDisconnected,
          message: 'انقطع الاتصال بالمضيف',
          showHostLostDialog: true,
        );
      case PeerDisconnected():
      case SessionPaused():
      case HostAdvertiserLost():
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
        _repository.setActiveGameConfig(
          current.config.copyWith(phase: MafiaPhase.day),
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
        _repository.setActiveGameConfig(nightConfig);
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
    _repository.setActiveGameConfig(dayConfig);
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
    _sessionSub ??= _repository.sessionEvents.listen((sessionEvent) {
      add(MafiaSessionEventReceived(sessionEvent));
    });
  }

  void _cancelSubscriptions() {
    _playersSub?.cancel();
    _sessionSub?.cancel();
    _playersSub = null;
    _sessionSub = null;
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
