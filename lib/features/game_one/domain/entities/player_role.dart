enum PlayerRole {
  normal,
  imposter;

  bool get isImposter => this == PlayerRole.imposter;
  bool get isNormal => this == PlayerRole.normal;
}
