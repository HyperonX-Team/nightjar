const _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatDateTime(DateTime time) {
  final local = time.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day ${_months[local.month - 1]} ${local.year}, $hour:$minute';
}

String formatClock(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String formatAge(DateTime then, DateTime now) {
  final age = now.difference(then);
  if (age.inSeconds < 5) {
    return 'just now';
  }
  if (age.inMinutes < 1) {
    return '${age.inSeconds} seconds ago';
  }
  if (age.inHours < 1) {
    final minutes = age.inMinutes;
    return minutes == 1 ? '1 minute ago' : '$minutes minutes ago';
  }
  final hours = age.inHours;
  return hours == 1 ? '1 hour ago' : '$hours hours ago';
}
