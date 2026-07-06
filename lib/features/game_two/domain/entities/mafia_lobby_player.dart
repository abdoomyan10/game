import 'package:equatable/equatable.dart';

class MafiaLobbyPlayer extends Equatable {
  const MafiaLobbyPlayer({
    required this.id,
    required this.name,
    required this.isHost,
  });

  final String id;
  final String name;
  final bool isHost;

  MafiaLobbyPlayer copyWith({
    String? id,
    String? name,
    bool? isHost,
  }) {
    return MafiaLobbyPlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      isHost: isHost ?? this.isHost,
    );
  }

  @override
  List<Object?> get props => [id, name, isHost];
}
