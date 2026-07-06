import 'package:equatable/equatable.dart';

class MafiaDiscoveredLobby extends Equatable {
  const MafiaDiscoveredLobby({
    required this.endpointId,
    required this.hostName,
  });

  final String endpointId;
  final String hostName;

  @override
  List<Object?> get props => [endpointId, hostName];
}
