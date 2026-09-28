enum CareKind { vaccine, checkup, screening, pregnancy, periodic, reminder }

enum DueStatus { overdue, today, upcoming }

class CareItem {
  final String id;
  final String personId;
  final String personName;
  final String title;
  final String description;
  final DateTime dueDate;
  final CareKind kind;
  final String source;
  final String targetAge;

  CareItem({
    required this.id,
    required this.personId,
    required this.personName,
    required this.title,
    this.description = '',
    required this.dueDate,
    required this.kind,
    required this.source,
    this.targetAge = '',
  });

  DueStatus get status {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (target.isBefore(today)) return DueStatus.overdue;
    if (target.isAtSameMomentAs(today)) return DueStatus.today;
    return DueStatus.upcoming;
  }

  int get differenceInDays {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return target.difference(today).inDays;
  }

  String get remainingText {
    final days = differenceInDays;
    if (days < 0) {
      final abs = days.abs();
      if (abs < 30) return '$abs روز گذشته (تأخیر)';
      final months = abs ~/ 30;
      final remDays = abs % 30;
      return remDays > 0 ? '$months ماه و $remDays روز گذشته' : '$months ماه گذشته';
    } else if (days == 0) {
      return 'امروز (موعد تزریق)';
    } else if (days == 1) {
      return 'فردا';
    } else if (days < 30) {
      return '$days روز دیگر';
    } else {
      final months = days ~/ 30;
      final remDays = days % 30;
      return remDays > 0 ? '$months ماه و $remDays روز دیگر' : '$months ماه دیگر';
    }
  }
}
