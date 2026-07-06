import 'package:equatable/equatable.dart';

import 'player_role.dart';

class GamePayload extends Equatable {
  const GamePayload({
    required this.role,
    required this.word,
  });

  final PlayerRole role;
  final String word;

  GamePayload copyWith({
    PlayerRole? role,
    String? word,
  }) {
    return GamePayload(
      role: role ?? this.role,
      word: word ?? this.word,
    );
  }

  @override
  List<Object?> get props => [role, word];
}
