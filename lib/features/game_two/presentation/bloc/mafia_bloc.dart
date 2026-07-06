import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/mafia_game_config.dart';
import '../../domain/entities/mafia_game_state.dart';
import '../../domain/entities/mafia_lobby_player.dart';
import '../../domain/entities/mafia_phase.dart';
import '../../domain/entities/mafia_role.dart';
import '../../domain/logic/distribute_mafia_roles.dart';
import 'mafia_event.dart';
import 'mafia_state.dart';

@injectable
class MafiaBloc extends Bloc<MafiaEvent, MafiaState> {
  MafiaBloc() : super(const MafiaInitial()) {
    on<InitMafiaFlow>(_onInitMafiaFlow);
    on<HostLobbyEvent>(_onHostLobby);
    on<DiscoverLobbyEvent>(_onDiscoverLobby);
    on<PlayersUpdatedEvent>(_onPlayersUpdated);
    on<StartMafiaGame>(_onStartMafiaGame);
    on<NextPhaseEvent>(_onNextPhase);
    on<ExecuteRoleAction>(_onExecuteRoleAction);
  }

  static const _hostPlayerId = 'local';

  static const _nightWakeOrder = [
    MafiaRole.mafiaBoss,
    MafiaRole.silencerMafia,
    MafiaRole.doctor,
    MafiaRole.detective,
    MafiaRole.sniper,
  ];

  int _roundNumber = 1;

  void _onInitMafiaFlow(InitMafiaFlow event, Emitter<MafiaState> emit) {
    _roundNumber = 1;
    emit(const MafiaInitial());
  }

  void _onHostLobby(HostLobbyEvent event, Emitter<MafiaState> emit) {
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
  }

  void _onDiscoverLobby(DiscoverLobbyEvent event, Emitter<MafiaState> emit) {
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
    final current = state;
    if (current is! MafiaNightPhase) return;
    if (event.actingRole != current.activeWakeRole) return;

    final completed = {...current.completedWakeRoles, event.actingRole};
    _emitAfterNightWake(
      emit,
      current.copyWith(completedWakeRoles: completed),
    );
  }

  void _onNextPhase(NextPhaseEvent event, Emitter<MafiaState> emit) {
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
}
