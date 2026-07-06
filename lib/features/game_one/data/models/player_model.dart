import 'package:equatable/equatable.dart';

import '../../domain/entities/player.dart';

class PlayerModel extends Equatable {
  const PlayerModel({
    required this.id,
    required this.name,
    required this.isHost,
  });

  final String id;
  final String name;
  final bool isHost;

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    return PlayerModel(
      id: json['id'] as String,
      name: json['name'] as String,
      isHost: json['isHost'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isHost': isHost,
      };

  PlayerModel copyWith({
    String? id,
    String? name,
    bool? isHost,
  }) {
    return PlayerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isHost: isHost ?? this.isHost,
    );
  }

  Player toEntity() => Player(id: id, name: name, isHost: isHost);

  factory PlayerModel.fromEntity(Player entity) => PlayerModel(
        id: entity.id,
        name: entity.name,
        isHost: entity.isHost,
      );

  @override
  List<Object?> get props => [id, name, isHost];
}
