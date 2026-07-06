import 'package:equatable/equatable.dart';

class DiscoveredRoom extends Equatable {
  const DiscoveredRoom({
    required this.id,
    required this.hostName,
  });

  final String id;
  final String hostName;

  @override
  List<Object?> get props => [id, hostName];
}
