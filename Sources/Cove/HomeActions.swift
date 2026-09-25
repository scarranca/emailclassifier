import CoveCore
import Foundation

extension AppStore {
  func openHomeMail(_ message: Mail) {
    search = ""
    let target = message.labels.contains("DRAFT") ? "Drafts"
      : (message.snoozedUntil ?? .distantPast) > now ? "Snoozed"
      : message.labels.contains("INBOX") ? "Inbox"
      : message.labels.contains("SENT") ? "Sent" : "Archive"
    chooseFolder(target)
    select(message)
  }

  func reviewHomeDecision(_ message: Mail) {
    if let run = customAgents.runs.first(where: { run in
      run.mailID == message.id && run.replySuggestion != nil && run.replyApplied != true
        && customAgents.agents.contains(where: { $0.id == run.agentID })
    }) {
      agentEditor = nil; agentActivityID = run.agentID; screen = "agents"
    } else { openHomeMail(message) }
  }

  func prepareHomeDelegation(_ message: Mail) {
    guard !busy else { return }
    newDraft()
    guard let id = composeID else { return }
    let attachments = message.availableAttachments.isEmpty ? "" : "\nAttachments are in the original email; they are not included in this draft.\n"
    let quoted = "\n\n---------- Forwarded message ----------\nFrom: \(message.sender) <\(message.senderEmail)>\nDate: \(message.date.formatted())\nSubject: \(message.subject)\n\(attachments)\n\(message.body)"
    saveComposition(id: id, to: "", subject: "Fwd: " + message.subject, body: quoted)
  }

  func prepareHomeFollowUp(_ message: Mail) {
    guard !busy else { return }
    newDraft()
    guard let id = composeID else { return }
    let subject = message.subject.lowercased().hasPrefix("re:") ? message.subject : "Re: " + message.subject
    saveComposition(id: id, to: message.to, subject: subject, body: "")
  }
}
