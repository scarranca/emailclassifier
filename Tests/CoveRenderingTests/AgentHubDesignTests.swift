import AppKit
import CoveCore
import SwiftUI
import XCTest
@testable import Cove

@MainActor final class AgentHubDesignTests: XCTestCase {
  func testDottedWavesHaveSmallMotionAndNoFalsePeaksForEmptyMail() {
    let counts = [22, 31, 12, 15, 42, 36, 28]
    let a = MailTideGeometry.dots(counts: counts, width: 644, height: 128, time: 0).flatMap { $0 }
    let b = MailTideGeometry.dots(counts: counts, width: 644, height: 128, time: 3.5).flatMap { $0 }
    XCTAssertGreaterThan(a.count, 2000)
    XCTAssertEqual(a.count, b.count)
    let movements = zip(a, b).map { abs($0.y - $1.y) }
    XCTAssertGreaterThan(movements.max() ?? 0, 1)
    XCTAssertLessThanOrEqual(movements.max() ?? 0, 3.2)
    XCTAssertTrue(zip(a, b).allSatisfy { $0.x == $1.x })
    XCTAssertTrue(a.allSatisfy { $0.radius < 1 && $0.y > 0 && $0.y < 128 })
    let emptyA = MailTideGeometry.dots(counts: [0,0,0,0,0,0,0], width: 644, height: 128, time: 0).flatMap { $0 }
    let emptyB = MailTideGeometry.dots(counts: [0,0,0,0,0,0,0], width: 644, height: 128, time: 99).flatMap { $0 }
    XCTAssertEqual(emptyA.map(\.y), emptyB.map(\.y))
    XCTAssertEqual(Set(emptyA.map(\.y)).count, 1)
    XCTAssertTrue(MailTideGeometry.shouldAnimate(reduceMotion: false, active: true, visible: true, total: 186))
    XCTAssertFalse(MailTideGeometry.shouldAnimate(reduceMotion: true, active: true, visible: true, total: 186))
    XCTAssertFalse(MailTideGeometry.shouldAnimate(reduceMotion: false, active: false, visible: true, total: 186))
    XCTAssertFalse(MailTideGeometry.shouldAnimate(reduceMotion: false, active: true, visible: false, total: 186))
    XCTAssertFalse(MailTideGeometry.shouldAnimate(reduceMotion: false, active: true, visible: true, total: 0))
  }

  func testHomeDesignAndWavePhasesRenderOffscreen() async throws {
    _ = NSApplication.shared; DesignAssets.registerFonts()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let database = try Database(url: directory.appendingPathComponent("mail.sqlite"))
    let store = try AppStore(database: database, accountEmail: "me@example.com", gmail: GmailClient(), gmailTokenProvider: { "fixture" }, syncClock: Date.init)
    let now = Date(); let calendar = Calendar.current; let today = calendar.startOfDay(for: now)
    store.now = now; store.screen = "home"; store.isSample = true
    let counts = [22, 31, 12, 15, 42, 36, 28]
    for day in 0..<7 {
      for index in 0..<counts[day] {
        let date = calendar.date(byAdding: .day, value: day - 6, to: today)!
        store.mails.append(Mail(id: "received-\(day)-\(index)", sender: "Maya Chen", senderEmail: "maya@example.com", subject: "Weekly update", body: "Notes from our team.", date: date, labels: ["INBOX"]))
      }
    }
    let titles = ["Sign off on the website launch", "Choose the Q3 brand direction", "Approve the June services invoice"]
    let excerpts = ["Your approval keeps Thursday’s launch on schedule.", "The design team is waiting on a direction before production.", "Confirm the invoice so Finance can schedule payment."]
    for index in 0..<3 {
      store.mails[index].subject = titles[index]
      store.mails[index].body = excerpts[index]
      store.mails[index].date = now.addingTimeInterval(-Double(index * 60 + 100))
      store.mails[index].decision = Decision(category: .work, confidence: 0.9, needsReply: 0.8, urgent: 0.8, excerpt: excerpts[index], model: "fixture")
      store.mails[index].attachments = [MailAttachment(id: "file", filename: index == 0 ? "Launch checklist.pdf" : "Project notes.pdf", mimeType: "application/pdf")]
    }
    store.mails[0].draft = "The launch looks ready."
    for (index, person) in ["Jamie Lee", "Olivia Reed"].enumerated() {
      store.mails.append(Mail(id: "sent-\(index)", threadID: "thread-\(index)", sender: "Me", senderEmail: "me@example.com", to: "\(person) <person\(index)@example.com>", subject: index == 0 ? "Confirm mobile QA sign-off" : "Send the revised proposal", body: "Could you share an update?", date: now.addingTimeInterval(-Double(index + 2) * 86400), labels: ["SENT"]))
    }
    var meeting = LocalEvent(title: "Launch readiness", start: now.addingTimeInterval(3600), end: now.addingTimeInterval(5400))
    meeting.attendees = [CalendarAttendee(name: "Maya Chen"), CalendarAttendee(name: "Priya Shah")]
    meeting.details = "Resolve the final launch blockers before Thursday.\n\n• Is mobile QA complete?\n• Who owns the launch-day checklist?"
    store.events = [meeting]
    var launchAgent = CustomAgent(); launchAgent.name = "Launch assistant"; launchAgent.status = .active
    launchAgent.rules = [CustomAgentRule(condition: "Project updates", labelName: "Launch"), CustomAgentRule(condition: "Invoices", labelName: "Finance")]
    store.customAgents.agents = [launchAgent]
    store.gmailLabels = [GmailLabel(id: "launch", name: "Launch"), GmailLabel(id: "finance", name: "Finance")]
    for index in 0..<store.mails.count where index % 3 == 0 { store.mails[index].labels.insert(index % 2 == 0 ? "launch" : "finance") }
    for width in [1040.0, 1440.0] {
      let content = HStack(spacing: 0) {
        Sidebar(store: store).frame(width: 224); Divider()
        AgentHubView(store: store, loadLiveData: false)
      }
      _ = try await render(content, size: CGSize(width: width, height: 1080), path: "/tmp/cove-hub-0133-\(Int(width)).png")
    }
    let tide = MailTide(mails: store.mails, now: now)
    let phase0 = try await render(MailTideView(tide: tide, previewTime: 0).padding(26).background(Color(red: 0.114, green: 0.125, blue: 0.165)), size: CGSize(width: 696, height: 290), path: "/tmp/cove-wave-0.png")
    let phase1 = try await render(MailTideView(tide: tide, previewTime: 3.5).padding(26).background(Color(red: 0.114, green: 0.125, blue: 0.165)), size: CGSize(width: 696, height: 290), path: "/tmp/cove-wave-1.png")
    XCTAssertNotEqual(phase0, phase1)

    let source = store.mails[0]
    store.prepareHomeDelegation(source)
    let delegated = try XCTUnwrap(store.mails.first { $0.id == store.composeID })
    XCTAssertTrue(store.showComposer); XCTAssertEqual(delegated.to, "")
    XCTAssertEqual(delegated.subject, "Fwd: " + source.subject)
    XCTAssertTrue(delegated.body.contains(source.body)); XCTAssertTrue(delegated.body.contains("not included"))
    XCTAssertEqual(delegated.labels, ["DRAFT"])
    store.prepareHomeFollowUp(store.mails.first { $0.id == "sent-0" }!)
    let followup = try XCTUnwrap(store.mails.first { $0.id == store.composeID })
    XCTAssertEqual(followup.to, "Jamie Lee <person0@example.com>")
    XCTAssertTrue(followup.body.isEmpty)
    store.showComposer = false
    store.reviewHomeDecision(source)
    XCTAssertEqual(store.selectedID, source.id); XCTAssertEqual(store.screen, "mail")
    var agent = CustomAgent.invoiceTemplate; agent.name = "Review agent"
    var run = CustomAgentRun(agent: agent, mail: source); run.replySuggestion = "Ready for review"
    store.customAgents.agents = [agent]; store.customAgents.runs = [run]
    store.reviewHomeDecision(source)
    XCTAssertEqual(store.screen, "agents"); XCTAssertEqual(store.agentActivityID, agent.id)
  }

  func testLiveTimelineProducesMotionWithoutShowingAWindow() async throws {
    _ = NSApplication.shared; DesignAssets.registerFonts()
    let now = Date()
    let mails = (0..<7).flatMap { day in
      (0..<(day * 3 + 2)).map { index in
        Mail(id: "\(day)-\(index)", sender: "Test", senderEmail: "test@example.com", subject: "", body: "", date: now.addingTimeInterval(-Double(day) * 86400))
      }
    }
    let tide = MailTide(mails: mails, now: now)
    for phase in [ScenePhase.active, .inactive] {
      let content = MailTideView(tide: tide).padding(26)
        .background(Color(red: 0.114, green: 0.125, blue: 0.165))
        .environment(\.scenePhase, phase).coordinateSpace(name: "hub-scroll")
      let host = NSHostingView(rootView: content)
      let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 696, height: 290), styleMask: [.borderless], backing: .buffered, defer: false)
      window.isReleasedWhenClosed = false; window.contentView = host
      for _ in 0..<10 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(30)) }
      func capture() throws -> Data {
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
      }
      let first = try capture()
      for _ in 0..<30 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(40)) }
      let second = try capture()
      if phase == .active { XCTAssertNotEqual(first, second, "The live TimelineView must advance the dot field") }
      else { XCTAssertEqual(first, second, "Inactive windows must stop the motion") }
      XCTAssertFalse(window.isVisible); window.close()
    }
  }

  private func render<V: View>(_ view: V, size: CGSize, path: String) async throws -> Data {
    let host = NSHostingView(rootView: view)
    let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = host
    defer { window.close() }
    for _ in 0..<8 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(30)) }
    XCTAssertFalse(window.isVisible)
    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds)); host.cacheDisplay(in: host.bounds, to: bitmap)
    let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    try data.write(to: URL(fileURLWithPath: path))
    return data
  }
}
