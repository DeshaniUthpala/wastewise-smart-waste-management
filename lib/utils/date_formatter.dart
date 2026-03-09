import 'package:intl/intl.dart';

class DateFormatter {
  static String timeAgo(DateTime dateTime) {
    final duration = DateTime.now().difference(dateTime);

    if (duration.inDays > 7) {
      return DateFormat('MMM d, y').format(dateTime);
    } else if (duration.inDays >= 1) {
      return '${duration.inDays} ${duration.inDays == 1 ? "day" : "days"} ago';
    } else if (duration.inHours >= 1) {
      return '${duration.inHours} ${duration.inHours == 1 ? "hour" : "hours"} ago';
    } else if (duration.inMinutes >= 1) {
      return '${duration.inMinutes} ${duration.inMinutes == 1 ? "minute" : "minutes"} ago';
    } else {
      return 'Just now';
    }
  }

  static String formatDuration(DateTime start, DateTime end) {
    final diff = end.difference(start);
    if (diff.inDays >= 1) {
      return '${diff.inDays}d ${diff.inHours % 24}h';
    } else if (diff.inHours >= 1) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m';
    } else {
      return '${diff.inMinutes}m';
    }
  }
}
