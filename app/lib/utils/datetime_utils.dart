import 'package:intl/intl.dart';

class DateTimeUtils {
  /// Formats a DateTime according to the user's requirement:
  /// - Today: "10:45 AM" (HH:mm a)
  /// - Yesterday: "Yesterday"
  /// - Older: "29/01/26" (dd/MM/yy)
  /// 
  /// Automatically converts UTC to Local time.
  static String formatSmartDate(DateTime date) {
    final localDate = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(localDate.year, localDate.month, localDate.day);

    if (dateToCheck == today) {
      return DateFormat('h:mm a').format(localDate);
    } else if (dateToCheck == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('dd/MM/yy').format(localDate);
    }
  }

  /// Returns true if the date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    final localDate = date.toLocal();
    return now.year == localDate.year && now.month == localDate.month && now.day == localDate.day;
  }
}
