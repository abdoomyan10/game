import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/game_one_bloc.dart';
import '../widgets/discovering_rooms_view.dart';
import '../widgets/gameplay_view.dart';
import '../widgets/lobby_view.dart';
import '../widgets/role_selection_view.dart';

class GameOneMainPage extends StatefulWidget {
  const GameOneMainPage({super.key});

  @override
  State<GameOneMainPage> createState() => _GameOneMainPageState();
}

class _GameOneMainPageState extends State<GameOneMainPage> {
  @override
  void initState() {
    super.initState();
    context.read<GameOneBloc>().add(InitializeGameFlow());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لعبة ١'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocConsumer<GameOneBloc, GameOneState>(
        listener: (context, state) {
          if (state is SessionEnded) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(state.message)),
              );
            Navigator.of(context).popUntil(
              ModalRoute.withName(AppRouter.home),
            );
            return;
          }

          if (state is GameOneError) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(state.message)),
              );
            context.read<GameOneBloc>().add(DismissErrorEvent());
          }
        },
        builder: (context, state) {
          return switch (state) {
            GameOneInitial() => const RoleSelectionView(),
            CreatingRoom() => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            DiscoveringRooms(
              :final userName,
              :final rooms,
              :final isJoining,
            ) =>
              DiscoveringRoomsView(
                userName: userName,
                rooms: rooms,
                isJoining: isJoining,
              ),
            InsideLobby(:final players, :final isHost) => LobbyView(
                players: players,
                isHost: isHost,
              ),
            GameActive(
              :final role,
              :final word,
              :final remainingSeconds,
            ) =>
              GameplayView(
                role: role,
                word: word,
                remainingSeconds: remainingSeconds,
              ),
            GameOneError() => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            SessionEnded() => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
          };
        },
      ),
    );
  }
}
