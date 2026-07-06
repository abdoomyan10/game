import 'dart:math';

/// Local predefined secret words for Game One.
class SecretWords {
  SecretWords._();

  static const List<String> words = [
    'تفاحة',
    'سيارة',
    'مستشفى',
    'كتاب',
    'بحر',
    'قمر',
    'مدرسة',
    'حديقة',
    'قطار',
    'هاتف',
  ];

  static const String imposterPlaceholder = '???';

  static String pickRandom([Random? random]) {
    final rng = random ?? Random.secure();
    return words[rng.nextInt(words.length)];
  }
}
