part of 'home_bloc.dart';

enum HomeStatus { initial, gameSelected }

final class HomeState {
  const HomeState({
    this.status = HomeStatus.initial,
    this.selectedGameId,
  });

  final HomeStatus status;
  final String? selectedGameId;

  HomeState copyWith({
    HomeStatus? status,
    String? selectedGameId,
  }) {
    return HomeState(
      status: status ?? this.status,
      selectedGameId: selectedGameId ?? this.selectedGameId,
    );
  }
}
