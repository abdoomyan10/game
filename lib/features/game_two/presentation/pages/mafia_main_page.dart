import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/router/app_router.dart';
import '../bloc/mafia_bloc.dart';
import '../bloc/mafia_event.dart';
import '../bloc/mafia_state.dart';
import '../widgets/connection_lost_host_dialog.dart';
import '../widgets/mafia_day_discussion_view.dart';
import '../widgets/mafia_game_over_view.dart';
import '../widgets/mafia_initial_view.dart';
import '../widgets/mafia_lobby_view.dart';
import '../widgets/mafia_night_phase_view.dart';
import '../widgets/mafia_reconnect_overlay.dart';
import '../widgets/mafia_voting_view.dart';

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

  void _onBackPressed() {
    context.read<MafiaBloc>().add(MafiaLeaveSessionEvent());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لعبة المافيا'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _onBackPressed,
        ),
      ),
      body: BlocConsumer<MafiaBloc, MafiaState>(
        listener: (context, state) async {
          if (state is MafiaSessionEnded) {
            if (state.showHostLostDialog) {
              await showConnectionLostHostDialog(context);
              return;
            }

            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.message)));
            Navigator.of(context).popUntil(
              ModalRoute.withName(AppRouter.home),
            );
          }
        },
        builder: (context, state) {
          if (state is MafiaPaused) {
            return Stack(
              children: [
                _buildPhaseContent(context, state.frozenPhase),
                MafiaReconnectOverlay(
                  reconnectDeadline: state.reconnectDeadline,
                  statusMessage: state.statusMessage,
                ),
              ],
            );
          }

          if (state is MafiaSessionEnded) {
            return const Center(child: CircularProgressIndicator());
          }

          return _buildPhaseContent(context, state);
        },
      ),
    );
  }

  Widget _buildPhaseContent(BuildContext context, MafiaState state) {
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
        MafiaDayDiscussionView(
          players: config.players,
          isHost: isHost,
          roundNumber: roundNumber,
          onStartVoting: () =>
              context.read<MafiaBloc>().add(NextPhaseEvent()),
        ),
      MafiaVotingPhase(
        :final config,
        :final isHost,
        :final roundNumber,
        :final voteCounts,
        :final myVoteTargetId,
      ) =>
        MafiaVotingView(
          players: config.players,
          isHost: isHost,
          roundNumber: roundNumber,
          voteCounts: voteCounts,
          myVoteTargetId: myVoteTargetId,
          onEndVoting: () => context.read<MafiaBloc>().add(NextPhaseEvent()),
        ),
      MafiaGameOver(:final winner, :final message) => MafiaGameOverView(
          winner: winner,
          message: message,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}
