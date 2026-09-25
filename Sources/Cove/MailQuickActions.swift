import CoveCore
import SwiftUI

/// Direct actions alongside a Hub email, outside the button that opens its reader.
struct MailQuickActions: View {
  @Bindable var store: AppStore
  let mail: Mail

  var body: some View {
    HStack(spacing: 18) {
      Button { Task { await store.toggleFlag(mail) } } label: {
        Label(mail.isStarred ? "Flagged" : "Flag", systemImage: mail.isStarred ? "flag.fill" : "flag")
      }.disabled(mail.labels.contains("DRAFT")).help("Follow-up flag · syncs with Gmail’s star")
      Button {
        Task { await store.archive(mail) }
      } label: {
        Label("Archive", systemImage: "archivebox")
      }.disabled(!mail.labels.contains("INBOX") || mail.labels.contains("DRAFT"))
        .help("Remove from the inbox and keep in Archive")
      Button {
        store.queueTrash(mail)
      } label: {
        Label("Delete", systemImage: "trash")
      }.help("Move this email to Trash")
    }.buttonStyle(.plain).font(.coveMetadata).foregroundStyle(Palette.body)
      .disabled(store.busy)

  }
}
