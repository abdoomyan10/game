part of 'home_bloc.dart';

sealed class HomeEvent {}

final class HomeGameSelected extends HomeEvent {
  HomeGameSelected(this.gameId);

  final String gameId;
}
