import Foundation

public enum CalendarSearch {
  /// Search cached content only. Ongoing/upcoming events come first, then recent past events.
  public static func matches(_ events: [LocalEvent], query: String, now: Date) -> [LocalEvent] {
    let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
    return events.filter { event in
      let guests = (event.attendees ?? []).flatMap { [$0.name ?? "", $0.email ?? ""] }
      let text = ([event.title, event.details ?? "", event.location ?? ""] + guests)
        .joined(separator: "\n")
      return terms.allSatisfy { text.localizedStandardContains($0) }
    }.sorted {
      let firstUpcoming = $0.end > now
      let secondUpcoming = $1.end > now
      if firstUpcoming != secondUpcoming { return firstUpcoming }
      if $0.start != $1.start { return firstUpcoming ? $0.start < $1.start : $0.start > $1.start }
      return $0.id < $1.id
    }
  }
}
