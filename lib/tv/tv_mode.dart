/// The TV fork launches into the ten-foot interface by default.
/// Set PILIPLUS_TV=false only when comparing upstream mobile behavior.
abstract final class TvMode {
  static const enabled = bool.fromEnvironment(
    'PILIPLUS_TV',
    defaultValue: true,
  );
}
