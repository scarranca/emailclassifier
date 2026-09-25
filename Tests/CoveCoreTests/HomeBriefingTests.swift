import XCTest
@testable import CoveCore

final class HomeBriefingTests: XCTestCase {
  func testSevenLocalDaysAcrossDaylightSavingExcludeOutgoingAndFutureMail() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
    let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 12)))
    let first = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 4)))
    func mail(_ id: String, _ date: Date, _ labels: Set<String> = ["INBOX"]) -> Mail {
      Mail(id: id, sender: "Alex", senderEmail: "alex@example.com", subject: "Hello", body: "", date: date, labels: labels)
    }
    let start = mail("first", first)
    let input = [start, start, mail("archive", now, []), mail("before", first.addingTimeInterval(-1)),
                 mail("future", now.addingTimeInterval(1)), mail("sent", now, ["SENT", "INBOX"]),
                 mail("draft", now, ["DRAFT"]), mail("spam", now, ["SPAM"]), mail("trash", now, ["TRASH"])]
    let tide = MailTide(mails: input, now: now, calendar: calendar)
    XCTAssertEqual(tide.days.count, 7)
    XCTAssertEqual(tide.days.map(\.count), [1, 0, 0, 0, 0, 0, 1])
    XCTAssertEqual(tide.total, 2)
    XCTAssertEqual(tide.days[5].date.timeIntervalSince(tide.days[4].date), 23 * 3600)
  }
  func testWaitingThreadsHaveNoLaterReplyAndAreBoundedToRecentSentMail() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func sent(_ id: String, thread: String, days: Double) -> Mail {
      Mail(id: id, threadID: thread, sender: "Me", senderEmail: "me@example.com", to: "Alex Lee <alex@example.com>", subject: "Check-in", body: "", date: now.addingTimeInterval(-days * 86400), labels: ["SENT"])
    }
    let pending = sent("pending", thread: "pending-thread", days: 2)
    let responded = sent("responded", thread: "responded-thread", days: 3)
    var reply = responded; reply.id = "reply"; reply.labels = ["INBOX"]; reply.date = now.addingTimeInterval(-86400)
    var draft = pending; draft.id = "draft"; draft.labels = ["DRAFT"]; draft.date = now
    var toSelf = pending; toSelf.id = "self"; toSelf.threadID = "self-thread"; toSelf.to = "me@example.com"
    let mails = [pending, responded, reply, draft, toSelf, sent("old", thread: "old", days: 31), sent("recent", thread: "recent", days: 0.5), sent("no-thread", thread: "", days: 2)]
    XCTAssertEqual(HomeBriefing.awaitingReplies(mails: mails, accountEmail: "me@example.com", now: now).map(\.id), ["pending"])
    XCTAssertEqual(HomeBriefing.recipientNames(pending), "Alex Lee")
  }
}
