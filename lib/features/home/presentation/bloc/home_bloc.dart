import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/game_ids.dart';
import '../../../../core/router/app_router.dart';

part 'home_event.dart';
part 'home_state.dart';

@injectable
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc() : super(const HomeState()) {
    on<HomeGameSelected>(_onGameSelected);
  }

  void _onGameSelected(HomeGameSelected event, Emitter<HomeState> emit) {
    emit(const HomeState());
    emit(
      HomeState(
        status: HomeStatus.gameSelected,
        selectedGameId: event.gameId,
      ),
    );
  }

  String? routeForGame(String gameId) {
    return switch (gameId) {
      GameIds.game1 => AppRouter.gameOne,
      GameIds.game2 => AppRouter.gameTwo,
      _ => null,
    };
  }
}
