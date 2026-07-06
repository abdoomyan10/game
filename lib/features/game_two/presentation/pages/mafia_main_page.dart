import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/mafia_bloc.dart';
import '../bloc/mafia_event.dart';
import '../bloc/mafia_state.dart';
import '../widgets/mafia_day_phase_view.dart';
import '../widgets/mafia_game_over_view.dart';
import '../widgets/mafia_initial_view.dart';
import '../widgets/mafia_lobby_view.dart';
import '../widgets/mafia_night_phase_view.dart';
import '../widgets/mafia_voting_phase_view.dart';

class MafiaMainPage extends StatefulWidget {
  const MafiaMainPage({super.key});

  @override
  State<MafiaMainPage> createState() => _MafiaMainPageState();
}

class _MafiaMainPageState extends State<MafiaMainPage> {
  @override
  void initState() {
    super.initState();
    context.read<MafiaBloc>().add(InitMafiaFlow());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لعبة المافيا'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocBuilder<MafiaBloc, MafiaState>(
        builder: (context, state) {
          return switch (state) {
            MafiaInitial() => const MafiaInitialView(),
            MafiaLobby(:final players, :final isHost) => MafiaLobbyView(
                players: players,
                isHost: isHost,
              ),
            MafiaNightPhase(
              :final activeWakeRole,
              :final completedWakeRoles,
              :final isHost,
              :final roundNumber,
            ) =>
              MafiaNightPhaseView(
                activeWakeRole: activeWakeRole,
                completedWakeRoles: completedWakeRoles,
                isHost: isHost,
                roundNumber: roundNumber,
              ),
            MafiaDayPhase(:final config, :final isHost, :final roundNumber) =>
              MafiaDayPhaseView(
                players: config.players,
                isHost: isHost,
                roundNumber: roundNumber,
              ),
            MafiaVotingPhase(:final config, :final isHost, :final roundNumber) =>
              MafiaVotingPhaseView(
                players: config.players,
                isHost: isHost,
                roundNumber: roundNumber,
              ),
            MafiaGameOver(:final winner, :final message) => MafiaGameOverView(
                winner: winner,
                message: message,
              ),
          };
        },
      ),
    );
  }
}
