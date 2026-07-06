enum MafiaRole {
  mafiaBoss,
  silencerMafia,
  doctor,
  detective,
  sniper,
  citizen;

  bool get isMafia => this == mafiaBoss || this == silencerMafia;

  bool get isCitizen => this == citizen;

  bool get isSpecial => !isCitizen;
}
