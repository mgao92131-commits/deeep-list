import '../domain/node.dart';

enum SmartListType { today, favorites, dueDates }

enum SmartDateGroup { overdue, today, tomorrow, later }

class SmartListQuery {
  const SmartListQuery._();

  static bool includes(SmartListType type, Node node, DateTime today) {
    if (node.isDone || node.isArchived) return false;
    return switch (type) {
      SmartListType.favorites => node.isFavorite,
      SmartListType.dueDates => node.dueDate != null,
      SmartListType.today =>
        node.dueDate != null &&
            !Node.normalizeDate(
              node.dueDate,
            )!.isAfter(Node.normalizeDate(today)!),
    };
  }

  static SmartDateGroup dateGroup(DateTime date, DateTime today) {
    final day = Node.normalizeDate(date)!;
    final current = Node.normalizeDate(today)!;
    if (day.isBefore(current)) return SmartDateGroup.overdue;
    if (day == current) return SmartDateGroup.today;
    if (day == DateTime(current.year, current.month, current.day + 1)) {
      return SmartDateGroup.tomorrow;
    }
    return SmartDateGroup.later;
  }
}
