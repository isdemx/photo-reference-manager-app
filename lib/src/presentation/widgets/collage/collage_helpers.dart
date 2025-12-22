// helpers
Duration fracToTime(Duration total, double f) {
  if (total == Duration.zero) return Duration.zero;
  final ms = (total.inMilliseconds * f.clamp(0.0, 1.0)).round();
  return Duration(milliseconds: ms);
}

double timeToFrac(Duration total, Duration t) {
  if (total == Duration.zero) return 0.0;
  return (t.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
}
