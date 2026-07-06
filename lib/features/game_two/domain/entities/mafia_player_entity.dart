import 'package:equatable/equatable.dart';

import 'mafia_role.dart';

class MafiaPlayerEntity extends Equatable {
  const MafiaPlayerEntity({
    required this.id,
    required this.name,
    required this.isHost,
    required this.role,
    required this.isAlive,
    required this.isSilenced,
  });

  final String id;
  final String name;
  final bool isHost;
  final MafiaRole role;
  final bool isAlive;
  final bool isSilenced;

  MafiaPlayerEntity copyWith({
    String? id,
    String? name,
    bool? isHost,
    MafiaRole? role,
    bool? isAlive,
    bool? isSilenced,
  }) {
    return MafiaPlayerEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      isHost: isHost ?? this.isHost,
      role: role ?? this.role,
      isAlive: isAlive ?? this.isAlive,
      isSilenced: isSilenced ?? this.isSilenced,
    );
  }

  @override
  List<Object?> get props => [id, name, isHost, role, isAlive, isSilenced];
}
