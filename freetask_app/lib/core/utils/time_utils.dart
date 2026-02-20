import 'package:intl/intl.dart';

/// Utility class for Malaysia Time (UTC+8) display.
///
/// IMPORTANT: Do NOT modify the original DateTime object's timezone.
/// Only apply the +8 offset at the display/presentation layer.
class TimeUtils {
  static const Duration _malaysiaOffset = Duration(hours: 8);

  /// Convert any DateTime to Malaysia Time (UTC+8) for display purposes.
  /// Always converts from UTC first to ensure consistent behavior
  /// regardless of device timezone settings.
  static DateTime toMalaysiaTime(DateTime dateTime) {
    return dateTime.toUtc().add(_malaysiaOffset);
  }

  /// Format a DateTime as a short time string in Malaysia Time.
  /// Example output: "9:04 AM" or "11:30 PM"
  static String formatTime(DateTime dateTime) {
    final myTime = toMalaysiaTime(dateTime);
    return DateFormat('h:mm a').format(myTime);
  }

  /// Format timestamp for chat list (like WhatsApp).
  /// - Today: "9:04 AM"
  /// - Yesterday: "Semalam"
  /// - Within 7 days: "Isnin", "Selasa", etc.
  /// - Older: "19/02/25"
  static String formatChatListTime(DateTime dateTime) {
    final myTime = toMalaysiaTime(dateTime);
    final now = toMalaysiaTime(DateTime.now());

    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(myTime.year, myTime.month, myTime.day);

    if (messageDate == today) {
      return DateFormat('h:mm a').format(myTime);
    } else if (messageDate == yesterday) {
      return 'Semalam';
    } else if (today.difference(messageDate).inDays < 7) {
      return DateFormat('EEE').format(myTime); // Mon, Tue etc.
    } else {
      return DateFormat('dd/MM/yy').format(myTime);
    }
  }

  /// Format date header label for chat room (above grouped messages).
  /// - Today: "Hari Ini"
  /// - Yesterday: "Semalam"
  /// - Older: "19/02/2026"
  static String formatDateHeader(DateTime dateTime) {
    final myTime = toMalaysiaTime(dateTime);
    final now = toMalaysiaTime(DateTime.now());

    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(myTime.year, myTime.month, myTime.day);

    if (messageDate == today) {
      return 'Hari Ini';
    } else if (messageDate == yesterday) {
      return 'Semalam';
    } else {
      return DateFormat('dd/MM/yyyy').format(myTime);
    }
  }

  /// Check if two DateTimes are on different days (in Malaysia Time).
  static bool isDifferentDay(DateTime a, DateTime b) {
    final myA = toMalaysiaTime(a);
    final myB = toMalaysiaTime(b);
    return myA.year != myB.year || myA.month != myB.month || myA.day != myB.day;
  }
}
