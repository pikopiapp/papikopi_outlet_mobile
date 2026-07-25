const Duration _jakartaOffset = Duration(hours: 7);

/// Parse a timestamp that is stored without timezone as an instant in UTC.
DateTime parseTimestampAssumeUTC(Object timestamp) {
  if (timestamp is DateTime) {
    return timestamp.toUtc();
  }

  var value = timestamp.toString().trim();
  if (value.isEmpty) {
    throw FormatException('Empty timestamp');
  }

  value = value.replaceAll(RegExp(r'\s+'), 'T');
  value = value.replaceAll(RegExp(r'\$\d+'), '');
  value = value.replaceAll(RegExp(r'([+-]\d{2})(\d{2})$'), r'$1:$2');
  value = value.replaceAllMapped(
    RegExp(r'(\.\d{3})\d+'),
    (match) => match.group(1)!,
  );
  value = value.replaceAllMapped(
    RegExp(r'\.(\d{1,2})(?=[^\d]|$)'),
    (match) => '.${match.group(1)!.padRight(3, '0')}',
  );

  if (!RegExp(r'([zZ]|[+-]\d{2}:?\d{2})$').hasMatch(value)) {
    value = '$value' 'Z';
  }

  try {
    return DateTime.parse(value).toUtc();
  } on FormatException {
    final cleaned = value.replaceAll(RegExp(r'[^0-9TZ:+.-]'), '');
    if (cleaned.isNotEmpty && cleaned != value) {
      return DateTime.parse(cleaned).toUtc();
    }
    rethrow;
  }
}

/// Convert an instant to the Asia/Jakarta wall-clock time.
DateTime toJakartaDateTime(Object timestamp) {
  final instant = parseTimestampAssumeUTC(timestamp).add(_jakartaOffset);
  return DateTime(
    instant.year,
    instant.month,
    instant.day,
    instant.hour,
    instant.minute,
    instant.second,
    instant.millisecond,
  );
}

/// Return the Jakarta calendar date only for business-day comparisons.
DateTime toJakartaDate(Object timestamp) {
  final value = toJakartaDateTime(timestamp);
  return DateTime(value.year, value.month, value.day);
}

String _monthName(int month) {
  const months = <String>[
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Ags',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  return months[month];
}

/// Format a timestamp for display in Asia/Jakarta time.
String formatTimestampForJakartaDisplay(Object timestamp, {String pattern = 'HH:mm'}) {
  final date = toJakartaDateTime(timestamp);

  if (pattern == 'HH:mm') {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  if (pattern == 'dd MMM yyyy') {
    return '${date.day.toString().padLeft(2, '0')} ${_monthName(date.month)} ${date.year}';
  }

  if (pattern == 'dd MMM yyyy HH:mm') {
    return '${date.day.toString().padLeft(2, '0')} ${_monthName(date.month)} ${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  return '${date.day.toString().padLeft(2, '0')} ${_monthName(date.month)} ${date.year}';
}

/// Format a full date-time string for labels in Asia/Jakarta time.
String formatDateTimeForJakartaDisplay(
  Object timestamp, {
    String pattern = 'dd MMM yyyy HH:mm',
  }) {
  return formatTimestampForJakartaDisplay(timestamp, pattern: pattern);
}
