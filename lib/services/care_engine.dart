import '../models/care_item.dart';
import '../models/person.dart';
import '../data/health_rules.dart';

class CareEngine {
  static List<CareItem> generateCareItems(Person person) {
    final List<CareItem> items = [];
    final now = DateTime.now();

    // ۱. پردازش جدول واکسیناسیون کشوری
    for (final rule in HealthRules.vaccineRules) {
      final dueDate = _calculateDueDate(
        person.birthDate,
        days: rule['days'] as int?,
        months: rule['months'] as int?,
        years: rule['years'] as int?,
      );

      items.add(
        CareItem(
          id: '${person.id}-${rule['id']}',
          personId: person.id,
          personName: person.fullName.isEmpty ? 'عضو خانواده' : person.fullName,
          title: rule['title'] as String,
          description: rule['description'] as String? ?? '',
          dueDate: dueDate,
          kind: CareKind.vaccine,
          source: 'برنامه واکسیناسیون کشوری سامانه سیب',
          targetAge: rule['targetAge'] as String? ?? '',
        ),
      );
    }

    // ۲. بیماری‌های زمینه‌ای
    for (final cond in person.conditions) {
      final matches = HealthRules.conditionRules.where((r) => r['condition'] == cond);
      for (final rule in matches) {
        final step = rule['everyDays'] as int;
        DateTime cursor = person.createdAt;
        while (!cursor.isAfter(now)) {
          cursor = cursor.add(Duration(days: step));
        }
        items.add(
          CareItem(
            id: '${person.id}-${rule['id']}-${cursor.millisecondsSinceEpoch}',
            personId: person.id,
            personName: person.fullName,
            title: '${rule['title']} (${rule['condition']})',
            dueDate: cursor,
            kind: CareKind.checkup,
            source: 'راهنمای بالینی بیماری‌های مزمن',
          ),
        );
      }
    }

    // ۳. مراقبت‌های بارداری
    if (person.gender == 'زن' && person.pregnant && person.pregnancyStartDate != null) {
      for (final r in HealthRules.pregnancyRules) {
        final weeks = r['weeks'] as int;
        final dueDate = person.pregnancyStartDate!.add(Duration(days: weeks * 7));
        items.add(
          CareItem(
            id: '${person.id}-${r['id']}',
            personId: person.id,
            personName: person.fullName,
            title: r['title'] as String,
            dueDate: dueDate,
            kind: CareKind.pregnancy,
            source: 'دستورالعمل سلامت مادران باردار',
          ),
        );
      }
    }

    // مرتب‌سازی صعودی بر اساس تاریخ سررسید
    items.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return items;
  }

  static DateTime _calculateDueDate(
    DateTime base, {
    int? days,
    int? months,
    int? years,
  }) {
    if (days != null && days > 0) {
      return base.add(Duration(days: days));
    }
    if (months != null && months > 0) {
      int y = base.year + ((base.month + months - 1) ~/ 12);
      int m = ((base.month + months - 1) % 12) + 1;
      int d = base.day;
      if (d > 28) {
        final maxDays = DateTime(y, m + 1, 0).day;
        if (d > maxDays) d = maxDays;
      }
      return DateTime(y, m, d);
    }
    if (years != null && years > 0) {
      return DateTime(base.year + years, base.month, base.day);
    }
    return base;
  }
}
