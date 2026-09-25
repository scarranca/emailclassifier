import CoveCore
import SwiftUI

struct AgentHubView: View {
  @Bindable var store: AppStore
  var loadLiveData = true
  @Environment(\.scenePhase) private var scenePhase
  @State private var weather: HomeWeatherController
  @State private var showAllFiles = false
  @State private var lastIgnored: String?

  init(store: AppStore, loadLiveData: Bool = true, weather: HomeWeatherController? = nil) {
    self.store = store
    self.loadLiveData = loadLiveData
    _weather = State(initialValue: weather ?? HomeWeatherController(defaults: loadLiveData ? .standard : UserDefaults(suiteName: "Cove-Weather-Preview-" + UUID().uuidString)!))
  }

  private static let horizon = Bundle.module.url(
    forResource: "agent-hub-horizon", withExtension: "jpg"
  ).flatMap { NSImage(contentsOf: $0) }

  private var mail: [Mail] {
    store.mails.filter { !store.queuedTrashIDs.contains($0.id) && !$0.labels.contains("TRASH") && !$0.labels.contains("SPAM") }
  }
  private var inbox: [Mail] {
    mail.filter {
      $0.labels.contains("INBOX") && ($0.snoozedUntil ?? .distantPast) <= store.now
    }.sorted { $0.date > $1.date }
  }
  private var priorities: [Mail] { inbox.filter(\.isPriority) }
  private var files: [HubFile] {
    mail.sorted { $0.date > $1.date }.flatMap { message in
      message.availableAttachments.map { HubFile(message: message, attachment: $0) }
    }
  }
  private var contacts: [Mail] {
    KeepInTouch.candidates(mails: mail, accountEmail: store.accountEmail, now: store.now, ignored: store.ignoredKeepInTouch)
  }
  private var greeting: String {
    if store.isSample { return "A little head start, Alex." }
    return "A little head start."
  }
  private var briefing: String {
    if inbox.isEmpty { return "Your next clear moment starts here. Sync Gmail to catch up." }
    if priorities.isEmpty {
      return "No priority messages in your downloaded inbox. A little more room to focus."
    }
    return
      "\(priorities.count) \(priorities.count == 1 ? "message needs" : "messages need") your attention. Start with what matters."
  }

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        toolbar
        Divider()
        ScrollView {
          VStack(alignment: .leading, spacing: 25) {
            briefingBanner(compact: geometry.size.width < 760)
            if geometry.size.width >= 900 {
              hubColumns(width: geometry.size.width)
            } else {
              HomeCalendarView(store: store)
              prioritySection
              HomeWeatherView(weather: weather)
              reconnectSection
              recentSection
              activitySection
            }
            Label(
              "A little help, never the final say. You approve every send.",
              systemImage: "checkmark.shield"
            ).font(.coveMetadata).foregroundStyle(Palette.muted)
          }.padding(.horizontal, geometry.size.width < 760 ? 24 : 34).padding(.vertical, 26)
        }
      }.background(Palette.canvas).foregroundStyle(Palette.ink)
        .onChange(of: store.accountEmail) { _, _ in lastIgnored = nil }
        .task(id: "\(scenePhase)-\(store.calendarConnected)-\(store.accountEmail)") {
          guard loadLiveData, scenePhase == .active else { return }
          while !Task.isCancelled {
            await store.refreshHomeCalendar()
            do { try await Task.sleep(for: .seconds(120)) } catch { return }
          }
        }
        .task(id: scenePhase) {
          guard loadLiveData, scenePhase == .active else { return }
          while !Task.isCancelled {
            await weather.refresh()
            do { try await Task.sleep(for: .seconds(1800)) } catch { return }
          }
        }
    }
  }

  private func hubColumns(width: CGFloat) -> some View {
    let sidebarWidth = min(350, width * 0.30)
    return HStack(alignment: .top, spacing: 28) {
      VStack(alignment: .leading, spacing: 28) {
        HomeCalendarView(store: store)
        prioritySection
        recentSection
      }.frame(maxWidth: .infinity, alignment: .leading)
      VStack(alignment: .leading, spacing: 28) {
        HomeWeatherView(weather: weather)
        reconnectSection
        activitySection
      }.frame(width: sidebarWidth, alignment: .leading)
    }
    .overlay(alignment: .trailing) {
      Rectangle().fill(Palette.line).frame(width: 1)
        .padding(.trailing, sidebarWidth + 14).allowsHitTesting(false)
    }
  }

  private var toolbar: some View {
    HStack {
      Text("Agent Hub").font(.cove(size: 15, weight: .medium))
      if store.isSample {
        Text("Sample mailbox").font(.coveMetadata).foregroundStyle(Palette.muted)
      }
      Spacer()
      Text(store.now, format: .dateTime.weekday(.wide).month(.wide).day())
        .font(.cove(size: 12)).foregroundStyle(Palette.muted)
    }.padding(.horizontal, 34).frame(height: 62)
  }

  private func briefingBanner(compact: Bool) -> some View {
    HStack(spacing: 24) {
      VStack(alignment: .leading, spacing: 12) {
        Text(greeting).font(.cove(size: compact ? 25 : 29, weight: .medium))
          .foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
        Text(briefing).font(.cove(size: 13)).foregroundStyle(Color(white: 0.88))
          .lineSpacing(5).fixedSize(horizontal: false, vertical: true)
      }.frame(maxWidth: .infinity, alignment: .leading)
      Button {
        store.showAssistant = true
      } label: {
        Label("Ask Cove", systemImage: "sparkles")
      }.buttonStyle(SecondaryButton()).fixedSize()
    }.padding(.horizontal, 26).padding(.vertical, 24).frame(minHeight: 158)
      .background {
        GeometryReader { geometry in
          ZStack {
            Color(red: 0.114, green: 0.125, blue: 0.165)
            if let horizon = Self.horizon {
              Image(nsImage: horizon).resizable().scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                .opacity(0.42).accessibilityHidden(true)
            }
          }
        }
      }.clipShape(RoundedRectangle(cornerRadius: 10))
  }

  private var prioritySection: some View {
    VStack(alignment: .leading, spacing: 15) {
      HStack {
        Text("Worth your attention").font(HomeType.primarySection)
        Spacer()
        Text("\(priorities.count) \(priorities.count == 1 ? "message" : "messages")")
          .font(.coveMetadata).foregroundStyle(Palette.muted)
      }
      if priorities.isEmpty {
        emptyMessage(
          title: inbox.isEmpty ? "A clear place to begin" : "Nothing urgent has been flagged",
          detail: inbox.isEmpty
            ? "Sync your inbox to bring your latest messages into Cove."
            : "Organize downloaded mail to find messages that may need a reply.")
        Button(inbox.isEmpty ? "Sync Gmail" : "Organize mail") {
          Task {
            if inbox.isEmpty { await store.sync() } else { await store.classifyInbox() }
          }
        }.buttonStyle(SecondaryButton()).disabled(store.busy || store.isSample)
      } else {
        ForEach(Array(priorities.prefix(3))) { message in
          priorityRow(message)
        }
        if priorities.count > 3 {
          Button("View all priority mail →") {
            store.chooseFolder("Inbox")
            store.priorityOnly = true
            store.reconcileSelection()
          }.buttonStyle(.plain).font(HomeType.action)
        }
      }
    }
  }

  private func priorityRow(_ message: Mail) -> some View {
    VStack(spacing: 0) {
      Button {
        open(message)
      } label: {
        VStack(alignment: .leading, spacing: 10) {
          HStack(spacing: 8) {
            CoveAvatar(initials: message.initials, size: 26)
            Text(message.sender).font(HomeType.action).lineLimit(1)
            Spacer(minLength: 8)
            Text(message.date, format: .dateTime.month(.abbreviated).day())
              .font(.coveMetadata).foregroundStyle(Palette.muted).fixedSize()
          }
          HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
              Text(message.subject.isEmpty ? "No subject" : message.subject)
                .font(HomeType.itemTitle).lineLimit(2)
              Text(message.decision?.excerpt ?? String(message.body.prefix(160)))
                .font(HomeType.compactBody).foregroundStyle(Palette.body).lineSpacing(3).lineLimit(2)
              if message.decision?.excerpt != nil {
                Text(store.isSample ? "Sample source excerpt" : "From the email · selected by Jev")
                  .font(HomeType.metadata).foregroundStyle(Palette.muted)
              }
              if !message.draft.isEmpty {
                Label("Draft ready", systemImage: "square.and.pencil")
                  .font(.coveMetadata).foregroundStyle(Palette.body)
              }
            }.frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right").font(.cove(size: 11, weight: .medium))
              .foregroundStyle(Palette.muted).padding(.top, 3).accessibilityHidden(true)
          }
        }.multilineTextAlignment(.leading).padding(.vertical, 14).padding(.horizontal, 8)
          .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
      }.buttonStyle(HubEmailButtonStyle())
        .accessibilityLabel("Open email from \(message.sender): \(message.subject)")
        .help("Open email")
      MailQuickActions(store: store, mail: message)
        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8).padding(.bottom, 12)
      Divider()
    }
  }

  private var reconnectSection: some View {
    VStack(alignment: .leading, spacing: 15) {
      HStack {
        Text("Keep in touch").font(HomeType.supportingSection)
        Spacer()
        if !store.ignoredKeepInTouch.isEmpty {
          Menu {
            ForEach(store.ignoredKeepInTouch.sorted(), id: \.self) { address in
              Button("Suggest \(address) again") {
                if store.setKeepInTouchIgnored(address, ignored: false), lastIgnored == address { lastIgnored = nil }
              }
            }
          } label: { Text("Ignored (\(store.ignoredKeepInTouch.count))").font(HomeType.action) }
            .menuStyle(.borderlessButton).fixedSize().help("Restore ignored people")
        }
      }
      if let lastIgnored {
        HStack(alignment: .top, spacing: 10) {
          Text("\(lastIgnored) won’t be suggested here.").font(.coveMetadata).foregroundStyle(Palette.muted)
            .fixedSize(horizontal: false, vertical: true)
          Spacer(minLength: 0)
          Button("Undo") {
            if store.setKeepInTouchIgnored(lastIgnored, ignored: false) { self.lastIgnored = nil }
          }.buttonStyle(.plain).font(HomeType.action)
        }
      }
      Text("A small nudge goes a long way.").font(HomeType.compactBody).foregroundStyle(Palette.body)
      if contacts.isEmpty {
        emptyMessage(
          title: "Your people, close by",
          detail:
            "People from personal and work conversations appear here after syncing and organizing mail. Marketing and automated messages are excluded."
        )
      }
      ForEach(Array(contacts.prefix(2))) { message in
        VStack(alignment: .leading, spacing: 11) {
          HStack(spacing: 9) {
            CoveAvatar(initials: message.initials, size: 32)
            Text(message.sender).font(HomeType.supportingTitle).lineLimit(1)
            Spacer(minLength: 6)
            Button("Ignore") {
              if store.setKeepInTouchIgnored(message.senderEmail, ignored: true) {
                lastIgnored = ContactDirectory.normalizedEmail(message.senderEmail)
              }
            }.buttonStyle(.plain).font(HomeType.action).foregroundStyle(Palette.body)
              .help("Stop suggesting this person in Keep in touch")
              .accessibilityLabel("Ignore Keep in touch suggestions for \(message.sender)")
          }
          Text(
            "Last received \(message.date.formatted(date: .abbreviated, time: .omitted)).\n\(message.subject)"
          )
          .font(HomeType.compactBody).foregroundStyle(Palette.body).lineSpacing(4).lineLimit(3)
          HStack(spacing: 16) {
            Button {
              store.newDraft()
              if let id = store.composeID {
                store.saveComposition(
                  id: id, to: message.senderEmail, subject: "Checking in", body: "")
              }
            } label: {
              Label("Draft a check-in", systemImage: "square.and.pencil")
            }.buttonStyle(.plain).font(HomeType.action).disabled(store.busy)
            Button("View email") { open(message) }.buttonStyle(.plain).font(HomeType.action)
          }
          Divider().padding(.top, 6)
        }.padding(.top, 8)
      }
    }
  }

  private var recentSection: some View {
    VStack(alignment: .leading, spacing: 13) {
      HStack {
        Text("Fresh from your inbox").font(HomeType.supportingSection)
        Spacer()
        if files.count > 3 {
          Button(showAllFiles ? "Show recent ↑" : "All files →") { showAllFiles.toggle() }
            .buttonStyle(.plain).font(HomeType.action).foregroundStyle(Palette.body)
        }
      }
      Text("Attachments from your mail, with the source always close by.")
        .font(HomeType.compactBody).foregroundStyle(Palette.body)
      if files.isEmpty {
        emptyMessage(
          title: "No attachments in downloaded mail",
          detail: "Files will appear here when Cove syncs messages with attachments."
        )
      }
      ForEach(showAllFiles ? files : Array(files.prefix(3))) { file in
        HStack(spacing: 12) {
          Image(systemName: attachmentIcon(file.attachment))
            .font(.cove(size: 16)).foregroundStyle(Palette.body)
            .frame(width: 34, height: 39).background(
              Palette.sidebar, in: RoundedRectangle(cornerRadius: 5))
          VStack(alignment: .leading, spacing: 5) {
            Text(file.attachment.filename)
              .font(HomeType.supportingTitle).lineLimit(1)
            Button {
              open(file.message)
            } label: {
              Text(
                "\(file.message.sender) · \(file.message.subject.isEmpty ? "No subject" : file.message.subject)"
              )
              .font(.coveMetadata).foregroundStyle(Palette.muted).lineLimit(1)
            }.buttonStyle(.plain).help("Open source email")
          }.frame(maxWidth: .infinity, alignment: .leading)
          if let byteCount = file.attachment.byteCount {
            Text(ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file))
              .font(.coveMetadata).foregroundStyle(Palette.muted).fixedSize()
          }
          Button {
            Task { await store.downloadAttachment(file.attachment, from: file.message) }
          } label: {
            Image(systemName: "arrow.down.to.line").font(.cove(size: 15))
              .foregroundStyle(Palette.body).frame(width: 30, height: 34)
          }.buttonStyle(.plain).disabled(store.busy)
            .help("Save \(file.attachment.filename)")
            .accessibilityLabel("Save \(file.attachment.filename)")
        }.padding(.vertical, 6)
        Divider()
      }
    }
  }

  private func attachmentIcon(_ attachment: MailAttachment) -> String {
    if attachment.mimeType.hasPrefix("image/") { return "photo" }
    if attachment.mimeType.contains("spreadsheet") || attachment.mimeType.contains("excel") {
      return "tablecells"
    }
    return "doc.text"
  }

  private var activitySection: some View {
    VStack(alignment: .leading, spacing: 15) {
      Text("Quietly taken care of").font(HomeType.supportingSection)
      activity(
        "\(mail.filter { $0.decision != nil }.count) emails organized",
        detail: store.isSample
          ? "Sample categories and priority decisions."
          : "Categories and priority decisions from Jev.")
      activity(
        "\(mail.filter { !$0.draft.isEmpty || $0.labels.contains("DRAFT") }.count) drafts saved",
        detail: "Ready for your review. Nothing sent automatically.")
      activity(
        "\(files.count) attachments found",
        detail: "Linked to their original conversations.")
      Button("Your agent preferences →") { store.screen = "agent" }.buttonStyle(.plain)
        .font(HomeType.action)
    }
  }

  private func activity(_ title: String, detail: String) -> some View {
    HStack(alignment: .top, spacing: 9) {
      Image(systemName: "checkmark.circle").foregroundStyle(Palette.muted)
      VStack(alignment: .leading, spacing: 5) {
        Text(title).font(HomeType.action)
        Text(detail).font(.coveMetadata).foregroundStyle(Palette.muted).lineSpacing(4)
      }
    }
  }

  private func emptyMessage(title: String, detail: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(HomeType.supportingTitle)
      Text(detail).font(HomeType.compactBody).foregroundStyle(Palette.body).lineSpacing(4)
    }.padding(.vertical, 20)
  }

  private func open(_ message: Mail) {
    store.search = ""
    let folder =
      message.labels.contains("DRAFT")
      ? "Drafts"
      : (message.snoozedUntil ?? .distantPast) > store.now
        ? "Snoozed"
        : message.labels.contains("INBOX")
          ? "Inbox"
          : message.labels.contains("SENT") ? "Sent" : "Archive"
    store.chooseFolder(folder)
    store.select(message)
  }
}

private struct HubFile: Identifiable {
  let message: Mail
  let attachment: MailAttachment
  var id: String { message.id + ":" + attachment.id }
}

private struct HubEmailButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    HubEmailButtonSurface(configuration: configuration)
  }
}

private struct HubEmailButtonSurface: View {
  let configuration: ButtonStyleConfiguration
  @State private var hovering = false
  @Environment(\.isFocused) private var focused
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    configuration.label.foregroundStyle(Palette.ink)
      .background(
        configuration.isPressed ? Palette.selection : hovering ? Palette.surface : Palette.canvas,
        in: RoundedRectangle(cornerRadius: 6)
      )
      .overlay {
        if focused {
          RoundedRectangle(cornerRadius: 6).stroke(Palette.ink, lineWidth: 2)
        }
      }
      .onHover { hovering = $0 }
      .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: hovering)
  }
}
