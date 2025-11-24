int? parsePositiveInt(String? value) {
  final parsed = int.tryParse(value ?? '');
  if (parsed == null || parsed < 0) {
    return null;
  }
  return parsed;
}
