import 'package:intl/intl.dart';

/// Standardized formatters for dates and amounts across the Freetask application.
/// Use these formatters to ensure consistency in how dates and currency are displayed.
class AppFormatters {
  AppFormatters._();

  // ============================================================================
  // Date Formatters
  // ============================================================================

  /// Format date as "dd MMM yyyy" (e.g., "04 Des 2025")
  static String formatDate(DateTime? date) {
    if (date == null) return 'Tarikh tidak tersedia';
    return DateFormat('dd MMM yyyy').format(date.toLocal());
  }

  /// Format date with time as "dd MMM yyyy, h:mm a" (e.g., "04 Des 2025, 9:30 PM")
  static String formatDateTime(DateTime? date) {
    if (date == null) return 'Tarikh tidak tersedia';
    return DateFormat('dd MMM yyyy, h:mm a').format(date.toLocal());
  }

  /// Format date as relative time (e.g., "2 hari lalu", "3 jam lalu")
  static String formatRelativeDate(DateTime? date) {
    if (date == null) return 'Tarikh tidak tersedia';

    final now = DateTime.now();
    final difference = now.difference(date.toLocal());

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years tahun lalu';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months bulan lalu';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} hari lalu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minit lalu';
    } else {
      return 'Baru sahaja';
    }
  }

  /// Format date as short date "dd/MM/yyyy" (e.g., "04/12/2025")
  static String formatShortDate(DateTime? date) {
    if (date == null) return 'Tarikh tidak tersedia';
    return DateFormat('dd/MM/yyyy').format(date.toLocal());
  }

  /// Format time only as "h:mm a" (e.g., "9:30 PM")
  static String formatTime(DateTime? date) {
    if (date == null) return 'Masa tidak tersedia';
    return DateFormat('h:mm a').format(date.toLocal());
  }

  // ============================================================================
  // Amount Formatters
  // ============================================================================

  /// Format amount as currency with RM prefix (e.g., "RM150.00")
  static String formatAmount(double? amount, {bool showInvalid = true}) {
    if (amount == null || amount <= 0) {
      return showInvalid ? 'Jumlah tidak sah / sila refresh' : 'RM0.00';
    }
    return 'RM${amount.toStringAsFixed(2)}';
  }

  /// Format amount as currency without decimal if whole number (e.g., "RM150" or "RM150.50")
  static String formatAmountCompact(double? amount, {bool showInvalid = true}) {
    if (amount == null || amount <= 0) {
      return showInvalid ? 'Jumlah tidak sah / sila refresh' : 'RM0';
    }

    if (amount == amount.roundToDouble()) {
      return 'RM${amount.toStringAsFixed(0)}';
    }
    return 'RM${amount.toStringAsFixed(2)}';
  }

  /// Format amount with thousands separator (e.g., "RM1,500.00")
  static String formatAmountWithSeparator(double? amount,
      {bool showInvalid = true}) {
    if (amount == null || amount <= 0) {
      return showInvalid ? 'Jumlah tidak sah / sila refresh' : 'RM0.00';
    }

    final formatter = NumberFormat('#,##0.00', 'en_US');
    return 'RM${formatter.format(amount)}';
  }

  // ============================================================================
  // Helper Functions
  // ============================================================================

  /// Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Check if date is yesterday
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  /// Format date with "Today", "Yesterday", or date
  static String formatSmartDate(DateTime? date) {
    if (date == null) return 'Tarikh tidak tersedia';

    if (isToday(date)) {
      return 'Hari ini, ${formatTime(date)}';
    } else if (isYesterday(date)) {
      return 'Semalam, ${formatTime(date)}';
    } else {
      return formatDateTime(date);
    }
  }
}
