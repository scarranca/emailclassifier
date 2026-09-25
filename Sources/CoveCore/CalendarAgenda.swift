import Foundation

public enum CalendarAgenda {
  public static func weekStart(containing date: Date, calendar: Calendar = .current) -> Date {
    let day = calendar.startOfDay(for: date)
    let offset = (calendar.component(.weekday, from: day) + 5) % 7
    return calendar.date(byAdding: .day, value: -offset, to: day) ?? day
  }

  /// A stable Monday-first, six-row month grid, including adjacent-month dates.
  public static func monthDays(containing date: Date, calendar: Calendar = .current) -> [Date] {
    guard let month = calendar.dateInterval(of: .month, for: date) else { return [] }
    let start = weekStart(containing: month.start, calendar: calendar)
    return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
  }

  public static func events(_ events: [LocalEvent], on date: Date, calendar: Calendar = .current)
    -> [LocalEvent]
  {
    guard let day = calendar.dateInterval(of: .day, for: date) else { return [] }
    return events.filter { $0.end > $0.start && $0.start < day.end && $0.end > day.start }
      .sorted {
        if ($0.allDay == true) != ($1.allDay == true) { return $0.allDay == true }
        if $0.start != $1.start { return $0.start < $1.start }
        return $0.id < $1.id
      }
  }

  /// Union duration avoids counting overlapping meetings twice. All-day events are excluded.
  public static func scheduledMinutes(
    _ events: [LocalEvent], on date: Date, calendar: Calendar = .current
  ) -> Int {
    guard let day = calendar.dateInterval(of: .day, for: date) else { return 0 }
    let intervals = events.filter { $0.allDay != true && $0.end > $0.start }
      .compactMap { event -> DateInterval? in
        let start = max(day.start, event.start), end = min(day.end, event.end)
        return end > start ? DateInterval(start: start, end: end) : nil
      }.sorted { $0.start < $1.start }
    var total: TimeInterval = 0
    var through = day.start
    for interval in intervals where interval.end > through {
      total += interval.end.timeIntervalSince(max(through, interval.start))
      through = interval.end
    }
    return Int(total / 60)
  }

  /// Finds a future, hour-or-longer gap within 9 AM–5 PM, aligned to quarter hours.
  /// Callers must establish coverage for remote calendars before presenting availability.
  public static func focusInterval(
    _ events: [LocalEvent], on date: Date, now: Date,
    calendar: Calendar = .current
  ) -> DateInterval? {
    guard let start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date),
      let end = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: date), now < end
    else { return nil }
    func roundedUp(_ date: Date) -> Date {
      let minute = calendar.component(.minute, from: date)
      let floor = calendar.dateInterval(of: .minute, for: date)?.start ?? date
      let aligned = minute % 15 == 0 && date == floor
      let increment = aligned ? 0 : 15 - minute % 15
      return calendar.date(byAdding: .minute, value: increment, to: floor) ?? date
    }
    var cursor = roundedUp(max(start, now))
    let busy = self.events(events, on: date, calendar: calendar)
      .filter { $0.blocksTime != false }
      .sorted { $0.start < $1.start }
    for event in busy {
      if event.end <= cursor || event.start >= end { continue }
      let gapEnd = min(event.start, end)
      if gapEnd.timeIntervalSince(cursor) >= 3600 {
        return DateInterval(start: cursor, end: min(cursor.addingTimeInterval(7200), gapEnd))
      }
      cursor = roundedUp(max(cursor, event.end))
    }
    guard end.timeIntervalSince(cursor) >= 3600 else { return nil }
    return DateInterval(start: cursor, end: min(cursor.addingTimeInterval(7200), end))
  }
}
