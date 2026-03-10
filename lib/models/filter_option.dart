class FilterOption {
  final String key;
  final int id;
  final String label;

  FilterOption({required this.key, required this.id, required this.label});

  // 🔥 Ensures dropdown sees matching objects as equal
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterOption &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
