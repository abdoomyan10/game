part of 'splash_bloc.dart';

enum SplashStatus { initial, navigating }

final class SplashState {
  const SplashState({this.status = SplashStatus.initial});

  final SplashStatus status;

  SplashState copyWith({SplashStatus? status}) {
    return SplashState(status: status ?? this.status);
  }
}
