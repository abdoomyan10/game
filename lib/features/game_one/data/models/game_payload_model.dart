import 'package:equatable/equatable.dart';

import '../../domain/entities/game_payload.dart';
import '../../domain/entities/player_role.dart';

class GamePayloadModel extends Equatable {
  const GamePayloadModel({
    required this.role,
    required this.word,
  });

  final PlayerRole role;
  final String word;

  factory GamePayloadModel.fromJson(Map<String, dynamic> json) {
    return GamePayloadModel(
      role: _roleFromJson(json['role']),
      word: json['word'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'word': word,
      };

  GamePayloadModel copyWith({
    PlayerRole? role,
    String? word,
  }) {
    return GamePayloadModel(
      role: role ?? this.role,
      word: word ?? this.word,
    );
  }

  GamePayload toEntity() => GamePayload(role: role, word: word);

  factory GamePayloadModel.fromEntity(GamePayload entity) =>
      GamePayloadModel(role: entity.role, word: entity.word);

  static PlayerRole _roleFromJson(Object? value) {
    if (value is String) {
      return PlayerRole.values.firstWhere(
        (role) => role.name == value,
        orElse: () => PlayerRole.normal,
      );
    }
    return PlayerRole.normal;
  }

  @override
  List<Object?> get props => [role, word];
}
