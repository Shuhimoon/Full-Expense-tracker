/// Counts shown before a backup replace. Parsing only; it does not write.
///
/// Accepts the JSON object from LocalApi.exportBook, which matches
/// `api/internal/app/backup.go` `exportBook`: `book`, `accounts`,
/// `categories`, `entries`, `trades` (plus instruments, positions, quotes,
/// and fx_rates, which the preview does not count). A Go export with a
/// timestamp opening date is trimmed to `YYYY-MM-DD`.
class BackupPreview {
  const BackupPreview({
    required this.bookName,
    required this.openingDate,
    required this.accounts,
    required this.categories,
    required this.entries,
    required this.trades,
  });

  final String bookName;
  final String? openingDate;
  final int accounts;
  final int categories;
  final int entries;
  final int trades;

  /// Reads display fields. Missing lists count as zero. A bad book object
  /// yields an empty name rather than throwing; the page still previews.
  factory BackupPreview.parse(Map<String, dynamic> payload) {
    String name = '';
    String? opening;
    final book = payload['book'];
    if (book is Map) {
      name = '${book['name'] ?? ''}';
      final od = book['opening_date'];
      if (od != null) {
        final raw = od.toString();
        opening = raw.length >= 10 ? raw.substring(0, 10) : raw;
        if (opening.isEmpty || opening == 'null') opening = null;
      }
    }
    int len(Object? raw) => raw is List ? raw.length : 0;
    return BackupPreview(
      bookName: name,
      openingDate: opening,
      accounts: len(payload['accounts']),
      categories: len(payload['categories']),
      entries: len(payload['entries']),
      trades: len(payload['trades']),
    );
  }
}
