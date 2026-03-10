extension StringCasingExtension on String {
  String capitalize() =>
      isNotEmpty ? '${this[0].toUpperCase()}${substring(1)}' : '';
  String lowercaseFirst() =>
      isNotEmpty ? '${this[0].toLowerCase()}${substring(1)}' : '';
  String toTitleCase() {
    if (isEmpty) return '';
    return split(' ')
        .map(
          (word) =>
              word.isNotEmpty
                  ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
                  : '',
        )
        .join(' ');
  }
}
